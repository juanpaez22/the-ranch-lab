# Cluster administration

The standalone kubectl client is pinned to v1.36.4, matching the initial cluster. Copied kubeconfigs grant cluster-admin access and must remain outside Git.

## Linux laptops

Client: `~/.local/bin/kubectl`. Credentials: `~/.kube/config`, mode 0600 inside a mode-0700 directory. On bronco the copied config can use loopback; other machines use the server's reserved LAN address.

Ubuntu login sessions add `~/.local/bin` to PATH when present. This avoids replacing the k3s-managed client symlink in `/usr/local/bin`. Ordinary `kubectl get nodes` works without sudo once the standalone client is selected.

## Windows workstation

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

## Reproduce and maintain

- Download the matching client and SHA256 from the official Kubernetes release endpoints and verify before installing. Follow the [Linux](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) or [Windows](https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/) guide.
- Transfer the working admin kubeconfig over SSH from an authorized laptop. Preserve existing local configs; do not blindly overwrite them. Restrict permissions and use the actual server address only in the private copy.
- Verify `kubectl get nodes`, `kubectl get pods -A`, and `kubectl get --raw=/readyz` with certificate verification enabled.
- Refresh copied credentials when certificates are renewed or the cluster is rebuilt; copies do not update automatically. Keep the client compatible when upgrading the server.
- To remove local access, remove the client and private config you installed. Deleting a copy is not credential revocation; another copy of the same credentials remains valid.
