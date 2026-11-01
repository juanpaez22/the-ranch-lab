# Monitoring

Last updated: 2026-11-01

The monitoring stack combines cluster-native telemetry from the two k3s laptops with narrowly exposed Windows host and GPU telemetry from Longhorn. Prometheus is the common store and Grafana is the common presentation layer. Exact LAN addresses remain in ignored `local/` configuration.

## Deployed stack

| Component | Runs on | Purpose and boundary |
| --- | --- | --- |
| Prometheus | Bronco, in k3s | Scrapes every 30 seconds and retains up to 48 hours or 3 GiB on a 5 GiB node-local PVC. |
| Node Exporter | Bronco and Yeti, in k3s | Linux CPU, memory, disk, network, temperature, and host uptime. |
| kube-state-metrics | Bronco, in k3s | Kubernetes object state such as node readiness, replicas, pods, and PVCs. It does not report container resource use. |
| Windows Exporter | Longhorn Windows service | Whole-workstation CPU, memory, disk, network, OS, service, and system metrics on a specific LAN listener allowed only from Bronco. |
| NVIDIA GPU Exporter | Longhorn Ubuntu WSL, user systemd service | Reads WSL's `nvidia-smi` every 15 seconds and exposes GPU utilization, power draw, VRAM, temperature, and clocks on WSL loopback. |
| Windows portproxy and firewall | Longhorn Windows | Publishes only the GPU exporter port on Longhorn's reserved LAN address. The Private-profile TCP rule permits only Bronco. |
| Grafana | Yeti, in k3s | Uses Prometheus as its provisioned datasource and stores its database on a node-local PVC. |

The pinned Helm and exporter versions live under [`apps/monitoring`](../apps/monitoring) and [`configs/monitoring`](../configs/monitoring). Dashboard JSON is versioned under [`apps/monitoring/grafana/dashboards`](../apps/monitoring/grafana/dashboards) and published with [`publish_dashboards.py`](../scripts/monitoring/publish_dashboards.py).

## K3s nodes compared with Longhorn

| Property | Bronco and Yeti | Longhorn |
| --- | --- | --- |
| Platform role | k3s server/worker and worker | External Windows 11 workstation with Ubuntu WSL; not a Kubernetes node |
| Discovery | Kubernetes service discovery and cluster DNS | Static scrape target in an ignored local Helm values file |
| Host coverage | Broad Linux host metrics from Node Exporter | Whole-Windows CPU/memory/disk/network metrics plus physical GPU telemetry; no separate whole-WSL host exporter |
| Kubernetes state | Reported by kube-state-metrics | Not applicable |
| Network path | Cluster networking and host port 9100 | Native Windows listener on 9182 plus WSL loopback/Windows portproxy on 9835; both allow only Bronco |
| Availability | Intended to remain on with the cluster | Windows metrics persist independently of WSL; all Longhorn metrics disappear during sleep or Windows shutdown, while GPU metrics also depend on WSL |
| Storage | Prometheus/Grafana history is node-local in k3s | Exporter is stateless; samples are retained by Prometheus on Bronco |

Windows Exporter reports the physical workstation's Windows view, including load from Windows applications and WSL. It does not isolate WSL resource consumption. The GPU exporter reports board telemetry exposed by the WSL NVIDIA stack; power is GPU draw, not whole-workstation electricity consumption. Both endpoints are unauthenticated and restricted to Bronco rather than the LAN subnet. The WSL user service does not by itself keep WSL alive; the existing Windows logon keepalive used for inference provides that lifecycle today.

Bronco is the only allowed client because it is the only Prometheus scraper. Grafana on Yeti queries Prometheus and never contacts exporters directly. If another scraper is added, allow its specific address or a narrow monitoring subnet rather than exposing host inventory to the entire LAN.

The GPU exporter remains in WSL because it is already supervised, benchmarked, and colocated with inference. Moving the same NVIDIA exporter to a native Windows service would preserve GPU telemetry while WSL is stopped, but should be a separate parity-tested migration. Windows Exporter's optional GPU collector does not replace the NVIDIA-specific power, temperature, VRAM, utilization, and clock series used by the current dashboards.

## Data flow and dashboards

```text
Bronco/Yeti Node Exporter --+
kube-state-metrics ----------+--> Prometheus on Bronco --> Grafana on Yeti
Longhorn WSL GPU exporter ---+
        via scoped Windows forwarding
Longhorn Windows Exporter ---+
        via scoped native listener
```

`Ranch / Operations` is the always-on homelab homepage shown on Yeti. Fleet and Kubernetes status lead into equal-width Bronco, Yeti, and Longhorn CPU/memory quadrants. The bottom row covers Linux storage, fleet thermals, and Longhorn GPU utilization/VRAM/power. The machine-centric layout leaves room for inference throughput, queue, and model-state metrics later.

`Ranch / Longhorn GPU` remains the deeper GPU-only view with utilization, power, temperature, VRAM, and clocks. Both dashboards use `job="nvidia-gpu-exporter"` and the stable `instance="longhorn"` label. Missing Longhorn data is not converted into a healthy zero.

The live GPU dashboard and machine-centric Operations definition were API-validated on 2026-11-01, including whole-Windows CPU/memory queries. This does not constitute browser-rendered layout validation.

## Operations

Installation, update, validation, and rollback commands are in [SETUP.md](SETUP.md#longhorn-windows-host-monitoring) and [SETUP.md](SETUP.md#longhorn-gpu-monitoring). Useful live checks are:

```bash
systemctl --user status nvidia-gpu-exporter
curl -fsS http://127.0.0.1:9835/metrics | grep '^nvidia_smi_'
kubectl -n monitoring port-forward --address=127.0.0.1 svc/prometheus-server 9095:80
kubectl -n monitoring port-forward --address=127.0.0.1 svc/grafana 3000:80
python3 scripts/monitoring/publish_dashboards.py --check
```

From an elevated Windows PowerShell session:

```powershell
Get-Service windows_exporter
```

For a Prometheus change, render the base values plus the ignored Longhorn target before applying them. Validate the effective target and real queries after Helm reports success. For Grafana, publish the repository JSON and then run the read-only check. Do not treat a healthy pod, valid JSON, or successful Helm release as proof that the telemetry path works.

Current gaps include container CPU/memory telemetry, external service probes, alerting, monitoring backups, node-loss recovery, browser startup recovery, whole-PC power, WSL-only host attribution, and llama.cpp request/throughput metrics. The next Longhorn addition should reuse the same WSL supervision and narrowly scoped forwarding pattern where practical.
