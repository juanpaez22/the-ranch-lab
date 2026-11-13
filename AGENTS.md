# Agent instructions

## Hard rules

1. **MUST treat this repository as public.** Before publishing, review file contents and commit metadata. **NEVER** commit credentials, tokens, keys, kubeconfigs, private application data, backups, or unredacted diagnostics.
2. **MUST keep environment-specific details private.** Use hostnames in public documentation. Keep exact LAN addresses, secrets, and machine-specific overrides in ignored `local/` files. Ignore rules do not replace content review.
3. **NEVER make operational changes without authorization.** Inspect the live target first. Repository edits do not authorize installing software, changing settings, or deploying to lab machines.
4. **MUST preserve unrelated work. NEVER** reset, discard, overwrite, or publish user changes without explicit authorization.

## Overview

This public repository is the source of truth for the Ranch homelab: supported deployments, platform automation, current operational documentation, and active project work. Before non-trivial work, read `README.md` for the repository map and the README for the target app or project.

## Repo structure rules

- Choose the narrowest durable owner first. A file used by one app or project belongs with that owner, even when it is a script or configuration file.
- `apps/<name>/` is for a supported deployment unit. Keep its manifests, app-specific configuration, automation, assets, and tests together. Every app MUST have an operational README covering purpose and status, source of truth, prerequisites, operation, validation, rollback or removal, and private inputs.
- `projects/<name>/` is for exploratory or proposed work that is not yet authoritative. No supported system may depend on a project. Every project MUST have a README stating its status, goal, next decision, promotion targets, and private inputs.
- `docs/` holds current cross-cutting architecture and runbooks. `benchmarks/` holds repeatable cross-cutting measurements and their reports. Top-level `configs/` and `scripts/` are only for genuinely shared or platform-wide artifacts.
- `local/<scope>/` holds ignored private, generated, machine-specific, or disposable artifacts. When a project is adopted, promote its durable outputs into an app, shared automation/configuration, current docs, or benchmarks, then remove obsolete project files.

## Maintenance

- Before editing, inspect the target and Git status. Keep the root limited to repository-wide metadata and instructions.
- Maintain one durable source of truth. Keep generated, temporary, private, and machine-specific artifacts in ignored `local/<scope>/` or outside the repository. Make generated outputs reproducible and remove obsolete task files.
- For every mutating task, append actions, validation, outcome, and pending work to `logs/YYYY_MM_DD.md`. Update existing `docs/` in the same task when architecture, procedures, prerequisites, validation, rollback, or deployed state changes. Keep current state distinct from plans and history.
- Before committing or pushing, review the diff, status, untracked files, and metadata; validate in proportion to risk; and include only intended files. Commit or push only when requested. Write concisely and avoid unsupported claims.
