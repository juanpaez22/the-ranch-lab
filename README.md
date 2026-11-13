# The Ranch Lab 🐂

The public source of truth for the Ranch homelab: supported deployments, shared platform automation, current runbooks, repeatable experiments, and projects that may become part of the lab.

## Where work belongs

Organize by ownership first and artifact type second. A deployment's script belongs with that deployment; only automation used across owners belongs in the shared `scripts/` directory.

| Location | Use it when | Do not use it for |
| --- | --- | --- |
| `apps/<name>/` | The lab formally supports or deploys the unit. Co-locate its manifests, configuration, scripts, assets, and tests. | Proposals, scratch work, or unrelated shared tooling. |
| `projects/<name>/` | Work is exploratory, proposed, or incubating and no supported system depends on it. | Authoritative deployed state. |
| `docs/` | Information is current and useful across multiple apps or the whole lab. | Proposals, dated experiment reports, or app-owned details. |
| `benchmarks/<area>/` | A measurement is repeatable and produces comparable evidence across models, apps, or versions. | One-off diagnostics or operational runbooks. |
| `configs/` and `scripts/` | Configuration or automation is genuinely shared across owners or operates the platform itself. | Files with one clear app or project owner. |
| `local/<scope>/` | Material is private, machine-specific, generated, or disposable. This directory is ignored. | Any durable source of truth. |
| `logs/` | A dated audit records what changed, how it was validated, and what remains. | Current procedures or architecture. |

Every app has a concise operational README. Every project README states its status, goal, next decision, promotion targets, and private inputs. When a project is adopted, move its durable outputs to the owning app, shared platform directories, current documentation, or benchmarks; remove the project once it no longer has independent work to track.

## Current documentation

- [Architecture](docs/ARCHITECTURE.md): current machines, roles, and boundaries.
- [Setup](docs/SETUP.md): cluster installation, administration, and rebuild procedures.
- [Inference](docs/INFERENCE.md): local/LAN model serving, GPU lifecycle, and client setup.
- [Monitoring](docs/MONITORING.md): Prometheus/Grafana topology, telemetry, and host boundaries.
- [Backlog](docs/BACKLOG.md): accepted gaps and next steps.
