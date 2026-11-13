# Working in the Ranch Lab

## Repository purpose

This public repository is the durable source of truth for the Ranch homelab: supported deployments, shared platform automation, current runbooks, repeatable experiments, and work being considered for adoption.

Before substantial work, read the root `README.md` for the repository map, then read the README and relevant runbook for the area being changed. There is no repository-wide build or test command; use the target's documented validation.

## Non-negotiable boundaries

1. **Protect private data.** Treat every tracked file and commit as public. **NEVER** commit credentials, tokens, keys, kubeconfigs, private application data, backups, exact LAN addresses, machine-specific overrides, or unredacted diagnostics. Put private or machine-specific material in ignored `local/<scope>/` files. Ignore rules do not replace content review.
2. **Separate repository work from operations.** Editing this repository does not authorize installing software, changing settings, deploying, or otherwise mutating a lab machine. **NEVER** make an operational change without explicit authorization; inspect the live target immediately before an authorized change.
3. **Preserve work and scope.** **NEVER** reset, discard, overwrite, publish, or include unrelated user work. Make the smallest coherent change that satisfies the request.
4. **Report only verified state.** Distinguish current state, historical results, proposals, and assumptions. Do not claim that a repository edit changed a live system or that a check passed unless it was actually observed.

## Start every task

1. Inspect `git status` and the files already in scope. Preserve pre-existing changes.
2. Read the nearest source of truth: the target app or project README for ownership and lifecycle; `docs/` for current cross-cutting architecture or procedures; `benchmarks/` for measurement methodology and results.
3. Decide whether the request is repository-only or operational. If operational, confirm authorization and inspect the target before acting.
4. Place new work using the rules below. Prefer updating an existing source of truth over creating another document, script, or configuration path.

## Place files by ownership and lifecycle

Choose the first matching destination:

1. **Private, machine-specific, disposable, or unreviewed generated output:** ignored `local/<scope>/` or outside the repository. Track generated output only when the repository deliberately owns it and its reproduction path.
2. **Owned by one supported deployment:** `apps/<name>/`. Keep that app's manifests, configuration, scripts, assets, and tests together.
3. **Exploratory, proposed, or not yet authoritative:** `projects/<name>/`. A supported system **MUST NOT** depend on files in `projects/`.
4. **A repeatable comparative measurement:** `benchmarks/<area>/`, including its harness, reviewed results, and reports.
5. **Current knowledge shared across the lab:** `docs/`. Do not put proposals, dated benchmark reports, or app-owned instructions here.
6. **Genuinely shared platform configuration or automation:** top-level `configs/` or `scripts/`. If only one app or project uses it, it belongs with that owner.
7. **Dated audit history:** `logs/YYYY_MM_DD.md`. Logs record work; they are not the current procedure or architecture.

Keep the repository root limited to repository-wide metadata and instructions.

Every app README **MUST** state its purpose and status, owned source of truth, prerequisites, operation, validation, rollback or removal, and private inputs. Every project README **MUST** state its status, goal, next decision, intended promotion targets, and private inputs.

When a project is adopted, move each durable output to its final owner (`apps/`, `docs/`, `benchmarks/`, or shared platform directories), update references, and remove obsolete project files. Do not leave a second source of truth behind.

## Make and document changes

- Edit the authoritative source, not an installed copy or generated output. If generated artifacts are tracked, keep their generator and reproduction path current.
- For every mutating task, append a concise entry to `logs/YYYY_MM_DD.md` containing the actions, validation, outcome, and pending work. Never include secrets or raw sensitive output.
- Update the relevant existing `docs/` page in the same task when architecture, deployed state, prerequisites, procedures, validation, recovery, or rollback changes. Keep plans in `projects/` or the backlog until adopted.
- Keep exact commands and operational details in the owning README or runbook rather than expanding this always-loaded file.

## Validate and hand off

1. Run the narrowest relevant checks documented by the target. Validate syntax and rendering for changed configuration; test behavior when practical. Live validation requires operational authorization.
2. Review the final diff, status, and untracked files. Check public content and commit metadata for private or machine-specific data.
3. Confirm that links and moved-file references resolve and that obsolete files or duplicate sources of truth are gone.
4. Report what changed, what was validated, what remains unverified, and whether any live state changed.
5. Commit or push only when explicitly requested. Before either, include only intended files and recheck the public-data boundary.
