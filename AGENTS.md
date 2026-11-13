# Agent instructions

- This repository is public. Never commit private information, credentials, tokens, keys, kubeconfigs, application data, backups, or unredacted diagnostic output. Review file contents and commit metadata before publishing.
- Use hostnames in public documentation. Keep exact LAN addresses and machine-specific overrides in ignored `local/` files. Ignore rules are not a substitute for reviewing changes.
- Before changing anything, inspect the target and Git status, confirm the request authorizes the change, and preserve unrelated work. Repository edits do not authorize installing software or changing lab machines.
- Keep the repository root for repo-wide metadata and instructions. Do not add application, project, generated, or scratch files there.
- Put deployable services and their owned manifests, source, assets, and scripts in `apps/<name>/`. Put self-contained non-deployed work in `projects/<name>/`, repeatable measurements in `benchmarks/<name>/`, and shared automation or configuration in `scripts/` or `configs/`.
- Every `apps/<name>/` and `projects/<name>/` directory must have a concise README covering purpose and status, source of truth, prerequisites, operation, validation, rollback or removal, and private inputs.
- Keep private, machine-specific, generated, and temporary artifacts in ignored `local/<scope>/` or outside the repository. Maintain one durable source of truth, make generated outputs reproducible, and remove obsolete task-created files before handoff.
- Every mutating task must append a concise entry to the local day's `logs/YYYY_MM_DD.md`, including changes, validation, outcome, and pending work. Never include full transcripts or sensitive output.
- If a change affects architecture, deployed state, procedures, prerequisites, validation, rollback, or future operation, update the relevant existing `docs/` page in the same task. A fresh system must be reproducible from versioned configuration and documentation; logs are audit history, not current instructions.
- Prefer existing documents: architecture for current state and decisions, setup for procedures, and backlog for future work. Keep verified state distinct from plans, assumptions, and historical results.
- Before committing or pushing, review the diff, status, untracked files, and commit metadata; run proportionate validation; and include only the intended task files. Commit or push only when requested.
- Keep structure and writing concise. Add automation or dependencies only when needed; avoid em dashes and unsupported claims.
