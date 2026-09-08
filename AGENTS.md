# Agent instructions

- This repository is public. Never commit private information, credentials, tokens, keys, kubeconfigs, application data, backups, or unredacted diagnostic output. Review file contents and commit metadata before publishing.
- Use hostnames in public documentation. Keep exact LAN addresses and machine-specific overrides in ignored `local/` files. Ignore rules are not a substitute for reviewing changes.
- Update documentation liberally as decisions, procedures, and verified behavior change. Keep current state distinct from plans, assumptions, and historical reports.
- Log major actions in `logs/YYYY_MM_DD_topic.md`, using the session's local date. Record purpose, actions, validation, outcomes, and pending work. Avoid full transcripts and sensitive output.
- Before operational changes, inspect the target and confirm the user's request authorizes them. Repository edits do not authorize installing software or changing settings on lab machines.
- Preserve unrelated changes. Never reset, discard, or overwrite user work without explicit approval.
- Document prerequisites, application steps, validation, and rollback for operational configurations and scripts. Prefer repeatable procedures and versioned configuration.
- Keep the structure simple. Add automation and dependencies when needed, and validate in proportion to risk.
- Write concisely. Avoid em dashes and unsupported claims about completion or reliability.
