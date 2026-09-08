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
- Post-reboot SSH persistence, laptop update completion, and closed-lid operation remain unverified here.
- No k3s installation is recorded as completed.

## Networking

Use hostnames in shared configuration. Keep actual addresses in an ignored local inventory, such as `local/inventory.md`.

DHCP reservations do not automatically provide DNS. Verify name resolution from every relevant host before relying on it. Previous notes reported that `.local` resolution did not work from WSL's NAT network; this remains an open validation item.

Prefer Ethernet where practical. Begin with LAN access; remote access and public service exposure require separate decisions.

## Evolving direction

- Start with `bronco` as a single k3s server that also runs workloads, then add `yeti` as a worker. This does not provide a highly available control plane.
- Keep the Windows workstation optional for essential services. Validate WSL as a CPU worker separately from GPU scheduling.
- Keep standalone inference and Docker Compose available; the inference backend and deployment method remain open.
- Introduce GitOps and monitoring after a basic workload works across the laptops.
- Consider Proxmox later if VM isolation becomes useful. Linux VMs can become cluster nodes, but replacing a host requires a migration and data recovery plan.
- Treat persistent storage and recovery as explicit work. Git preserves configuration, not application data or cluster backups.

Planning context was adapted from existing personal homelab notes during bootstrap; future verified state belongs here.
