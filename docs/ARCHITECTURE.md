# Architecture

Living notes, expected to evolve as the lab is built. Planned roles below are proposals, not evidence of deployed services.

## Machines

| Host | Current machine | Proposed role |
| --- | --- | --- |
| `bronco` | Ubuntu laptop, 16 GB RAM | Always-on k3s server and worker |
| `yeti` | Ubuntu laptop, 8 GB RAM | Always-on k3s worker; constrained agent experiments |
| `longhorn` | Windows 11 workstation with WSL2 and NVIDIA GPU | Gaming, local inference, optional CPU-only WSL worker |
| Undecided | Optional Raspberry Pi | Lightweight ARM worker |

## Reported baseline

- Earlier lab notes recorded DHCP reservations and successful SSH between the three named machines on 2026-08-30. These were not reverified during repository bootstrap.
- Post-reboot SSH and installed lid settings were verified on 2026-09-07; the owner also confirmed SSH with lids closed. Package-update completeness has not been audited.
- K3s v1.36.4+k3s1 is installed: bronco is the server, yeti the agent. Both were verified Ready from the workstation's WSL client on 2026-09-07; packaged pods were healthy and install jobs completed. Owner-provided output confirmed secrets encryption enabled. See [cluster access](CLUSTER_ACCESS.md).

## Initial SSH preflight: 2026-09-07 (resolved)

- Both bare hostnames resolved from the Windows workstation during an SSH attempt.
- `bronco` reached SSH authentication but rejected the available noninteractive authentication.
- `yeti` lacked a trusted host-key entry for the requested hostname; strict verification stopped the connection.
- Neither the Windows nor default WSL user's SSH directory contained a private-key file. Password login may have been used previously; this was not verified.
- No remote inspection commands executed. CPU, disk, OS release, and live memory details remain unverified; the machine table above reflects prior planning notes.
- Subsequently resolved: after the owner configured key authentication, both hosts accepted noninteractive SSH with strict host-key checking. See the verified inventory below.

## Verified laptop inventory: 2026-09-07

Collected via read-only SSH after key setup. No packages or host settings were changed by the inspection.

| Specification | `bronco` | `yeti` |
| --- | --- | --- |
| Model | HP EliteBook x360 1030 G3 | HP Spectre x360 Convertible 13-w0XX |
| CPU | Intel Core i7-8650U, 4 cores / 8 threads | Intel Core i7-7500U, 2 cores / 4 threads |
| Architecture | x86_64 | x86_64 |
| OS-reported usable RAM (`free -h`) | 14 GiB | 7.1 GiB |
| Swap configured | 4 GiB | 4 GiB |
| NVMe disk | Toshiba KXG50ZNV512G, 476.9 GiB | Samsung MZVLW256HEHP-000H1, 238.5 GiB |
| Root filesystem available at inspection | 432 GiB | 210 GiB |
| OS | Ubuntu 26.04.1 LTS | Ubuntu 26.04.1 LTS |
| Running kernel | 7.0.0-29-generic | 7.0.0-30-generic |
| Failed system services | `grub2-common.service` | None |
| Reboot-required marker | Present | Present |

Both machines were reachable by bare hostname from Windows. Both reported approximately one hour of uptime. Neither exposed a `k3s` executable in the SSH command's PATH; this is not an exhaustive installation audit.

The inventory above predates the lid installation and subsequent reboot. Follow-up on 2026-09-07 found both running kernel `7.0.0-31-generic`, no failed system units, and no reboot-required markers. The earlier `grub2-common.service` failure on `bronco` was no longer present; its original cause was not diagnosed. Both have the versioned lid settings installed, and the owner confirmed closed-lid SSH access.

See [k3s readiness and proposed configuration](K3S_PLAN.md) for the installation preflight.

## Networking

Use hostnames in shared configuration. Keep actual addresses in an ignored local inventory, such as `local/inventory.md`.

DHCP reservations do not automatically provide DNS. Current checks show Windows can reach both bare hostnames, while the laptops resolve and ping each other using `.local` names only. Previous notes reported that `.local` resolution did not work from WSL's NAT network; this remains an open validation item.

Prefer Ethernet where practical. Begin with LAN access; remote access and public service exposure require separate decisions.

## Evolving direction

- Start with `bronco` as a single k3s server that also runs workloads, then add `yeti` as a worker. This does not provide a highly available control plane.
- Keep the Windows workstation optional for essential services. Validate WSL as a CPU worker separately from GPU scheduling.
- Keep standalone inference and Docker Compose available; the inference backend and deployment method remain open.
- Introduce GitOps and monitoring after a basic workload works across the laptops.
- Consider Proxmox later if VM isolation becomes useful. Linux VMs can become cluster nodes, but replacing a host requires a migration and data recovery plan.
- Treat persistent storage and recovery as explicit work. Git preserves configuration, not application data or cluster backups.

Planning context was adapted from existing personal homelab notes during bootstrap; future verified state belongs here.
