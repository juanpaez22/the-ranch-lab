# Architecture

Last updated: 2026-11-01

The Ranch Lab is a small LAN-based homelab for running useful services and experimenting with Kubernetes, networking, and local inference. Two Linux laptops host the cluster; a Windows workstation supplies GPU inference while remaining available for gaming and everyday use.

This document describes the deployed components and their boundaries. [SETUP.md](SETUP.md) covers cluster installation and administration, [INFERENCE.md](INFERENCE.md) covers the inference service, and [BACKLOG.md](BACKLOG.md) tracks planned work. Dated validation and troubleshooting records live in [logs/](../logs/).

## Hosts

| Host | Hardware | Role |
| --- | --- | --- |
| `bronco` | HP EliteBook x360 1030 G3; i7-8650U; 14 GiB OS-visible RAM; 476.9 GiB NVMe | k3s server and worker |
| `yeti` | HP Spectre x360 Convertible 13-w0XX; i7-7500U; 7.1 GiB OS-visible RAM; 238.5 GiB NVMe | k3s worker |
| `longhorn` | Windows 11 workstation with WSL2 and an NVIDIA RTX 5080 | Gaming, cluster administration, and GPU inference |

The laptops run Ubuntu 26.04.1 LTS and retain 4 GiB of host swap. They use Wi-Fi with DHCP reservations. Longhorn's WSL instance administers the cluster but is not a cluster node.

## Kubernetes platform

The cluster has one k3s server on bronco and one agent on yeti. Both can run application workloads. The server uses SQLite, so the control plane has no high availability.

| Component | Configuration |
| --- | --- |
| Versions | k3s `v1.36.4+k3s1`, pinned in [version.txt](../configs/k3s/version.txt); standalone kubectl `v1.36.4` |
| Container runtime | Bundled containerd |
| Pod networking | IPv4 Flannel VXLAN; pod range `10.42.0.0/16` |
| Service networking | Service range `10.43.0.0/16`; CoreDNS for cluster DNS |
| LAN ingress | Bundled Traefik and ServiceLB, exposing TCP 80/443 on LAN nodes |
| Other bundled components | metrics-server and network policy |
| Storage | local-path volumes backed by the node hosting each volume |
| API security | Secrets encryption enabled; server certificate includes `bronco.local` |

The pod and service ranges are cluster defaults, not LAN host addresses. Persistent volumes are local to a node: moving a workload does not automatically move its data. Host swap remains enabled without a separate pod-swap experiment.

## Networking and access

LAN clients reach cluster applications through Traefik on the nodes. Kubernetes Services provide internal routing, and CoreDNS supplies names inside the cluster. Household DNS is separate; a standalone Pi-hole and service names under `apps.home.arpa` are planned but not deployed.

Host-name resolution varies by client. Windows resolves the laptop names, and the Linux hosts use mDNS names such as `bronco.local`. WSL has not reliably resolved those mDNS names. Installed cluster connections therefore use bronco's reserved IPv4 address where needed, while public configuration prompts for that value rather than storing it. Exact addresses and machine-specific overrides belong in ignored `local/` files or private installed configuration.

Administration uses SSH and private kubeconfig copies. Standalone kubectl works without sudo on both laptops, and Windows administration uses WSL. WSL validates the cluster API certificate directly; the recorded native Windows HTTPS path substituted the certificate, so it is not the documented kubectl access path.

## Services

### Cluster applications

IT-Tools is the first application, deployed from [apps/it-tools](../apps/it-tools). It has one stateless replica, a ClusterIP Service, and a hostless Traefik Ingress. The hostless rule is suitable while it is the only application using that route; assign explicit hostnames before sharing the ingress with more applications.

### Host monitoring

Prometheus runs on Bronco as a pinned standalone Helm release, with Node Exporter on both Linux nodes and kube-state-metrics on Bronco. It collects host metrics and Kubernetes object state every 30 seconds, retaining up to 48 hours on a node-local PVC. Node Exporter listens on host TCP 9100; the Prometheus UI/API is reached through localhost port-forwarding.

Grafana runs as a separate Helm release on Yeti, with its own node-local database PVC and a provisioned Prometheus datasource. Its UI is available through localhost port-forwarding; Yeti's desktop browser reaches the cluster-internal Service directly. Administrator credentials are supplied through a private Secret. Both releases retain their PVCs on Helm uninstall, but there is no monitoring backup or node failover. Installation, access, validation, and recovery are covered in [SETUP.md](SETUP.md#prometheus-host-monitoring).

Dashboard JSON is versioned alongside Grafana values and published through a repeatable API script. The node-basics dashboard is the minimal example; the eight-panel Operations homepage combines fleet/Kubernetes status with separate Bronco, Yeti, and Longhorn resource quadrants plus storage and thermal detail. Yeti displays the dashboard with screen blanking/dimming disabled.

Longhorn remains outside k3s. A user systemd service in WSL exports NVIDIA GPU utilization, power, VRAM, temperature, and clocks on loopback. A Windows portproxy exposes only its metrics port on the workstation's reserved address, and a Private-profile firewall rule allows only Bronco to scrape it. Prometheus uses a machine-specific target from ignored local values; the public base keeps that job disabled. The `Ranch / Longhorn GPU` dashboard presents the data. See [MONITORING.md](MONITORING.md) for topology, host differences, and operational boundaries. Automatic browser startup, end-to-end service probes, alerts, llama.cpp telemetry, and GitOps remain planned work.

### Workstation inference

Longhorn exposes an authenticated OpenAI-compatible API at `http://longhorn.local:19331/v1` to devices on the home LAN. A user systemd service in WSL runs llama.cpp's model router, loading one model at a time and releasing model memory after 30 idle minutes. Windows provides LAN forwarding and a logon task that keeps WSL available; stopping the inference service releases the GPU for gaming. Configuration, model selection, client setup, and lifecycle limits are documented in [INFERENCE.md](INFERENCE.md).

## Availability and recovery

This is a learning platform with a single control-plane node and node-local storage. The current recovery policy treats cluster state, secrets, and application data as disposable; there are no cluster backups. Versioned configuration and scripts reproduce the infrastructure. Revisit that policy before storing data that must survive a rebuild.

Inference is independent of k3s but depends on Longhorn being awake and WSL being available. Cluster clients must tolerate inference being stopped for gaming. A GPU-capable cluster node, GitOps, and household DNS remain backlog items rather than architectural dependencies.

## Validation boundaries

The cluster's recorded checks established node readiness, API readiness, secrets encryption, SSH access after laptop reboots, and operation with the lids closed. IT-Tools was validated through both LAN ingress and cluster DNS across nodes. These are historical checks, not a statement of live node health; see [the bootstrap log](../logs/2026_09_07.md) and [application validation](../logs/2026_09_19.md).

Monitoring validation on 2026-10-30 covered host and Kubernetes object-state metrics, authenticated Grafana queries, persistence across application restarts, and repeatable dashboard publication. On 2026-11-01, Longhorn's WSL GPU exporter, restricted Windows forwarding, Prometheus scrape, five required metric families, and all GPU dashboard queries were validated live. Browser-rendered GPU layout, full uninstall/reinstall, Windows restart/sleep recovery, and node-loss recovery remain untested; dated evidence is in the daily logs.

Inference was validated locally and from bronco and yeti on 2026-10-30, including authentication and service stop/start. Full Windows reboot/login and sleep/resume recovery remain untested. Cluster node-failure recovery, a complete firewall audit, and package-update completeness also remain open.

## References

- [K3s requirements](https://docs.k3s.io/installation/requirements), [server options](https://docs.k3s.io/cli/server), and [datastore choices](https://docs.k3s.io/datastore/ha-embedded).
- [K3s networking](https://docs.k3s.io/networking/basic-network-options), [network services](https://docs.k3s.io/networking/networking-services), and [bundled components](https://docs.k3s.io/add-ons).
- [K3s storage](https://docs.k3s.io/add-ons/storage) and [backup and restore](https://docs.k3s.io/datastore/backup-restore).
