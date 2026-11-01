# Monitoring

Last updated: 2026-11-01

The monitoring stack combines cluster-native telemetry from the two k3s laptops with narrowly exposed GPU telemetry from Longhorn. Prometheus is the common store and Grafana is the common presentation layer. Exact LAN addresses remain in ignored `local/` configuration.

## Deployed stack

| Component | Runs on | Purpose and boundary |
| --- | --- | --- |
| Prometheus | Bronco, in k3s | Scrapes every 30 seconds and retains up to 48 hours or 3 GiB on a 5 GiB node-local PVC. |
| Node Exporter | Bronco and Yeti, in k3s | Linux CPU, memory, disk, network, temperature, and host uptime. |
| kube-state-metrics | Bronco, in k3s | Kubernetes object state such as node readiness, replicas, pods, and PVCs. It does not report container resource use. |
| NVIDIA GPU Exporter | Longhorn Ubuntu WSL, user systemd service | Reads WSL's `nvidia-smi` every 15 seconds and exposes GPU utilization, power draw, VRAM, temperature, and clocks on WSL loopback. |
| Windows portproxy and firewall | Longhorn Windows | Publishes only the GPU exporter port on Longhorn's reserved LAN address. The Private-profile TCP rule permits only Bronco. |
| Grafana | Yeti, in k3s | Uses Prometheus as its provisioned datasource and stores its database on a node-local PVC. |

The pinned Helm and exporter versions live under [`apps/monitoring`](../apps/monitoring) and [`configs/monitoring`](../configs/monitoring). Dashboard JSON is versioned under [`apps/monitoring/grafana/dashboards`](../apps/monitoring/grafana/dashboards) and published with [`publish_dashboards.py`](../scripts/monitoring/publish_dashboards.py).

## K3s nodes compared with Longhorn

| Property | Bronco and Yeti | Longhorn |
| --- | --- | --- |
| Platform role | k3s server/worker and worker | External Windows 11 workstation with Ubuntu WSL; not a Kubernetes node |
| Discovery | Kubernetes service discovery and cluster DNS | Static scrape target in an ignored local Helm values file |
| Host coverage | Broad Linux host metrics from Node Exporter | GPU-only metrics from `nvidia-smi`; no Windows or whole-WSL host exporter |
| Kubernetes state | Reported by kube-state-metrics | Not applicable |
| Network path | Cluster networking and host port 9100 | WSL loopback, Windows portproxy, then a Bronco-only LAN firewall rule on port 9835 |
| Availability | Intended to remain on with the cluster | Expected to disappear during sleep, Windows restart, WSL shutdown, or deliberate gaming/inference downtime |
| Storage | Prometheus/Grafana history is node-local in k3s | Exporter is stateless; samples are retained by Prometheus on Bronco |

Longhorn's exporter reports GPU board telemetry exposed by the WSL NVIDIA stack. Power is GPU draw, not whole-workstation electricity consumption. The endpoint is unauthenticated, so the Windows listener is restricted to Bronco rather than the LAN subnet. The WSL user service does not by itself keep WSL alive; the existing Windows logon keepalive used for inference provides that lifecycle today.

## Data flow and dashboards

```text
Bronco/Yeti Node Exporter --+
kube-state-metrics ----------+--> Prometheus on Bronco --> Grafana on Yeti
Longhorn WSL GPU exporter ---+
        via scoped Windows forwarding
```

`Ranch / Operations` summarizes cluster and Linux-node health. `Ranch / Longhorn GPU` shows utilization, power, temperature, VRAM, and clocks. The GPU dashboard uses `job="nvidia-gpu-exporter"` and the stable `instance="longhorn"` label. Missing Longhorn data is not converted into a healthy zero.

The live GPU dashboard definition and all 11 literal PromQL queries were API-validated on 2026-11-01. This does not constitute browser-rendered layout validation.

## Operations

Installation, update, validation, and rollback commands are in [SETUP.md](SETUP.md#longhorn-gpu-monitoring). Useful live checks are:

```bash
systemctl --user status nvidia-gpu-exporter
curl -fsS http://127.0.0.1:9835/metrics | grep '^nvidia_smi_'
kubectl -n monitoring port-forward --address=127.0.0.1 svc/prometheus-server 9095:80
kubectl -n monitoring port-forward --address=127.0.0.1 svc/grafana 3000:80
python3 scripts/monitoring/publish_dashboards.py --check
```

For a Prometheus change, render the base values plus the ignored Longhorn target before applying them. Validate the effective target and real queries after Helm reports success. For Grafana, publish the repository JSON and then run the read-only check. Do not treat a healthy pod, valid JSON, or successful Helm release as proof that the telemetry path works.

Current gaps include container CPU/memory telemetry, external service probes, alerting, monitoring backups, node-loss recovery, browser startup recovery, whole-PC power, Windows host metrics, and llama.cpp request/throughput metrics. The next Longhorn addition should reuse the same WSL supervision and narrowly scoped forwarding pattern where practical.
