# Setup and operations

Repeatable procedures for the current [architecture](ARCHITECTURE.md). Run only the steps needed for the target machine; existing lab installations do not need to be repeated.

- [Ubuntu preparation](#ubuntu-preparation)
- [K3s installation](#k3s-installation)
- [Cluster administration](#cluster-administration)

## Ubuntu preparation

Run on each Ubuntu laptop separately. These are manual procedures, not a record that they have been applied.

### Updates and reboot

Inspect the baseline:

```bash
hostnamectl
df -h /
systemctl --failed
```

Review and install normal package updates:

```bash
sudo apt update
apt list --upgradable
sudo apt upgrade
```

Review proposed changes before accepting. Investigate held packages separately; major distribution upgrades and firmware updates are separate tasks.

Reboot when ready, then reconnect over SSH:

```bash
sudo reboot
```

After reconnecting:

```bash
uptime
uname -r
systemctl --failed
ip -br address
df -h /
```

Verify access without a local login and name resolution between hosts. Do not paste raw network output into public logs. Package updates have no universal rollback; preserve important data before updating and investigate failures before further changes.

### Closed-lid operation

The [configuration](../configs/ubuntu/60-lid.conf) tells systemd-logind to ignore lid closure on external power or when docked, and suspend on battery when undocked. It does not disable idle suspend. A desktop power manager can take over lid handling, so test the result.

Requires Ubuntu with systemd-logind and administrative access. From the repository root on the target laptop, inspect existing settings:

```bash
systemd-analyze cat-config systemd/logind.conf
```

Check for an existing `/etc/systemd/logind.conf.d/60-lid.conf`. If present, compare it and save a copy outside the repository before replacing it. Other drop-ins may override these settings.

Apply:

```bash
sudo install -d -m 0755 /etc/systemd/logind.conf.d
sudo install -m 0644 configs/ubuntu/60-lid.conf /etc/systemd/logind.conf.d/60-lid.conf
sudo reboot
```

After reconnecting over SSH, plug in the laptop, close the lid, wait at least 30 seconds, and run `uptime`. Verify it remains reachable. Check ventilation with the lid closed.

To roll back a newly added file:

```bash
sudo rm /etc/systemd/logind.conf.d/60-lid.conf
sudo reboot
```

If the file replaced a previous configuration, restore that saved copy instead, then reboot.

Reference: [Ubuntu systemd-logind manual](https://manpages.ubuntu.com/manpages/noble/man5/logind.conf.d.5.html).

## K3s installation

Approved baseline: `bronco` server, `yeti` agent; default packaged components, SQLite, host swap unchanged. Server overrides are the `bronco.local` TLS SAN and secrets encryption. No backups initially: all cluster state and application data are disposable.

### Prerequisites

- Ubuntu/systemd, curl, sudo, and reachability to bronco's reserved IPv4 address on TCP 6443.
- Check unique hostnames, cgroup support, time synchronization, available disk/RAM, and non-overlapping LAN/VPN/cluster routes. Cluster networking must be permitted: server TCP 6443, peer UDP 8472 for VXLAN, and peer TCP 10250 for metrics. Keep these on the trusted LAN.
- Use a local terminal or `ssh -t` so sudo and the hidden join-token prompt can read your terminal.
- Obtain this repository on each laptop, or use the session's staged bundle containing `scripts/` and `configs/` together. Git is not required for a staged bundle.

### Version and behavior

`configs/k3s/version.txt` pins `v1.36.4+k3s1`, the official stable-channel result observed on 2026-09-07. The script downloads the upstream installer from that release tag; the installer verifies its binary against the release checksum.

The two small scripts install their respective configuration and run the upstream installer. That installer installs binaries and systemd services, enables startup at boot, and starts k3s; k3s then downloads images and configures cluster networking. The scripts do not change swap or firewall policy. Review firewall readiness separately. They refuse to overwrite an existing `config.yaml` and assume a fresh installation on the intended laptop. They are not upgrade scripts.

Run from the repository or bundle root, without shell tracing (`bash -x`). There is no hostname detection: choose the correct script for the laptop.

### What the scripts do

Both use `set -euo pipefail` to stop on failed commands, missing variables, or pipeline failures. Both check that the destination configuration does not exist, read the shared version pin, and use `install -D -m 0600` to copy configuration, create parent directories, and restrict file access to root.

The server configuration adds `bronco.local` to the TLS certificate and enables secrets encryption. The server script then downloads the upstream installer from the pinned release tag and runs it in server mode with the binary version pinned too.

The agent script asks for bronco's reserved IPv4 address and reads the join token with hidden input. It substitutes the address into the installed configuration only; the public template keeps a placeholder. `umask 077` restricts newly created files; the token is written outside Git with mode 0600, then removed from the shell variable. Finally it runs the same upstream installer in agent mode. The token is not a command-line argument.

Verification is separate from installation so each step is visible. A failure after configuration is copied may leave partial state; inspect it before retrying.

### Server first: bronco

From the repository or staged bundle root:

```bash
sudo bash scripts/install_k3s_server_bronco.sh
sudo k3s kubectl wait --for=condition=Ready node/bronco --timeout=180s
sudo k3s secrets-encrypt status
```

Wait for the server node to become Ready and encryption status to report enabled. To obtain the join token, run this in your own terminal on bronco:

```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Copy the full token privately. Do not put it in chat, Git, screenshots, shell arguments, or session logs. Clear the clipboard afterward if used.

### Agent next: yeti

From the repository or staged bundle root:

```bash
sudo bash scripts/install_k3s_agent_yeti.sh
```

Enter bronco's reserved IPv4 address, then paste the token at the hidden prompt. The token is stored only in a root-readable file outside the repository, referenced by the agent configuration. The script does not echo it or put it on a command line.

### Existing agent: fix the initial mDNS endpoint

The initial `.local` endpoint failed during agent startup. Shell mDNS resolution succeeded, but system DNS resolution failed and the agent repeatedly failed to retrieve CA certificates through its local proxy. Direct-IP configuration avoids this resolver dependency.

Do not rerun the installer. On yeti, edit only the `server:` URL in `/etc/rancher/k3s/config.yaml` using `sudoedit`, replacing `bronco.local` with bronco's reserved IPv4 address. Preserve the `token-file:` setting. Then run `sudo systemctl restart k3s-agent` and verify node readiness from bronco. To roll back the endpoint change, restore the previous URL and restart the agent. The TLS SAN on bronco can remain; no server reinstall is necessary.

### Verify on bronco

```bash
sudo k3s kubectl wait --for=condition=Ready node/yeti --timeout=180s
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A
sudo k3s secrets-encrypt status
sysctl net.ipv4.ip_forward
```

Both nodes should be Ready at the pinned version, packaged pods should settle successfully, encryption should be enabled, and forwarding should be enabled. These checks alone do not establish cross-node pod connectivity, DNS, or ingress; deploy and inspect a disposable workload next. Do not publish raw output containing node addresses.

If installation fails, inspect service status/logs locally and redact secrets before sharing. A partial installation may require diagnosis before retrying; do not blindly uninstall it.

### Rebuild or uninstall

Destructive: the upstream uninstall scripts remove local cluster state and local-path volume data. With no backups, that data is lost. Run only when intentionally discarding this cluster.

On yeti:

```bash
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

On bronco:

```bash
sudo /usr/local/bin/k3s-uninstall.sh
```

For a fresh rebuild, repeat server then agent installation with a newly obtained token. Review any surviving config files/drop-ins first. Do not expect a rebuilt cluster to recover old secrets or application data from Git.

Sources: [installation](https://docs.k3s.io/installation), [configuration](https://docs.k3s.io/installation/configuration), [uninstall](https://docs.k3s.io/installation/uninstall).

## Cluster administration

The standalone kubectl client is pinned to v1.36.4, matching the initial cluster. Copied kubeconfigs grant cluster-admin access and must remain outside Git.

### Linux laptops

Client: `~/.local/bin/kubectl`. Credentials: `~/.kube/config`, mode 0600 inside a mode-0700 directory. On bronco the copied config can use loopback; other machines use the server's reserved LAN address.

Ubuntu login sessions add `~/.local/bin` to PATH when present. This avoids replacing the k3s-managed client symlink in `/usr/local/bin`. Ordinary `kubectl get nodes` works without sudo once the standalone client is selected.

### Windows workstation

Use the Ubuntu WSL distribution for administration. From PowerShell:

```powershell
wsl -d Ubuntu -- bash -lc 'kubectl get nodes'
wsl -d Ubuntu -- bash -lc 'kubectl get pods -A'
```

Or open WSL and run commands there:

```powershell
wsl -d Ubuntu
```

```bash
~/.local/bin/kubectl get nodes
```

The WSL client lives in `~/.local/bin`; its private configuration lives in `~/.kube/config`. This only administers the cluster; WSL is not a Kubernetes node.

Native Windows access encountered HTTPS inspection replacing the cluster certificate. WSL presented the original certificate and validated it using the copied cluster CA. No certificate-verification bypass or security-product change was applied. A checksum-verified Windows client was downloaded under the user's local Programs directory but was not added to PATH after its connection test failed.

### Reproduce and maintain

- Download the matching client and SHA256 from the official Kubernetes release endpoints and verify before installing. Follow the [Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) or [Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/) guide.
- Transfer the working admin kubeconfig over SSH from an authorized laptop. Preserve existing local configs; do not blindly overwrite them. Restrict permissions and use the actual server address only in the private copy.
- Verify `kubectl get nodes`, `kubectl get pods -A`, and `kubectl get --raw=/readyz` with certificate verification enabled.
- Refresh copied credentials when certificates are renewed or the cluster is rebuilt; copies do not update automatically. Keep the client compatible when upgrading the server.
- To remove local access, remove the client and private config you installed. Deleting a copy is not credential revocation; another copy of the same credentials remains valid.
