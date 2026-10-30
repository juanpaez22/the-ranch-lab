#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
manifest="$script_dir/models.tsv"
prompt_file="$script_dir/prompt.txt"
llama_server="${LLAMA_SERVER:-$HOME/.local/bin/llama-server}"
llama_cli="${LLAMA_CLI:-$HOME/.local/bin/llama}"
port="${BENCHMARK_PORT:-18080}"
repeats=3
output_tokens=1024
download=false
resume=false
model_filter=""
output_dir=""
contexts=(4096 16384 32768 65536 131072 262144)

usage() {
  cat <<'EOF'
Usage: run.sh [options]

Options:
  --download           Download each selected model before benchmarking.
  --model ID           Benchmark one model ID from models.tsv.
  --repeats N          Measured requests per point. Default: 3.
  --output-tokens N    Maximum generated tokens per request. Default: 1024.
  --contexts LIST      Comma-separated context sizes. Default: 4096,16384,32768,65536,131072,262144.
  --output DIR         Result directory. Default: results/<UTC timestamp>.
  --resume DIR         Continue an interrupted result directory, skipping complete points.
  -h, --help           Show this help.

The script needs Bash, curl, jq, Python 3, sha256sum, nvidia-smi, and a
CUDA-enabled llama-server. --download also needs the llama CLI. It owns port
18080 by default. Stop other GPU inference processes first so every point has
the same available VRAM. It never deletes model-cache files.
EOF
}

while (($#)); do
  case "$1" in
    --download)
      download=true
      shift
      ;;
    --model)
      model_filter="${2:?missing model ID}"
      shift 2
      ;;
    --repeats)
      repeats="${2:?missing repeat count}"
      shift 2
      ;;
    --output-tokens)
      output_tokens="${2:?missing output-token count}"
      shift 2
      ;;
    --contexts)
      IFS=',' read -r -a contexts <<< "${2:?missing context list}"
      shift 2
      ;;
    --output)
      output_dir="${2:?missing output directory}"
      shift 2
      ;;
    --resume)
      output_dir="${2:?missing result directory}"
      resume=true
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -x "$llama_server" ]]; then
  printf 'Required executable not found: %s\n' "$llama_server" >&2
  exit 1
fi

if [[ "$download" == true && ! -x "$llama_cli" ]]; then
  printf 'Required download executable not found: %s\n' "$llama_cli" >&2
  exit 1
fi

for command_name in curl jq nvidia-smi sha256sum; do
  if ! command -v "$command_name" >/dev/null; then
    printf 'Required command not found: %s\n' "$command_name" >&2
    exit 1
  fi
done

if ! command -v python3 >/dev/null; then
  printf 'Required command not found: python3\n' >&2
  exit 1
fi

if [[ ! "$repeats" =~ ^[1-9][0-9]*$ || ! "$output_tokens" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Repeats and output tokens must be positive integers.\n' >&2
  exit 2
fi

for context in "${contexts[@]}"; do
  if [[ ! "$context" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Invalid context size: %s\n' "$context" >&2
    exit 2
  fi
done

current_llama_version="$($llama_server --version 2>&1 | tr '\n' ' ')"
current_gpu="$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | head -1)"
current_hostname="$(hostname)"
current_kernel="$(uname -srmo)"
prompt_sha256="$(sha256sum "$prompt_file" | cut -d' ' -f1)"
manifest_sha256="$(sha256sum "$manifest" | cut -d' ' -f1)"

port_in_use() {
  python3 - "$port" <<'PY'
import socket
import sys

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    try:
        sock.bind(("127.0.0.1", int(sys.argv[1])))
    except OSError:
        raise SystemExit(0)
raise SystemExit(1)
PY
}

if port_in_use; then
  printf 'Benchmark port %s is already in use.\n' "$port" >&2
  exit 1
fi

if [[ -z "$output_dir" ]]; then
  output_dir="$script_dir/results/$(date -u +%Y%m%dT%H%M%SZ)"
fi

if [[ "$resume" == false && -e "$output_dir" ]]; then
  printf 'Refusing to overwrite existing output directory: %s\n' "$output_dir" >&2
  exit 1
fi

csv="$output_dir/results.csv"
if [[ "$resume" == true ]]; then
  if [[ ! -f "$csv" || ! -f "$output_dir/metadata.json" ]]; then
    printf 'Resume directory is missing results.csv or metadata.json: %s\n' "$output_dir" >&2
    exit 1
  fi
  metadata_repeats="$(jq -er '.repeats' "$output_dir/metadata.json")"
  metadata_output_tokens="$(jq -er '.output_tokens' "$output_dir/metadata.json")"
  metadata_llama_version="$(jq -er '.llama_version' "$output_dir/metadata.json")"
  metadata_gpu="$(jq -er '.gpu' "$output_dir/metadata.json")"
  metadata_hostname="$(jq -er '.hostname' "$output_dir/metadata.json")"
  metadata_kernel="$(jq -er '.kernel' "$output_dir/metadata.json")"
  metadata_prompt_sha256="$(jq -er '.prompt_sha256' "$output_dir/metadata.json")"
  metadata_manifest_sha256="$(jq -er '.manifest_sha256' "$output_dir/metadata.json")"
  if [[ "$metadata_repeats" != "$repeats" || "$metadata_output_tokens" != "$output_tokens" ||
        "$metadata_llama_version" != "$current_llama_version" || "$metadata_gpu" != "$current_gpu" ||
        "$metadata_hostname" != "$current_hostname" || "$metadata_kernel" != "$current_kernel" ||
        "$metadata_prompt_sha256" != "$prompt_sha256" || "$metadata_manifest_sha256" != "$manifest_sha256" ]] ||
     ! jq -e '
       .parallel == 1 and .flash_attention == true and .kv_cache == "q4_0" and
       .fit_target_mib == 1024 and .prompt_cache == false and .thinking == false
     ' "$output_dir/metadata.json" >/dev/null; then
    printf 'Refusing to mix incompatible settings or runtime data in resume directory: %s\n' "$output_dir" >&2
    exit 1
  fi
  mkdir -p "$output_dir/logs" "$output_dir/responses"
else
  mkdir -p "$output_dir/logs" "$output_dir/responses"
  printf '%s\n' 'model_id,label,hf_ref,quantization,native_context,configured_context,actual_context,status,repeat,prompt_tokens,generated_tokens,prompt_tps,generation_tps,total_seconds,gpu_memory_used_mib,gpu_memory_free_mib,finish_reason' > "$csv"

  jq -n \
    --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg hostname "$current_hostname" \
    --arg kernel "$current_kernel" \
    --arg llama_version "$current_llama_version" \
    --arg gpu "$current_gpu" \
    --arg prompt_sha256 "$prompt_sha256" \
    --arg manifest_sha256 "$manifest_sha256" \
    --argjson repeats "$repeats" \
    --argjson output_tokens "$output_tokens" \
    --arg contexts "$(IFS=,; printf '%s' "${contexts[*]}")" \
    '{started_at:$started_at,hostname:$hostname,kernel:$kernel,llama_version:$llama_version,gpu:$gpu,prompt_sha256:$prompt_sha256,manifest_sha256:$manifest_sha256,repeats:$repeats,output_tokens:$output_tokens,contexts:$contexts,parallel:1,flash_attention:true,kv_cache:"q4_0",fit_target_mib:1024,prompt_cache:false,thinking:false}' \
    > "$output_dir/metadata.json"
fi

server_pid=""
stop_server() {
  if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
    kill "$server_pid"
    for _ in {1..20}; do
      if ! kill -0 "$server_pid" 2>/dev/null; then
        break
      fi
      sleep 0.5
    done
    if kill -0 "$server_pid" 2>/dev/null; then
      kill -KILL "$server_pid"
    fi
    wait "$server_pid" 2>/dev/null || true
  fi
  server_pid=""
}
trap stop_server EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

csv_row() {
  jq -rn --args '$ARGS.positional | @csv' -- "$@"
}

record_failure() {
  local model_id="$1" label="$2" hf_ref="$3" quantization="$4"
  local native_context="$5" context="$6" actual_context="$7" status="$8"
  csv_row "$model_id" "$label" "$hf_ref" "$quantization" "$native_context" \
    "$context" "$actual_context" "$status" "" "" "" "" "" "" "" "" "" >> "$csv"
}

successful_runs() {
  local model_id="$1" context="$2"
  python3 - "$csv" "$model_id" "$context" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as handle:
    rows = csv.DictReader(handle)
    print(sum(
        row["model_id"] == sys.argv[2]
        and row["configured_context"] == sys.argv[3]
        and row["status"] == "ok"
        for row in rows
    ))
PY
}

is_unsupported() {
  local model_id="$1" context="$2"
  python3 - "$csv" "$model_id" "$context" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as handle:
    rows = csv.DictReader(handle)
    found = any(
        row["model_id"] == sys.argv[2]
        and row["configured_context"] == sys.argv[3]
        and row["status"] == "unsupported"
        for row in rows
    )
print("true" if found else "false")
PY
}

next_attempt() {
  local model_id="$1" context="$2"
  python3 - "$csv" "$model_id" "$context" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as handle:
    attempts = [
        int(row["repeat"])
        for row in csv.DictReader(handle)
        if row["model_id"] == sys.argv[2]
        and row["configured_context"] == sys.argv[3]
        and row["repeat"].isdigit()
    ]
print(max(attempts, default=0) + 1)
PY
}

wait_for_server() {
  local attempts=0
  while ((attempts < 600)); do
    if ! kill -0 "$server_pid" 2>/dev/null; then
      return 1
    fi
    if curl --fail --silent --max-time 2 "http://127.0.0.1:$port/health" | jq -e '.status == "ok"' >/dev/null 2>&1; then
      return 0
    fi
    attempts=$((attempts + 1))
    sleep 1
  done
  return 1
}

selected=0
while IFS=$'\t' read -r model_id label hf_ref quantization native_context; do
  [[ -z "$model_id" || "$model_id" == \#* ]] && continue
  if [[ -n "$model_filter" && "$model_id" != "$model_filter" ]]; then
    continue
  fi
  selected=$((selected + 1))

  printf '\n[%s] %s\n' "$(date -u +%H:%M:%S)" "$label"
  if [[ "$download" == true ]]; then
    "$llama_cli" download -hf "$hf_ref"
  fi

  for context in "${contexts[@]}"; do
    completed_runs="$(successful_runs "$model_id" "$context")"
    if ((completed_runs >= repeats)) || [[ "$(is_unsupported "$model_id" "$context")" == true ]]; then
      printf '  context=%s skipped: point already complete\n' "$context"
      continue
    fi

    if ((context > native_context)); then
      printf '  context=%s skipped: native limit is %s\n' "$context" "$native_context"
      record_failure "$model_id" "$label" "$hf_ref" "$quantization" \
        "$native_context" "$context" "" "unsupported"
      continue
    fi

    run_tag="$(date -u +%Y%m%dT%H%M%S%NZ)"
    log_file="$output_dir/logs/${model_id}-${context}-${run_tag}.log"
    printf '  context=%s loading\n' "$context"
    if port_in_use; then
      printf '  context=%s failed: benchmark port is already in use\n' "$context"
      record_failure "$model_id" "$label" "$hf_ref" "$quantization" \
        "$native_context" "$context" "" "port_busy"
      exit 1
    fi
    "$llama_server" \
      --host 127.0.0.1 \
      --port "$port" \
      --alias "$model_id" \
      --ctx-size "$context" \
      --parallel 1 \
      --flash-attn on \
      --cache-type-k q4_0 \
      --cache-type-v q4_0 \
      --fit on \
      --fit-target 1024 \
      --jinja \
      --no-mmproj \
      -hf "$hf_ref" \
      > "$log_file" 2>&1 &
    server_pid=$!

    if ! wait_for_server; then
      printf '  context=%s load failed\n' "$context"
      record_failure "$model_id" "$label" "$hf_ref" "$quantization" \
        "$native_context" "$context" "" "load_failed"
      stop_server
      sleep 2
      continue
    fi

    props="$(curl --fail --silent "http://127.0.0.1:$port/props")"
    actual_context="$(jq -r '.default_generation_settings.n_ctx' <<< "$props")"
    actual_alias="$(jq -r '.model_alias' <<< "$props")"
    if [[ "$actual_alias" != "$model_id" ]]; then
      printf '  context=%s alias mismatch: expected %s, found %s\n' \
        "$context" "$model_id" "$actual_alias"
      record_failure "$model_id" "$label" "$hf_ref" "$quantization" \
        "$native_context" "$context" "$actual_context" "alias_mismatch"
      stop_server
      sleep 2
      continue
    fi
    if [[ "$actual_context" != "$context" ]]; then
      printf '  context=%s mismatch: server allocated %s\n' "$context" "$actual_context"
      record_failure "$model_id" "$label" "$hf_ref" "$quantization" \
        "$native_context" "$context" "$actual_context" "context_mismatch"
      stop_server
      sleep 2
      continue
    fi

    read -r gpu_used gpu_free < <(
      nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits |
        head -1 | tr -d ','
    )

    warmup_request="$output_dir/responses/${model_id}-${context}-warmup-${run_tag}-request.json"
    warmup_response="$output_dir/responses/${model_id}-${context}-warmup-${run_tag}.json"
    jq -n \
      --arg model "$model_id" \
      --rawfile prompt "$prompt_file" \
      '{model:$model,messages:[{role:"user",content:$prompt}],temperature:0,max_tokens:128,cache_prompt:false,chat_template_kwargs:{enable_thinking:false}}' \
      > "$warmup_request"
    if ! curl --fail --silent --show-error --max-time 600 \
      "http://127.0.0.1:$port/v1/chat/completions" \
      -H 'Content-Type: application/json' \
      --data-binary "@$warmup_request" > "$warmup_response"; then
      printf '  context=%s warmup failed\n' "$context"
      record_failure "$model_id" "$label" "$hf_ref" "$quantization" \
        "$native_context" "$context" "$actual_context" "warmup_failed"
      stop_server
      sleep 2
      continue
    fi

    context_request_failed=false
    successful_count="$completed_runs"
    attempt="$(next_attempt "$model_id" "$context")"
    while ((successful_count < repeats)); do
      repeat="$attempt"
      request_file="$output_dir/responses/${model_id}-${context}-${repeat}-request.json"
      response_file="$output_dir/responses/${model_id}-${context}-${repeat}.json"
      jq -n \
        --arg model "$model_id" \
        --rawfile prompt "$prompt_file" \
        --argjson output_tokens "$output_tokens" \
        '{model:$model,messages:[{role:"user",content:$prompt}],temperature:0,max_tokens:$output_tokens,cache_prompt:false,chat_template_kwargs:{enable_thinking:false}}' \
        > "$request_file"

      start_ns="$(date +%s%N)"
      if ! curl --fail --silent --show-error --max-time 600 \
        "http://127.0.0.1:$port/v1/chat/completions" \
        -H 'Content-Type: application/json' \
        --data-binary "@$request_file" > "$response_file"; then
        printf '  context=%s repeat=%s request failed\n' "$context" "$repeat"
        csv_row "$model_id" "$label" "$hf_ref" "$quantization" "$native_context" \
          "$context" "$actual_context" "request_failed" "$repeat" "" "" "" "" "" \
          "$gpu_used" "$gpu_free" "" >> "$csv"
        context_request_failed=true
        break
      fi
      end_ns="$(date +%s%N)"

      if ! jq -e '.timings.predicted_per_second and .timings.prompt_per_second' "$response_file" >/dev/null; then
        printf '  context=%s repeat=%s invalid response\n' "$context" "$repeat"
        csv_row "$model_id" "$label" "$hf_ref" "$quantization" "$native_context" \
          "$context" "$actual_context" "invalid_response" "$repeat" "" "" "" "" "" \
          "$gpu_used" "$gpu_free" "" >> "$csv"
        context_request_failed=true
        break
      fi

      prompt_tokens="$(jq -r '.timings.prompt_n' "$response_file")"
      generated_tokens="$(jq -r '.timings.predicted_n' "$response_file")"
      prompt_tps="$(jq -r '.timings.prompt_per_second' "$response_file")"
      generation_tps="$(jq -r '.timings.predicted_per_second' "$response_file")"
      finish_reason="$(jq -r '.choices[0].finish_reason // "unknown"' "$response_file")"
      total_seconds="$(jq -n --arg start "$start_ns" --arg end "$end_ns" \
        '((($end | tonumber) - ($start | tonumber)) / 1000000000)')"

      csv_row "$model_id" "$label" "$hf_ref" "$quantization" "$native_context" \
        "$context" "$actual_context" "ok" "$repeat" "$prompt_tokens" "$generated_tokens" \
        "$prompt_tps" "$generation_tps" "$total_seconds" "$gpu_used" "$gpu_free" \
        "$finish_reason" >> "$csv"
      printf '  context=%-6s repeat=%s generated=%s generation_tps=%.2f\n' \
        "$context" "$repeat" "$generated_tokens" "$generation_tps"
      successful_count=$((successful_count + 1))
      attempt=$((attempt + 1))
    done

    stop_server
    if [[ "$context_request_failed" == true ]]; then
      printf '  context=%s stopped after request failure\n' "$context"
    fi
    sleep 2
  done
done < "$manifest"

if ((selected == 0)); then
  printf 'No matching model found in %s\n' "$manifest" >&2
  exit 1
fi

observed_contexts="$(python3 - "$csv" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as handle:
    contexts = {int(row["configured_context"]) for row in csv.DictReader(handle)}
print(",".join(str(context) for context in sorted(contexts)))
PY
)"
jq --arg finished_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg contexts "$observed_contexts" \
  '. + {finished_at:$finished_at,contexts:$contexts}' "$output_dir/metadata.json" \
  > "$output_dir/metadata.finished.json"
mv "$output_dir/metadata.finished.json" "$output_dir/metadata.json"
python3 "$script_dir/summarize.py" "$output_dir"

printf '\nResults: %s\n' "$csv"
