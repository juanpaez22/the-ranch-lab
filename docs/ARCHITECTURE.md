# Architecture

Current setup verified on 2026-09-07. Procedures live in [SETUP.md](SETUP.md); future work lives in [BACKLOG.md](BACKLOG.md).

## Machines

| Host | Hardware | Current role |
| --- | --- | --- |
| `bronco` | HP EliteBook x360 1030 G3; i7-8650U, 4 cores / 8 threads; 14 GiB OS-visible RAM; Toshiba 476.9 GiB NVMe | k3s server and workloads |
| `yeti` | HP Spectre x360 Convertible 13-w0XX; i7-7500U, 2 cores / 4 threads; 7.1 GiB OS-visible RAM; Samsung 238.5 GiB NVMe | k3s agent |
| `longhorn` | Windows 11 workstation, WSL2, NVIDIA GPU | Gaming/workstation; cluster administration through WSL |

Both laptops run Ubuntu 26.04.1 LTS, x86_64, kernel `7.0.0-31-generic`, with 4 GiB host swap retained. Hardware inventory was read over SSH. Post-install root filesystem availability was approximately 431 GiB on bronco and 210 GiB on yeti.

An optional Pi worker, WSL worker, and GPU integration are future experiments. WSL currently administers the cluster; it is not a node.

## Cluster decisions

- **Version:** k3s `v1.36.4+k3s1`, pinned in [version.txt](../configs/k3s/version.txt); standalone kubectl `v1.36.4`.
- **Topology:** one server on bronco and one agent on yeti. SQLite datastore; no control-plane high availability.
- **Networking:** default IPv4 Flannel VXLAN, pod range `10.42.0.0/16`, service range `10.43.0.0/16`. These are cluster defaults, not published host addresses.
- **Components:** bundled containerd, CoreDNS, Traefik, ServiceLB, metrics-server, and network policy. Traefik/ServiceLB uses node ports 80/443 for ingress.
- **Overrides:** server TLS SAN `bronco.local` and secrets encryption enabled. Host swap remains enabled; no separate pod-swap experiment.
- **Storage:** default local-path volumes. Data belongs to its node and does not automatically move with workloads.
- **Recovery:** no backups initially by explicit choice. Rebuild scripts reproduce infrastructure; cluster state, secrets, and application data are disposable.

## Access and networking

Both laptops currently use Wi-Fi and DHCP reservations. Public documentation uses hostnames; actual LAN addresses belong only in private installed configuration or ignored local inventory.

Windows resolves bare laptop names. Linux shell tools resolve their peers through mDNS `.local`, but the agent failed to join using that resolver path. The installed agent and remote kubeconfigs now use bronco's reserved IPv4 address. The public agent template prompts for the address rather than storing it. The server's additional TLS SAN can remain.

Standalone kubectl works without sudo on both laptops using private kubeconfig copies. PowerShell can administer through WSL. Native Windows HTTPS inspection substituted the API certificate; WSL validates the original certificate. No TLS-verification bypass or security-product change was applied. The Windows client remains downloaded but is not on PATH.

## Verified state and limits

- Both nodes Ready; packaged pods Running and installation jobs Completed.
- Owner output confirmed secrets encryption enabled with matching hashes.
- Workstation WSL checks confirmed node/pod status and authenticated API readiness `ok`.
- Laptop SSH survived reboot; matching lid settings were inspected and the owner confirmed access with lids closed.
- No failed system units or pending reboot markers after laptop preparation. CPU/memory cgroups and required kernel modules were available; time was synchronized. IPv4 forwarding was enabled after installation.
- A brief connection interruption during agent startup recovered automatically. Neither laptop rebooted or restarted SSH; its exact cause remains unknown. Short peer tests had no loss but variable latency.
- Dedicated cross-node application traffic, DNS, ingress, node-failure behavior, and full recovery testing remain pending. Live firewall rules and full package-update coverage were not audited.

## References

[K3s requirements](https://docs.k3s.io/installation/requirements), [network options](https://docs.k3s.io/networking/basic-network-options), [networking services](https://docs.k3s.io/networking/networking-services), [server options](https://docs.k3s.io/cli/server), [SQLite-to-etcd conversion](https://docs.k3s.io/datastore/ha-embedded), [storage](https://docs.k3s.io/add-ons/storage), [backup and restore](https://docs.k3s.io/datastore/backup-restore).
