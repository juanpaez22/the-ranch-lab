# Backlog

Ideas are candidates, not commitments. Move items forward when there is a useful workload or a specific learning goal.

## Next steps

- [x] Deploy a disposable application and verify cross-node pod networking, cluster DNS, and LAN ingress. On 2026-09-19, traffic entered through Traefik on bronco and reached IT-Tools on yeti; both the external ingress request and an in-cluster service-DNS request returned HTTP 200.
- [ ] Set up Pi-hole on the standalone Raspberry Pi as the next homelab platform project. Give it a reserved address, create friendly application names under `apps.home.arpa`, and configure the RAX45 to forward DNS to it. Document validation, outage behavior, and rollback before making it the household resolver. Keep it outside k3s initially so a cluster outage does not also disrupt household DNS.
- [ ] Test service placement, node downtime, and recovery.
- [ ] Review live firewall rules and scope cluster access to lab peers.
- [ ] Recheck network stability if the brief SSH/cluster interruption recurs; its cause remains unknown.
- [ ] Audit remaining package updates if needed; both laptops rebooted successfully, but update completeness was not independently verified.
- [ ] Before adding workers, review VPN/WSL route overlap and standard LAN DNS options.

Bootstrap, lid behavior, hardware inventory, and workstation administration are complete; see [architecture](ARCHITECTURE.md) and [setup](SETUP.md). Application-level validation remains separate from node readiness.

## Platform experiments

- Local inference with Ollama or vLLM and an optional Open WebUI frontend.
- Docker Compose for services that benefit from a small standalone setup.
- Evaluate direct LAN access to `longhorn` WSL using mirrored networking and narrowly scoped Hyper-V firewall rules. Possible uses include SSH on a non-conflicting port, exposing a WSL service such as Ollama to lab peers, or joining WSL to k3s as a GPU-capable worker.
- Before using WSL as an always-available host, define its Windows startup/keepalive behavior. Enabling a systemd service alone does not keep a WSL instance running.
- For a k3s GPU worker, validate k3s networking and cgroup requirements, WSL route overlap, node lifecycle after Windows restarts, and NVIDIA container/GPU support before joining the cluster.
- Optional Raspberry Pi worker and multi-architecture images.
- GitOps with Argo CD after initial cluster validation.
- Prometheus and Grafana for cluster, Linux, Windows, and GPU monitoring.
- Ingress authentication, private remote access, and secret handling after local DNS is established.
- Backup and restore exercises for cluster state and application data.
- Proxmox VMs and constrained agent workloads.
- A small Rust service or Kubernetes operator when a concrete need appears.

## Application ideas

- Home Assistant and environmental sensors.
- Bird-feeder or plant camera monitoring and notifications.
- Jellyfin, Pi-hole, or network-attached storage.
- A household dashboard or private journaling application.
- Local assistants, scheduled research digests, and a technical reading pipeline.
- A personal knowledge-base service or voice assistant.

## Learning experiments

- Distributed CPU training using PyTorch and Gloo.
- GPU performance profiling and a small training pipeline.
- ROS 2 simulation or an embedded sensor project connected to the lab.

Adapted from prior personal project notes. Private datasets and personal workflow details remain outside this repository.

## Saved references

- [Community discussion: help with k3s setup on WSL](https://www.reddit.com/r/kubernetes/comments/1iqqly6/help_with_k3s_setup_on_wsl/), saved 2026-09-07 for the future WSL worker experiment. Community troubleshooting, not an installation authority.
- [Microsoft: WSL networking](https://learn.microsoft.com/en-us/windows/wsl/networking), including mirrored networking, LAN access, and Hyper-V firewall rules.
- [Microsoft: systemd in WSL](https://learn.microsoft.com/en-us/windows/wsl/systemd), including the WSL lifecycle limitation for systemd services.
- [K3s requirements](https://docs.k3s.io/installation/requirements), for node networking, firewall, and cgroup prerequisites.
- [NVIDIA: CUDA on WSL](https://docs.nvidia.com/cuda/wsl-user-guide/), for GPU support, containers, and WSL-specific limitations.
- [Ollama FAQ](https://docs.ollama.com/faq), including `OLLAMA_HOST` configuration for LAN service exposure.
