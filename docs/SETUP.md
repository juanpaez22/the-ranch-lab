# Setup and operations

Repeatable procedures for the current [architecture](ARCHITECTURE.md). Run only the steps needed for the target machine; existing lab installations do not need to be repeated.

- [Ubuntu preparation](#ubuntu-preparation)
- [K3s installation](#k3s-installation)
- [Cluster administration](#cluster-administration)
- [First application: IT-Tools](#first-application-it-tools)
- [Prometheus host monitoring](#prometheus-host-monitoring)
- [Grafana](#grafana)
- [Local WSL inference](#local-wsl-inference)

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

## First application: IT-Tools

IT-Tools is the initial stateless workload and LAN-ingress check. Its manifests live in [`apps/it-tools`](../apps/it-tools). One replica is exposed through a ClusterIP Service and a hostless Traefik Ingress. While it is the only HTTP application, clients with mDNS support can open `http://bronco.local/`. Replace the hostless rule with a dedicated DNS name before adding another root application.

### Prerequisites

- Bronco is Ready and reachable through the configured kubectl context.
- Traefik is Running and the `traefik` IngressClass exists.
- Ports 80 and 443 on bronco remain available to the bundled ServiceLB.
- The cluster can pull the pinned IT-Tools image from `ghcr.io`. The manifest records the immutable digest verified during the initial deployment. Review upstream changes and update this digest deliberately.

Preview and inspect the change from the repository root:

```bash
kubectl kustomize apps/it-tools
kubectl diff -k apps/it-tools
```

### Apply

```bash
kubectl apply -k apps/it-tools
kubectl -n it-tools rollout status deployment/it-tools --timeout=180s
```

### Validate

```bash
kubectl -n it-tools get deployment,pod,service,ingress -o wide
kubectl -n it-tools get endpointslice -l kubernetes.io/service-name=it-tools
curl --fail --show-error --head http://bronco.local/
```

WSL does not currently resolve the lab's mDNS names. From WSL, preserve the hostname while supplying bronco's private reserved address explicitly:

```bash
curl --fail --show-error --head \
  --resolve bronco.local:80:<bronco-reserved-ipv4> \
  http://bronco.local/
```

Keep the real address outside this public repository. Open `http://bronco.local/` from another LAN client and confirm the IT-Tools interface loads. This validates the path through LAN name resolution, ServiceLB, Traefik, the ClusterIP Service, and the pod. Inspect pod placement because one replica only exercises cross-node routing when Traefik and IT-Tools run on different nodes. During the initial deployment, Traefik ran on bronco, IT-Tools ran on yeti, and the request returned HTTP 200. An in-pod request to `it-tools.it-tools.svc.cluster.local` also returned HTTP 200, validating cluster DNS and Service routing.

### Roll back

IT-Tools stores no application data. Remove all resources created by this kustomization with:

```bash
kubectl delete -k apps/it-tools
```

Confirm the namespace is gone and `http://bronco.local/` no longer routes to the application. Reapplying the kustomization recreates it from Git.

## Prometheus host monitoring

Prometheus runs as Helm release `prometheus` in namespace `monitoring`. The pinned chart version is in [version.txt](../apps/monitoring/prometheus/version.txt); [values.yaml](../apps/monitoring/prometheus/values.yaml) defines the installed configuration.

### Prerequisites and installation

Use a working kubectl context for this lab, Helm 3.7 or newer, and Bash/curl/jq for validation. Both nodes must be Ready, TCP 9100 reachable from the Prometheus pod, and the `local-path` provisioner available with free disk on Bronco. Check existing releases and resources before installing. The existing Helm CLI is installed in WSL; a new administration machine should follow the [official Helm installation procedure](https://helm.sh/docs/intro/install/), verifying its release checksum.

From the repository root:

```bash
kubectl get nodes
kubectl get storageclass
helm list -n monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
chart_version="$(cat apps/monitoring/prometheus/version.txt)"
helm template prometheus prometheus-community/prometheus \
  --namespace monitoring --version "$chart_version" \
  -f apps/monitoring/prometheus/values.yaml
helm upgrade --install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace --version "$chart_version" \
  --reset-values -f apps/monitoring/prometheus/values.yaml --wait --timeout 180s
```

Render and inspect before applying changes. The namespace is created separately from chart ownership. The chart creates two Deployments (Prometheus with its configuration-reloader sidecar, plus kube-state-metrics), one Node Exporter DaemonSet (two pods), three Services, three service accounts, one ConfigMap, one PVC, and separate discovery/object-state ClusterRoles and ClusterRoleBindings. Alertmanager, Pushgateway, and unrelated scrape jobs are disabled. Helm stores release metadata as Secrets in the namespace; do not export those into Git.

Prometheus is scheduled on Bronco with a 5 GiB local-path claim, 48-hour retention, and `retentionSize: 3GB` (the selected chart renders this as `3GiB`). Retention is bounded by whichever limit is reached first. Local-path storage is node-local and its requested capacity is not a filesystem quota. Disk usage still needs monitoring. The server requests 100m CPU/256Mi memory and has limits of 1000m/1Gi; the reloader requests/limits 100m/64Mi, and each exporter requests 50m/64Mi with limits of 100m/128Mi.

The exporter uses upstream read-only `/proc`, `/sys`, and root mounts, host networking/PID namespace, and a non-root user without privilege escalation. It listens on TCP 9100 on host interfaces, without authentication. Prometheus's UI/API is ClusterIP-only, but exporter metrics can be reachable from LAN peers depending on existing host firewall rules. No host firewall was changed. Do not expose this deployment to untrusted networks or copy its host-access settings into ordinary application pods. The chart's discovery role has read-only metadata/metrics access and no Secret-reading or write permissions; it covers more resource types than the node-only discovery currently needs.

### Kubernetes object state (KSM)

The Prometheus release enables its pinned kube-state-metrics dependency: chart `8.7.1`, application `v2.20.0`, built against Kubernetes client-go `v1.36`. It runs as one stateless pod on Bronco and exports object state through a ClusterIP Service at `prometheus-kube-state-metrics.monitoring.svc.cluster.local:8080`. Prometheus scrapes it every 30 seconds under job `kube-state-metrics`. No additional Helm release, PVC, host port, or operator is needed.

KSM requests 50m CPU/64Mi memory with limits of 200m/256Mi. Its read-only RBAC covers the explicitly enabled workload, node, namespace, networking, and storage collectors. Secret/configuration-object collectors and label/annotation wildcards are not enabled. KSM reports declared and observed Kubernetes object state, such as deployment replicas, pod readiness, and PVC binding. It does not supply actual container CPU/memory utilization; that needs a separate kubelet/cAdvisor scrape.

Example PromQL:

```promql
kube_node_status_condition{condition="Ready",status="true"}
kube_deployment_status_replicas_available
kube_pod_status_ready{condition="true"}
```

To remove KSM, set `kube-state-metrics.enabled: false` and remove its `scrapeConfigs.kube-state-metrics` entry, then run the pinned Helm upgrade. Update the validator's expected targets and object-state checks with that configuration change. This removes the KSM workload/RBAC/Service while retaining Prometheus history and Grafana. Do not uninstall the entire Prometheus release just to remove KSM.

References: [KSM overview and compatibility](https://github.com/kubernetes/kube-state-metrics) and [chart configuration](https://github.com/prometheus-community/helm-charts/tree/kube-state-metrics-8.7.1/charts/kube-state-metrics).

### Access and validation

Keep this localhost-bound port-forward running in a terminal:

```bash
kubectl -n monitoring port-forward --address=127.0.0.1 svc/prometheus-server 9095:80
```

Open `http://127.0.0.1:9095/` and run in a second terminal:

```bash
scripts/monitoring/validate_scrape.sh http://127.0.0.1:9095
kubectl top pods -n monitoring
```

The read-only validator checks readiness, exact configured jobs, four healthy 30-second scrape targets, the two expected host labels, and CPU/memory/root-filesystem/network metrics and rates. It also checks KSM node readiness, pod inventory, IT-Tools deployment availability, and the Prometheus PVC state. It exits nonzero on missing data or HTTP/API errors and does not create a port-forward. Allow at least two successful scrapes after initial startup for rates to exist. Choose a different local port if 9095 is occupied.

ConfigMap projection and reload can lag behind a Helm update. Confirm the effective configuration through `/api/v1/status/config`; Helm success alone does not establish that new scrape jobs are active. When immediate reload is needed, a bounded restart provides a deterministic update:

```bash
kubectl -n monitoring rollout restart deployment/prometheus-server
kubectl -n monitoring rollout status deployment/prometheus-server --timeout=180s
```

Prometheus's matching `promtool` is available inside the server container for configuration checks. Use `/api/v1/targets` for scrape errors and `/api/v1/query` with URL-encoded PromQL for metric checks. A healthy pod does not prove a functioning scrape pipeline. Daily logs record live validation, including historical samples queried across a server restart; that is not a disk-loss or node-failure recovery test.

### Updates, rollback, and removal

Keep chart version and values in Git. For configuration updates, render and repeat the pinned `helm upgrade --install` command, then run validation. Chart/application upgrades require a separate review of release notes, rendered changes, storage compatibility, and resource use; they are not needed to finish the current installation.

For a configuration rollback, inspect `helm history prometheus -n monitoring`, choose a compatible known revision, and use `helm rollback prometheus <revision> -n monitoring --wait --timeout 180s`. Historical revisions from the initial setup contain the broken scrape configuration, so do not choose a revision blindly. Restore the corresponding repository values as well.

To remove the workload while retaining history:

```bash
kubectl -n monitoring get pvc prometheus-server \
  -o go-template='{{index .metadata.annotations "helm.sh/resource-policy"}}{{"\n"}}'
# Confirm the result is "keep" before uninstalling.
helm uninstall prometheus -n monitoring
kubectl -n monitoring get pvc prometheus-server
```

The keep annotation retains the PVC but is not a backup. Uninstall recovery has not been exercised on the live installation. For redeployment with retained data, inspect the existing claim and install with `--set server.persistentVolume.existingClaim=prometheus-server` in addition to the pinned values. Do not delete the namespace: doing so also deletes retained claims. Deleting this PVC is a separate destructive cleanup action; the local-path storage class uses reclaim policy `Delete`, which can remove its underlying data.

[Grafana](#grafana) is managed as a separate Helm release.

References: [pinned chart](https://github.com/prometheus-community/helm-charts/tree/prometheus-29.40.1/charts/prometheus), [Prometheus API](https://prometheus.io/docs/prometheus/latest/querying/api/), [storage](https://prometheus.io/docs/prometheus/latest/storage/), and [Helm resource retention](https://helm.sh/docs/howto/charts_tips_and_tricks/#tell-helm-not-to-uninstall-a-resource).

## Grafana

Grafana runs as Helm release `grafana` in the shared `monitoring` namespace. It uses a provisioned, read-only Prometheus datasource with stable UID `prometheus`. The [version pin](../apps/monitoring/grafana/version.txt) selects chart `10.5.15` and Grafana `12.3.1`; [values.yaml](../apps/monitoring/grafana/values.yaml) supplies reproducible configuration. This chart source marks the pinned release deprecated; review the maintained chart repository and migration notes before a future upgrade rather than silently changing this installation.

### Credentials and installation

Prerequisites are the working Prometheus installation, Helm, kubectl, OpenSSL, and free disk on Yeti. Grafana has one replica on Yeti, a 5 GiB local-path PVC retained on Helm uninstall, and a Recreate deployment strategy for its single database volume. It requests 100m CPU/128Mi memory and limits use to 500m/512Mi. Its Service is ClusterIP-only; anonymous access and self-signup are disabled.

Credentials live in the externally managed Secret `grafana-admin`, not Helm values. From the repository root, create a private password only if one does not already exist, then install/update the Secret and chart:

```bash
(
set -euo pipefail
install -d -m 0700 local/grafana
if [[ ! -e local/grafana/admin-password ]]; then
  (umask 077; openssl rand -hex 32 | tr -d '\n' > local/grafana/admin-password)
fi
chmod 0600 local/grafana/admin-password
kubectl get namespace monitoring
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin --from-file=admin-password=local/grafana/admin-password \
  --dry-run=client -o yaml | kubectl apply -f -
helm repo add grafana https://grafana.github.io/helm-charts
chart_version="$(cat apps/monitoring/grafana/version.txt)"
helm template grafana grafana/grafana --namespace monitoring --version "$chart_version" \
  -f apps/monitoring/grafana/values.yaml
helm upgrade --install grafana grafana/grafana --namespace monitoring --version "$chart_version" \
  --reset-values -f apps/monitoring/grafana/values.yaml --wait --timeout 180s
)
```

Inspect rendered changes before applying to an existing installation. Preserve the password file across administration sessions. If the file is lost but the Secret is intact, recover it privately from the Secret rather than generating a replacement unintentionally. `local/` is ignored, but credentials must still be excluded from staged changes and diagnostic output. Helm stores release metadata in cluster Secrets; do not export it into Git.

Grafana's administrator password is stored in its persistent database. Changing the Secret does not rotate an existing database password. For an intentional rotation or recovery, update the private file/Secret, then reset the database using stdin so the password is not in process arguments:

```bash
kubectl -n monitoring exec -i deployment/grafana -- \
  grafana cli --homepath /usr/share/grafana --config /etc/grafana/grafana.ini \
  admin reset-admin-password --password-from-stdin < local/grafana/admin-password
```

Use the same private credential for validation afterward. When migrating an existing RollingUpdate deployment to Recreate, clear any incompatible `spec.strategy.rollingUpdate` field. Chart upgrades and database-schema rollback need a separate compatibility review.

### Access and validation

Keep a localhost port-forward running:

```bash
kubectl -n monitoring port-forward --address=127.0.0.1 svc/grafana 3000:80
```

Open `http://127.0.0.1:3000/`, log in as `admin`, and read the password from `local/grafana/admin-password` in a private terminal or editor. Do not paste it into shared logs. Choose another local port if needed. From another terminal:

```bash
scripts/monitoring/validate_grafana.sh http://127.0.0.1:3000
```

The validator checks database health, anonymous API rejection, administrator authentication, the provisioned default datasource, and an authenticated query through Grafana returning healthy exporters for both hosts. It accepts an optional second argument naming another private password file. It uses bounded requests and a mode-0600 temporary curl configuration, removes it on exit, and never places the password in command arguments. It does not create a port-forward or modify Grafana. Run the separate Prometheus validator as well when changing the monitoring stack.

Datasource provisioning uses a `datasources` list inside `datasources.yaml`. Validate the connection through Grafana rather than relying only on pod or API health. Credentials and datasource availability have been checked across a Grafana restart; that does not establish recovery from node loss.

### Removal

Inspect the Grafana PVC's keep annotation before `helm uninstall grafana -n monitoring`. The PVC and external `grafana-admin` Secret are retained, and Prometheus is a separate release. Do not delete the shared namespace. To reuse retained data on redeployment, inspect the claim and add `--set persistence.existingClaim=grafana` to the pinned install command. Live uninstall/reinstall remains untested. Deleting the claim is a separate destructive step that can remove its backing data under the local-path provisioner's Delete reclaim policy.

### Dashboard source and publication

Dashboard JSON in [apps/monitoring/grafana/dashboards/](../apps/monitoring/grafana/dashboards/) is the source of truth. [node-basics.json](../apps/monitoring/grafana/dashboards/node-basics.json) establishes a minimal example: two stat panels show uptime and memory used for each node, using datasource UID `prometheus`. Memory used means `100 * (1 - MemAvailable / MemTotal)`, including reclaimable memory correctly. Uptime uses exporter host time minus boot time. Missing data is not converted to zero.

With the Grafana localhost port-forward running, publish and check:

```bash
python3 scripts/monitoring/publish_dashboards.py
python3 scripts/monitoring/publish_dashboards.py --check
```

The publisher requires Python 3 and uses only its standard library and the existing private admin password file. Optional `--endpoint`, `--password-file`, and explicit JSON file paths select a tunnel, credential location, or subset. It uses bounded requests and keeps credentials out of process arguments. It does not start a port-forward. The current publisher targets the installed Grafana 12.3 legacy dashboard API (`POST /api/dashboards/db`); review API compatibility when upgrading Grafana.

Publication creates or updates dashboards by stable UID, verifies the saved authored fields, and skips unchanged definitions. It does not delete dashboards, touch Helm resources, or create public shares. Each JSON file is a classic Grafana dashboard model, not an API response/wrapper: retain stable `uid` and panel IDs, reference datasource UID `prometheus`, and omit instance-specific numeric IDs/revisions (`id: null`, `version: 0` are also accepted). Files are published to the default dashboard folder. Keep credentials, concrete LAN addresses, query results, and exported instance metadata out of these files.

`--check` is read-only: it compares saved definitions and runs each literal PromQL expression through Grafana, requiring nonempty finite instant-vector results. It is a smoke check, not proof of correct units/labels or visual layout. Variable-based queries require explicit bindings and a dedicated validation procedure. The example was additionally checked for exactly Bronco/Yeti values and valid uptime/percentage ranges. No browser-rendered visual check has been performed.

Treat UI edits as experiments: copy intentional changes back into the JSON and review them before publishing. A later publish replaces differing authored fields for the same UID. Existing dashboard data survives a normal Grafana pod restart via its PVC; replaying the publisher recreates repo dashboards after a clean installation once credentials/datasource are restored. Helm install alone does not publish them. For rollback, restore a prior JSON revision and republish it; renaming/removing a file does not delete the old dashboard automatically.

To add a dashboard, copy the example to a new file with a distinct UID, validate its PromQL against available host/KSM metrics, and publish/check that file. Keep dashboard development separate from deployment configuration changes.

References: [Grafana Helm installation](https://grafana.com/docs/grafana/latest/setup-grafana/installation/helm/), [file provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/), and [administrator CLI](https://grafana.com/docs/grafana/latest/administration/cli/).

## Local WSL inference

The inference decision, current state, scripts, installation, client configuration, validation, and rollback are documented in [INFERENCE.md](INFERENCE.md).
