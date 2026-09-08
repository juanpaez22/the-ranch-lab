# K3s installation plan

Read-only review dated 2026-09-07. These are recommendations pending agreement, not installed configuration.

## Readiness

| Check | Result |
| --- | --- |
| Hardware | Both exceed the documented role minimums; see architecture inventory. Both have NVMe storage. |
| OS and kernel | Ubuntu 26.04.1 LTS, x86_64, systemd, kernel 7.0.0-31-generic on both. Modern Linux prerequisites look suitable; this is not a vendor certification claim. |
| Reboot and health | SSH works after reboot, no failed system units, no pending reboot markers. |
| Lid behavior | Matching drop-ins installed; owner confirmed SSH with lids closed. |
| Kernel features | cgroup v2 with CPU, memory, cpuset, and pids controllers; overlay, br_netfilter, and VXLAN modules available on disk. Modules were not loaded manually. |
| Time | Both report NTP synchronization. |
| Hostnames | Unique names. Cross-laptop bare-name lookup fails; both `.local` names resolve and ping successfully. |
| Routing | Current laptop LAN routes do not overlap the default pod/service ranges. Windows, VPN, and WSL route overlap still needs checking before expansion. |
| Ports | No observed listeners on k3s ports or HTTP/HTTPS ingress ports. Availability is not proof of firewall reachability. |
| Firewall | UFW config says `ENABLED=no`; its systemd unit reports active. Firewalld inactive. Privileged live packet-filter rules were not inspected. |
| Downloads | wget checks reached installer and GitHub successfully. Registry endpoints returned HTTP 401; DNS/TLS/HTTP reachability works, but authenticated image pulls remain untested. |
| Tools | wget and iptables available; curl absent on both. |
| Forwarding | IPv4 forwarding currently disabled; must be enabled/verified as part of cluster setup. |
| Swap | Both have a 4 GiB active swap file, unused at inspection. Decide policy before bootstrap. |
| Privilege | SSH keys work; sudo requires interactive authentication. |

The earlier Python installer probe received HTTP 403, but wget's subsequent request returned HTTP 200. No installer was saved or executed. No host settings changed during this review.

## Proposed choices

- **Topology:** `bronco` server plus workloads; `yeti` agent. Start with SQLite. Accept a single control-plane failure point; conversion to embedded etcd is possible later when three reliable servers justify HA.
- **Network:** IPv4, default Flannel VXLAN. Default pod range `10.42.0.0/16` and service range `10.43.0.0/16`, subject to route review. These are proposed cluster defaults, not disclosed host addresses. Settle address ranges and network family before installation because changing them is disruptive.
- **Endpoint:** use `https://bronco.local:6443` for the initial LAN cluster and include that name in the API certificate SANs. Plan ordinary local DNS before relying on WSL or remote clients. A name working on Windows alone is insufficient.
- **Host preparation:** install curl for the documented workflow or use existing wget; confirm live firewall policy and forwarding. Recommend disabling swap for a conventional initial baseline, with a documented reversible change. Swap is a policy choice to check against the selected release, not claimed here as a universal k3s prohibition.
- **Packaged components:** retain containerd, CoreDNS, Traefik, ServiceLB, metrics-server, and network policy. No separate Docker installation is required for the k3s runtime. Traefik with ServiceLB uses node ports 80/443, so reserve them for cluster ingress.
- **Storage:** start with local-path volumes for disposable experiments. Data stays on its node and does not automatically follow a workload to another laptop. Choose off-node backup storage before storing important data.
- **Version and configuration:** select a stable release at installation time and pin the same exact version on both machines. Version non-secret `config.yaml` templates; keep tokens, real addresses, and admin kubeconfigs outside Git. Enable secrets encryption at rest and retain restrictive kubeconfig permissions.
- **Recovery:** back up the datastore and server token outside the node and repository; back up application volumes separately. Test recovery before calling stateful services reliable.

## Remaining validation

Inspect live firewall rules with interactive sudo; allow TCP 6443 to the server, UDP 8472 between nodes for VXLAN, and TCP 10250 between nodes for metrics. Keep these restricted to trusted lab peers. Test pod-to-pod networking, DNS, image pulls, and ingress after bootstrap. Do not infer UDP reachability from SSH or ping.

## Sources

- [Installation](https://docs.k3s.io/installation)
- [Requirements](https://docs.k3s.io/installation/requirements)
- [Configuration](https://docs.k3s.io/installation/configuration)
- [Network options](https://docs.k3s.io/networking/basic-network-options)
- [Networking services](https://docs.k3s.io/networking/networking-services)
- [Server options](https://docs.k3s.io/cli/server)
- [Embedded etcd and SQLite conversion](https://docs.k3s.io/datastore/ha-embedded)
- [Storage](https://docs.k3s.io/add-ons/storage)
- [Backup and restore](https://docs.k3s.io/datastore/backup-restore)
