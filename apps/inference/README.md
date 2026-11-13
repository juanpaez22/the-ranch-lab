# Inference

Status: supported deployment on Longhorn's Ubuntu WSL environment.

This app owns the llama.cpp router service, model presets, OpenCode provider configuration, and Windows-side helper scripts. The current architecture and full operating procedure are in [the inference runbook](../../docs/INFERENCE.md).

## Source of truth

- `systemd/inference.service`: supervised router process.
- `config/models.ini`: router model presets.
- `config/opencode.jsonc`: versioned OpenCode provider and model entries.
- `scripts/`: installation and Windows/WSL networking helpers.

The runbook documents prerequisites, installation, normal operation, validation, recovery, and rollback. Repository files are not the installed copies; changing them does not change the live workstation.

Keep API keys, exact LAN addresses, installed-file backups, model caches, and diagnostics outside Git or in ignored `local/inference/`. Stop and disable the user service to remove the active deployment; remove installed copies only after preserving any private inputs needed for recovery.
