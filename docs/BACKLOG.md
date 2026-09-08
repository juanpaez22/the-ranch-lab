# Backlog

Ideas are candidates, not commitments. Move items forward when there is a useful workload or a specific learning goal.

## Next steps

- [ ] Complete Ubuntu updates on both laptops and record outcomes.
- [x] Apply and validate the [lid configuration](UBUNTU_PREFLIGHT.md). Owner confirmed closed-lid SSH; installed settings verified after reboot.
- [ ] Verify SSH after reboot and hostnames from Linux, Windows, and WSL.
- [ ] Inspect CPU, disk, networking, and available resources before cluster installation.
- [ ] Decide cluster networking ranges, endpoint, initial storage, and backup procedure.
  - See the [k3s readiness review and proposed decisions](K3S_PLAN.md).
- [ ] Install k3s on `bronco`, run a test service, then join `yeti`.
- [ ] Test service placement, node downtime, and recovery.

## Platform experiments

- Local inference with Ollama or vLLM and an optional Open WebUI frontend.
- Docker Compose for services that benefit from a small standalone setup.
- CPU-only WSL worker, followed by a separate Kubernetes GPU experiment.
- Optional Raspberry Pi worker and multi-architecture images.
- GitOps with Argo CD after initial cluster validation.
- Prometheus and Grafana for cluster, Linux, Windows, and GPU monitoring.
- Local DNS, ingress, authentication, private remote access, and secret handling.
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
