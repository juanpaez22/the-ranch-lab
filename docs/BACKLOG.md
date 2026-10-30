# Backlog

Ideas are candidates, not commitments. Move items forward when there is a useful workload or a specific learning goal.

## Next steps

- [x] Deploy a disposable application and verify cross-node pod networking, cluster DNS, and LAN ingress. On 2026-09-19, traffic entered through Traefik on bronco and reached IT-Tools on yeti; both the external ingress request and an in-cluster service-DNS request returned HTTP 200.
- [ ] Set up Pi-hole on the standalone Raspberry Pi as the next homelab platform project. Give it a reserved address, create friendly application names under `apps.home.arpa`, and configure the RAX45 to forward DNS to it. Candidate names include `inference.apps.home.arpa`, `grafana.apps.home.arpa`, and `home.apps.home.arpa`. DNS supplies names; ingress or forwarding still determines the service port and destination. Validate resolution from ordinary LAN devices as well as lab hosts, and document outage behavior and rollback before making it the household resolver. Keep it outside k3s initially so a cluster outage does not also disrupt household DNS.
- [ ] Test service placement, node downtime, and recovery.
- [ ] Review live firewall rules and scope cluster access to lab peers.
- [ ] Recheck network stability if the brief SSH/cluster interruption recurs; its cause remains unknown.
- [ ] Audit remaining package updates if needed; both laptops rebooted successfully, but update completeness was not independently verified.
- [ ] Before adding workers, review VPN/WSL route overlap and standard LAN DNS options.

Bootstrap, lid behavior, hardware inventory, and workstation administration are complete; see [architecture](ARCHITECTURE.md) and [setup](SETUP.md). Application-level validation remains separate from node readiness.

## Local inference

### Model lifecycle

- [x] Use llama.cpp's built-in router with model presets, explicit load/unload, and idle sleep. The user systemd service and OpenCode model definitions were installed on 2026-10-30.
- Validate Windows reboot/login and sleep/resume recovery. The logon keepalive task is running, but a full workstation reboot has not been tested.
- Consider a small local control application only if existing controls leave a concrete gap. Possible additions are benchmark-backed presets, explicit CPU-offload policy, GPU memory checks, and a stable OpenAI-compatible endpoint.
- Any custom controller should manage one owned child server at a time, stay lightweight while unloaded, and verify GPU release after bounded shutdown. Keep controls on loopback until authentication and scoped LAN access are in place.

### Service exposure and integration

- [x] Validate authenticated LAN inference from bronco and yeti on TCP 19331. Windows portproxy forwards its reserved LAN address to Windows localhost, which forwards to WSL loopback; the Private-profile firewall permits the home LAN subnet and API-key authentication remains required.
- [x] Migrate inference and OpenCode from TCP 8080 to 19331 and remove the old listener/rule. The owner approved Windows elevation on the retry; health, authentication rejection, and authenticated inference passed from both peers. See [INFERENCE.md](INFERENCE.md).
- Streaming inference from yeti passed on TCP 19331; test large prompts from LAN clients separately. Add LAN DNS such as `inference.apps.home.arpa` when the household DNS path is ready; current peers resolve `longhorn.local`.
- Revisit mirrored networking or native Windows serving if localhost forwarding or WSL lifecycle becomes unreliable. Kubernetes GPU integration remains a separate experiment.
- Compare the current llama.cpp setup with Ollama or vLLM only if model management, concurrency, or client compatibility creates a concrete need. An optional Open WebUI frontend can remain independent of the API boundary.

## Agents and dashboards

### Hermes on a separate machine

- Run Hermes on another lab machine, with Longhorn providing inference through the authenticated LAN API. Choose the host and deployment method after checking resources and isolation; cluster membership is not required to call the inference API.
- Give the agent a constrained workspace, limited tools, and only the credentials it needs. Keep broad access to workstation files and cluster-admin credentials out of the agent environment.
- Start with a small, useful task and verify the complete tool loop. Test cold model loading, service downtime during gaming, and recovery without retry storms or lost task state. Decide how agent state should persist before leaving it running unattended.

### Observability and system-health display

- Run Prometheus and Grafana for cluster, Linux/Windows host, GPU, and inference health. Start with availability, CPU/RAM/disk, GPU utilization/VRAM/temperature/power, and inference readiness/latency; choose exporters and retention to fit the laptops' resources.
- Keep a system-health dashboard visible on one laptop screen. Choose the laptop later, and configure a browser display that recovers after login/reboot without interrupting its existing k3s role. Verify screen-power, session, and resource behavior separately from server uptime.
- Distinguish expected inference shutdown for gaming from failures. Add actionable alerts after the basic dashboards work; avoid routine notifications for deliberately unloaded models.

### Life and sports display

- Use the other laptop screen for a custom web application, separate from the Grafana operations dashboard. Candidate content includes calendar/agenda, tasks, weather, and selected teams' schedules/scores; decide which panels are useful before building integrations.
- Make it readable at a distance, show when data was last refreshed, and handle unavailable sources. Review data/API access, privacy, and authentication before displaying personal information or connecting accounts.
- Validate automatic browser startup, recovery, and screen behavior on the second laptop. The web application can be hosted independently of the machine displaying it; screen assignments remain open.

## Platform experiments

- Docker Compose for services that benefit from a small standalone setup.
- Evaluate direct LAN access to `longhorn` WSL for other services such as SSH on a non-conflicting port or joining WSL to k3s as a GPU-capable worker.
- Before using WSL as an always-available host, define its Windows startup/keepalive behavior. Enabling a systemd service alone does not keep a WSL instance running.
- For a k3s GPU worker, validate k3s networking and cgroup requirements, WSL route overlap, node lifecycle after Windows restarts, and NVIDIA container/GPU support before joining the cluster.
- Optional Raspberry Pi worker and multi-architecture images.
- GitOps with Argo CD after initial cluster validation.
- Ingress authentication, private remote access, and secret handling after local DNS is established.
- Backup and restore exercises for cluster state and application data.
- Proxmox VMs and constrained agent workloads.
- A small Rust service or Kubernetes operator when a concrete need appears.

## Application ideas

- Home Assistant and environmental sensors.
- Bird-feeder or plant camera monitoring and notifications.
- Jellyfin or network-attached storage.
- A private journaling application.
- Local assistants, scheduled research digests, and a technical reading pipeline.
- A personal knowledge-base service or voice assistant.

### Additional candidates to evaluate

- A small service homepage with friendly links, purpose, and runbook references, so services are easy to discover from a phone or another LAN device.
- Health checks from outside the monitored service and failure notifications, so a dashboard outage does not also hide the outage. Reuse the observability stack where practical.
- Review backup/restore needs before agent memory or dashboard data becomes valuable. Keep the current disposable-cluster policy until a recovery requirement justifies changing it.

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
- [llama.cpp server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md), including router mode, model presets, load/unload endpoints, the Web UI, and idle sleep.
- [Hermes model providers](https://hermes-agent.nousresearch.com/docs/integrations/providers), including custom OpenAI-compatible inference endpoints.
- [Prometheus overview](https://prometheus.io/docs/introduction/overview/) and [Grafana overview](https://grafana.com/docs/grafana/latest/introduction/), for the planned monitoring stack.
- [Pi-hole configuration](https://docs.pi-hole.net/ftldns/configfile/), for the planned LAN DNS service.
