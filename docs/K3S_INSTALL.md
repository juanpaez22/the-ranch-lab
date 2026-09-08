# Install the first cluster

Approved baseline: `bronco` server, `yeti` agent; default packaged components, SQLite, host swap unchanged. Server overrides are the `bronco.local` TLS SAN and secrets encryption. No backups initially: all cluster state and application data are disposable.

## Prerequisites

- Ubuntu/systemd, curl, sudo, and working `bronco.local` resolution on the agent.
- Review the [readiness findings](K3S_PLAN.md). Cluster networking must be permitted: server TCP 6443, peer UDP 8472 for VXLAN, and peer TCP 10250 for metrics. Keep these on the trusted LAN.
- Use a local terminal or `ssh -t` so sudo and the hidden join-token prompt can read your terminal.
- Obtain this repository on each laptop, or use the session's staged bundle containing `scripts/` and `configs/` together. Git is not required for a staged bundle.

## Version and behavior

`configs/k3s/version.txt` pins `v1.36.4+k3s1`, the official stable-channel result observed on 2026-09-07. The script downloads the upstream installer from that release tag; the installer verifies its binary against the release checksum.

The two small scripts install their respective configuration and run the upstream installer. That installer installs binaries and systemd services, enables startup at boot, and starts k3s; k3s then downloads images and configures cluster networking. The scripts do not change swap or firewall policy. Review firewall readiness separately. They refuse to overwrite an existing `config.yaml` and assume a fresh installation on the intended laptop. They are not upgrade scripts.

Run from the repository or bundle root, without shell tracing (`bash -x`). There is no hostname detection: choose the correct script for the laptop.

## What the scripts do

Both use `set -euo pipefail` to stop on failed commands, missing variables, or pipeline failures. Both check that the destination configuration does not exist, read the shared version pin, and use `install -D -m 0600` to copy configuration, create parent directories, and restrict file access to root.

The server configuration adds `bronco.local` to the TLS certificate and enables secrets encryption. The server script then downloads the upstream installer from the pinned release tag and runs it in server mode with the binary version pinned too.

The agent script first reads the join token with hidden input. `umask 077` restricts newly created files; the token is written outside Git with mode 0600, then removed from the shell variable. The agent configuration supplies the server URL and token-file path. Finally it runs the same upstream installer in agent mode. The token is not a command-line argument.

Verification is separate from installation so each step is visible. A failure after configuration is copied may leave partial state; inspect it before retrying.

## Server first: bronco

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

## Agent next: yeti

From the repository or staged bundle root:

```bash
sudo bash scripts/install_k3s_agent_yeti.sh
```

Paste the token at the hidden prompt. It is stored only in a root-readable file outside the repository, referenced by the agent configuration. The script does not echo it or put it on a command line.

## Verify on bronco

```bash
sudo k3s kubectl wait --for=condition=Ready node/yeti --timeout=180s
sudo k3s kubectl get nodes
sudo k3s kubectl get pods -A
sudo k3s secrets-encrypt status
sysctl net.ipv4.ip_forward
```

Both nodes should be Ready at the pinned version, packaged pods should settle successfully, encryption should be enabled, and forwarding should be enabled. These checks alone do not establish cross-node pod connectivity, DNS, or ingress; deploy and inspect a disposable workload next. Do not publish raw output containing node addresses.

If installation fails, inspect service status/logs locally and redact secrets before sharing. A partial installation may require diagnosis before retrying; do not blindly uninstall it.

## Rebuild or uninstall

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
