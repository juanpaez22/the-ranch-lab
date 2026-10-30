# Local inference

Last updated: 2026-10-30

Longhorn provides local GPU inference for OpenCode and other OpenAI-compatible clients on the home LAN. The service is designed for a shared gaming workstation: models can be switched without changing client endpoints, and inference can be stopped when another application needs the GPU.

This runbook covers the service design, normal operation, configuration, installation, and recovery. The surrounding homelab is described in [ARCHITECTURE.md](ARCHITECTURE.md); planned extensions belong in [BACKLOG.md](BACKLOG.md#local-inference).

## Service design

A user systemd service runs llama.cpp in router mode inside Ubuntu WSL. The router keeps the API available and starts a separate inference process when a client requests a model. Systemd supervises the process tree and provides logs and start/stop controls; the router handles model selection, loading, unloading, and idle sleep.

The service is independent of k3s. This keeps GPU use under workstation control and avoids making model experiments depend on cluster GPU integration. A stable OpenAI-compatible API lets clients remain unchanged if serving later moves to native Windows or another deployment.

For LAN requests, Windows accepts TCP 19331 on its reserved LAN address and forwards to Windows localhost on the same port. WSL's existing localhost forwarding carries the connection to the router. This uses default WSL NAT without storing the changing guest address or requiring mirrored networking.

| Setting | Configuration |
| --- | --- |
| Local API | `http://127.0.0.1:19331/v1` |
| LAN API | `http://longhorn.local:19331/v1` |
| Runtime | llama.cpp `b11552`, using CUDA on an RTX 5080 with 16 GB VRAM |
| Supervisor | User systemd service `inference.service` |
| Model lifecycle | One loaded model at most; none loaded at startup; sleep after 1,800 idle seconds |
| Inference capacity | One 131,072-token slot per loaded model |
| Client default | `llama-cpp/gemma-4-26b-a4b-q4` in OpenCode |
| Access | Windows Private-profile firewall scoped to the home LAN subnet; shared bearer key required |
| WSL availability | Linger-enabled user manager and Windows logon task `RanchInference-WSL` |

The bearer key authenticates both inference and router-management requests. HTTP does not encrypt those requests, so this endpoint is intended for the trusted home LAN. Guest networks, routed subnets, remote access, and TLS require separate configuration. Clients do not need to join the Kubernetes cluster.

## Everyday operation

Run these commands in WSL as the user who owns the service:

```bash
systemctl --user start inference
systemctl --user stop inference
systemctl --user status inference
journalctl --user -u inference -n 50 --no-pager
```

Stop the service before gaming. This shuts down the router and its child processes, preventing a remote agent from loading a model again. Start it afterward to restore the API; a model loads only when requested.

Unloading and idle sleep are useful while keeping the API available, but neither reserves the GPU for other work:

| Action | Result |
| --- | --- |
| Stop service | Stops the API and all owned inference processes |
| Unload model | Releases that model's allocations; the next request may reload it |
| Idle sleep | Releases model and KV-cache memory after 30 idle minutes; a request wakes it again |
| Disable service | Prevents automatic startup on later WSL boots; manual start remains possible |

Some CUDA/driver memory can remain while a model sleeps. Use service stop when GPU release matters. A manually stopped, enabled service can start again when WSL boots; use `systemctl --user disable --now inference` to suppress that startup as well.

### Model routing

Inference requests must include a known model ID. The router does not fall back to whichever model happens to be loaded:

- A request for the loaded model reuses it.
- A request for an unloaded model loads it. With the one-model limit, a busy model finishes its requests before it can be evicted.
- A missing or unknown model ID returns an error.

OpenCode's default is a client setting. If multiple clients repeatedly request different models, they can cause repeated loading and unloading. Use a common model for background agents when predictable latency matters.

### Management API

In WSL, read the key from its private file. The following requests list models, preload one, and unload it without deleting its files:

```bash
inference_key="$(tr -d '\r\n' < ~/.config/llama.cpp/api.key)"
curl --fail -H "Authorization: Bearer $inference_key" \
  http://127.0.0.1:19331/models | jq '.data[] | {id, status: .status.value}'
curl --fail -H "Authorization: Bearer $inference_key" -H 'Content-Type: application/json' \
  -d '{"model":"gemma-4-e4b-q4"}' http://127.0.0.1:19331/models/load
curl --fail -H "Authorization: Bearer $inference_key" -H 'Content-Type: application/json' \
  -d '{"model":"gemma-4-e4b-q4"}' http://127.0.0.1:19331/models/unload
```

`DELETE /models` deletes cached files and is not part of normal model switching.

## Models and client configuration

The installed presets use cached instruction-tuned GGUFs, text input/output, Flash Attention, Q4_0 K/V cache, and automatic fitting. The service runs with `--offline`, so download weights before adding a preset.

| Preset ID | Model / quantization | Notes |
| --- | --- | --- |
| `gemma-4-26b-a4b-q4` | Gemma 4 26B-A4B Q4_0 | OpenCode default |
| `gemma-4-e4b-q4` | Gemma 4 E4B Q4_0 | Smaller alternative |
| `gemma-4-12b-q4` | Gemma 4 12B Q4_0 | OpenCode tool-use issue noted below |
| `gemma-4-31b-q4` | Gemma 4 31B Q4_0 | Substantial CPU offload on this GPU |
| `qwen3.8-27b-q4` | Qwen3.8 27B Q4_K_M | Substantial CPU offload on this GPU |

All current presets allocate one 128K slot. The model's native ceiling, the server allocation, and the client's request budget are separate limits. OpenCode declares 131,072 total tokens, up to 122,880 input tokens, and up to 8,192 output tokens, with automatic conversation compaction. Change client and server limits together, and verify the actual allocation through `/props?model=<id>`. The default model supports up to 256K natively; E4B's ceiling is 128K.

OpenCode assembles instructions, conversation, files, and tool results into each request. The model produces text or tool calls; OpenCode executes permitted tools and sends their results back. Files and stored chat history persist independently of the model's KV cache.

### OpenCode

The versioned [provider configuration](../configs/opencode/opencode.jsonc) contains all five model entries. It reads authentication from `~/.config/llama.cpp/api.key` rather than embedding a credential.

Select a model through `/models` in the interactive client, or pass its provider/model ID:

```bash
opencode --model llama-cpp/gemma-4-e4b-q4
```

Ensure `~/.opencode/bin` is on PATH, or use `~/.opencode/bin/opencode` directly. Restart existing OpenCode sessions after installing configuration changes.

### Clients on other machines

Use an OpenAI-compatible provider with these settings:

| Field | Value |
| --- | --- |
| Base URL | `http://longhorn.local:19331/v1` |
| API key | Shared key, stored privately on the client |
| Model | Router preset ID, such as `gemma-4-26b-a4b-q4` |
| Context and output limits | Match the selected preset; current OpenCode limits are 128K total and 8K output |
| Timeouts | Allow for model loading and prompt processing; OpenCode uses 600,000 ms header/chunk timeouts |

For remote OpenCode, reuse the model definitions but change `settings.baseURL` and the key-file reference. The `llama-cpp/` prefix is OpenCode's provider namespace; the model ID sent to the router does not include that prefix. Hermes uses the same URL, credential, and preset ID through its custom-provider settings.

The mDNS name `longhorn.local` works from bronco and yeti, but resolution depends on the client and network. Use another working local DNS name or a private address override where necessary. Dedicated `apps.home.arpa` DNS remains planned work.

### Adding or changing a preset

1. Download the model once with `llama download -hf <repo>:<quant>`. Never run concurrent downloaders for the same model/cache.
2. Add a section to [models.ini](../configs/inference/models.ini). A new preset ID lets you compare settings while preserving a known configuration.
3. Install the preset file and call the authenticated `GET /models?reload=1` endpoint. Changed running presets are unloaded, so refresh between tasks.
4. Add a matching OpenCode model entry with appropriate capabilities and context/input/output limits, then install the client config.
5. Test an inference request, inspect the allocated context, and exercise the client's tool loop.

For example, this preset reuses a cached model with a smaller slot:

```ini
[gemma-4-e4b-32k]
hf-repo = ggml-org/gemma-4-E4B-it-GGUF:Q4_0
ctx-size = 32768
```

Its OpenCode entry must declare a 32,768-token context budget. Model-specific settings inherit from `[*]`; router command-line arguments take precedence over presets. Keep settings that vary by model in the preset file.

The [benchmark report](INFERENCE_BENCHMARK_2026_10_11.md) records throughput across context allocations, not model quality or filled-context performance. To repeat it, stop the router, run [the benchmark harness](../benchmarks/llama-context-sweep/README.md), and start the router again afterward.

## Installation

Run WSL commands from the repository root unless stated otherwise. Prerequisites are systemd-enabled Ubuntu WSL with working NVIDIA GPU access; Bash, curl, jq, OpenSSL, tar, and `sha256sum`; and an existing OpenCode installation for the client steps. Windows networking/task installation requires elevated Windows PowerShell, a reserved LAN address for Longhorn, and the intended LAN subnet.

### Configuration files

| Source | Installed location |
| --- | --- |
| [inference.service](../configs/inference/inference.service) | `~/.config/systemd/user/inference.service` |
| [models.ini](../configs/inference/models.ini) | `~/.config/llama.cpp/models.ini` |
| [opencode.jsonc](../configs/opencode/opencode.jsonc) | `~/.config/opencode/opencode.jsonc` |
| Windows scripts in [scripts/inference/](../scripts/inference/) | `%USERPROFILE%\.config\RanchInference` |

These are installed copies. Editing the repository does not change the running configuration; install the changed files and reload or restart the relevant component. Keep API keys, concrete LAN addresses, backups, and diagnostic output outside Git. Public examples use hostnames or prompts for private values.

### Runtime

The pinned runtime is llama.cpp `b11552`, installed under `~/.local/opt/llama.cpp/b11552`, with user-local symlinks for `llama`, `llama-cli`, and `llama-server`. It includes the release's CUDA 12.8 libraries; WSL uses the Windows NVIDIA driver for `libcuda.so.1`. No Linux NVIDIA driver or CUDA toolkit was installed.

The release archives and checksums come from the official llama.cpp GitHub release. Verify checksums before installing a newer build, install it in a new versioned directory, repoint the symlinks only after validation, and retain the previous directory for rollback.

For the installed release, the verified archives were:

| Archive | SHA256 |
| --- | --- |
| `llama-b11552-bin-ubuntu-cuda-12.8-x64.tar.gz` | `8443251b678d8c4bf4720b4b9c17ff8f687f1b06081f08ff2017999cba18ae7f` |
| `cudart-llama-b11552-bin-ubuntu-cuda-12.8-x64.tar.gz` | `e8b04db589bdf3681d960ea41c516d3f6e2ccb9c9fe2050f5bc74cb875c4a607` |

The binaries were extracted together into the versioned directory. The three user-local symlinks point directly to that directory.

To reproduce the installation without replacing an existing versioned directory:

```bash
(
set -euo pipefail

release=b11552
binary_archive="llama-${release}-bin-ubuntu-cuda-12.8-x64.tar.gz"
runtime_archive="cudart-llama-${release}-bin-ubuntu-cuda-12.8-x64.tar.gz"
asset_base="https://github.com/ggml-org/llama.cpp/releases/download/${release}"
staging_dir="$(mktemp -d)"
install_dir="$HOME/.local/opt/llama.cpp/$release"

if [[ -e "$install_dir" ]]; then
  printf 'Refusing to replace existing directory: %s\n' "$install_dir" >&2
  exit 1
fi

curl --fail --location --output "$staging_dir/$binary_archive" \
  "$asset_base/$binary_archive"
curl --fail --location --output "$staging_dir/$runtime_archive" \
  "$asset_base/$runtime_archive"

cd "$staging_dir"
printf '%s  %s\n' \
  '8443251b678d8c4bf4720b4b9c17ff8f687f1b06081f08ff2017999cba18ae7f' \
  "$binary_archive" \
  'e8b04db589bdf3681d960ea41c516d3f6e2ccb9c9fe2050f5bc74cb875c4a607' \
  "$runtime_archive" | sha256sum --check

mkdir -p "$install_dir" "$HOME/.local/bin"
tar -xzf "$binary_archive" -C "$install_dir" --strip-components=1
tar -xzf "$runtime_archive" -C "$install_dir" --strip-components=1
ln -sfn "$install_dir/llama" "$HOME/.local/bin/llama"
ln -sfn "$install_dir/llama-cli" "$HOME/.local/bin/llama-cli"
ln -sfn "$install_dir/llama-server" "$HOME/.local/bin/llama-server"
)
```

The temporary staging directory may be removed after validation. Keep the previous versioned installation until the new build and symlinks have been tested.

Ensure `~/.local/bin` is on the shell `PATH`, or invoke the three binaries by their full paths.

Validate the active installation:

```bash
llama-server --version
llama-server --list-devices
ldd ~/.local/opt/llama.cpp/b11552/libggml-cuda.so
```

Download the default model through llama.cpp so it uses the standard Hugging Face cache and can resume an interrupted transfer:

```bash
llama download -hf ggml-org/gemma-4-26B-A4B-it-GGUF:Q4_0
```

Repeat the download for each additional preset you intend to use, taking its Hugging Face reference from `models.ini`. The router can start without every preset's weights, but an uncached model cannot load in offline mode. Do not start a second downloader for the same model and cache while one is active.

### Router and OpenCode

Before replacing an existing installation, stop its inference process and back up its service, preset, and OpenCode files. Create the configuration directories, install the versioned files, and create a key only if one does not already exist:

```bash
install -d -m 0700 ~/.config/llama.cpp ~/.config/systemd/user ~/.config/opencode
install -m 0600 configs/inference/models.ini ~/.config/llama.cpp/models.ini
install -m 0644 configs/inference/inference.service ~/.config/systemd/user/inference.service
install -m 0600 configs/opencode/opencode.jsonc ~/.config/opencode/opencode.jsonc
if [[ ! -e ~/.config/llama.cpp/api.key ]]; then
  (umask 077; openssl rand -hex -out ~/.config/llama.cpp/api.key 32)
fi
sudo loginctl enable-linger "$USER"
systemctl --user daemon-reload
systemctl --user enable --now inference
```

Linger starts the user service manager when WSL boots. The router starts without loading a model. After updating only the preset, refresh the model catalog; after changing the unit, run `daemon-reload` and restart the service.

### Windows networking and startup

The scripts have separate responsibilities:

- [Set-InferenceLan.ps1](../scripts/inference/Set-InferenceLan.ps1) creates or removes the listener and `RanchInference-19331` firewall rule. It accepts `-ListenAddress`, optional `-Port` (default 19331), and `-AllowedClients` as IPv4 addresses, CIDRs, or `LocalSubnet`.
- [Install-InferenceKeepalive.ps1](../scripts/inference/Install-InferenceKeepalive.ps1) registers or updates the `RanchInference-WSL` logon task, then starts it. Its `-Distribution` argument defaults to `Ubuntu`.
- [Keep-InferenceWsl.ps1](../scripts/inference/Keep-InferenceWsl.ps1) is the task action. It holds a foreground `sleep infinity` process in the chosen distribution without starting a manually stopped inference service.

From Windows PowerShell at the repository root, copy the scripts to their installed location:

```powershell
$stateDir = Join-Path $env:USERPROFILE '.config\RanchInference'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
Copy-Item scripts/inference/*.ps1 $stateDir
```

Use this normal user directory rather than AppData, which packaged applications can redirect to a private cache that Task Scheduler does not see.

Then, in elevated Windows PowerShell:

```powershell
$stateDir = Join-Path $env:USERPROFILE '.config\RanchInference'
$listen = Read-Host 'Longhorn reserved LAN IPv4 address'
$scope = Read-Host 'Home LAN IPv4 CIDR'
& "$stateDir\Set-InferenceLan.ps1" -ListenAddress $listen -Port 19331 -AllowedClients @($scope)
& "$stateDir\Install-InferenceKeepalive.ps1" -Distribution Ubuntu
```

The deployed rule permits the home LAN CIDR on the Private profile. Omitting `-AllowedClients` uses `LocalSubnet`, which can cover multiple directly connected subnets. Explicit CIDR scope reproduces the intended home-LAN boundary. Keep Windows localhost port 19331 free for WSL forwarding.

If script execution is restricted, launch the reviewed installer with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <script>` and its arguments. This applies to that process; changing the machine execution policy is unnecessary.

The scheduled task runs with the logged-on user's limited privileges and keeps WSL available after login. It does not provide service before login or while Windows sleeps. Full reboot/login and sleep/resume recovery still require validation.

## Validation and troubleshooting

Check service health, authenticated inference, client tools, and LAN access separately. A healthy router can have no model loaded, and a model that generates text can still fail an agent's tool workflow.

Start with a local smoke request:

```bash
curl --fail http://127.0.0.1:19331/health
inference_key="$(tr -d '\r\n' < ~/.config/llama.cpp/api.key)"
curl --fail -H "Authorization: Bearer $inference_key" -H 'Content-Type: application/json' \
  -d '{"model":"gemma-4-26b-a4b-q4","messages":[{"role":"user","content":"Reply with exactly: ready"}],"temperature":0,"max_tokens":128,"chat_template_kwargs":{"enable_thinking":false}}' \
  http://127.0.0.1:19331/v1/chat/completions
curl --fail -H "Authorization: Bearer $inference_key" \
  'http://127.0.0.1:19331/props?model=gemma-4-26b-a4b-q4' | \
  jq '{n_ctx: .default_generation_settings.n_ctx, total_slots, is_sleeping}'
```

Confirm `n_ctx` is 131072 and `total_slots` is 1. An unauthenticated `/v1/models` request should return HTTP 401. Repeat health and an authenticated completion from another LAN machine using `longhorn.local` and a securely supplied copy of the key.

Test the complete client tool loop from the target repository:

```bash
opencode run --standalone --model llama-cpp/gemma-4-26b-a4b-q4 \
  "Use the read tool to read README.md. Do not edit anything. Reply with only its first Markdown heading."
```

Local OpenCode tool use, authenticated LAN inference from bronco and yeti, streaming from yeti, model switching, explicit unload, idle sleep/wake, and service stop/start have been exercised. Detailed outcomes are in [the daily log](../logs/2026_10_30.md). Large filled-context behavior, full workstation lifecycle recovery, and sustained agent reliability remain separate tests.

One known limitation is Gemma 4 12B's OpenCode tool use: a Read-tool attempt produced malformed input and stalled even though its GGUF matched the publisher's size and SHA-256. It generated valid arguments for a simpler direct tool schema. The workflow-specific cause remains unresolved; do not assume a redownload will fix it.

| Symptom | Checks |
| --- | --- |
| Local connection refused | Service state, journal, configured port, and conflicting listeners |
| Windows cannot reach WSL localhost | WSL availability and localhost forwarding before the LAN firewall |
| LAN fails but local works | Windows Private network profile, firewall source scope, forwarding, DNS, and client isolation |
| HTTP 401 | Client credential and key-file reference |
| Model missing or load fails | Exact preset ID, catalog refresh, cached files, offline mode, free memory, and journal |
| Client still uses an old port/model | Installed config and whether the client session was restarted |
| Model reloads during gaming | Stop the service rather than only unloading the model |
| Keepalive task exits | Actual script path, working directory, and task result; avoid redirected AppData paths |

Useful Windows diagnostics:

```powershell
Get-ScheduledTask -TaskName RanchInference-WSL
Get-ScheduledTaskInfo -TaskName RanchInference-WSL
Get-NetFirewallRule -Name RanchInference-19331 | Get-NetFirewallAddressFilter
Get-NetTCPConnection -State Listen -LocalPort 19331
netsh interface portproxy show all
```

A running keepalive task reports `Running` with result `0x41301`. Keep credentials and full address-bearing diagnostics out of shared logs and commits.

## Recovery and removal

To recover from a failed service, inspect its journal and correct the configuration before restarting. If repeated failures triggered the systemd start limit, run `systemctl --user reset-failed inference` before starting it again.

To suppress automatic startup:

```bash
systemctl --user disable --now inference
```

To remove the Windows keepalive task, use elevated Windows PowerShell:

```powershell
Stop-ScheduledTask -TaskName RanchInference-WSL
Unregister-ScheduledTask -TaskName RanchInference-WSL -Confirm:$false
```

Remove LAN exposure separately with `Set-InferenceLan.ps1 -ListenAddress <reserved-address> -Port 19331 -Remove`. This removes that forwarding entry and its managed firewall rule, not unrelated networking configuration. Disable linger only if no other user service needs it. Models, keys, and runtime files can remain in place for later reuse.

For configuration rollback, restore the saved service, preset, and client files; reload systemd and restart the service as needed. For a runtime rollback, repoint the user-local symlinks to the previous versioned installation. Back up files before applying changes rather than relying on a particular session's backup names.

When changing ports, migrate the service, clients, Windows listener, and firewall together. Test the new path before removing the old listener with an explicit old `-Port`. Remove stale forwarding entries so they cannot later expose an unrelated development server.

## References

- [llama.cpp server documentation for b11552](https://github.com/ggml-org/llama.cpp/blob/b11552/tools/server/README.md), covering router presets, management APIs, and idle sleep.
- [Microsoft WSL networking](https://learn.microsoft.com/en-us/windows/wsl/networking) and [systemd lifecycle](https://devblogs.microsoft.com/commandline/systemd-support-is-now-available-in-wsl/).
- [OpenCode configuration variables](https://opencode.ai/v2/docs/config#files) and [custom providers](https://opencode.ai/v2/docs/providers#custom).
- [Workstation benchmark report](INFERENCE_BENCHMARK_2026_10_11.md) and [benchmark harness](../benchmarks/llama-context-sweep/README.md).
