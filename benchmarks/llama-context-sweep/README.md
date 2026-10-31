# llama.cpp context sweep

This benchmark measures one fixed, medium-sized portfolio-site generation task across models and configured context sizes. It records llama.cpp's prompt-processing and generation timings separately.

The default matrix uses one server slot, Flash Attention, Q4_0 K/V cache, automatic GPU fitting with a 1024 MiB target margin, three measured requests, and context sizes from 4K through 256K. The prompt is identical at every point, prompt caching is disabled, and the request asks the model template to disable thinking. Not every model implements that template argument: GPT-OSS still emits reasoning tokens, as recorded in its comparison report. This isolates the effect of allocating a larger context window; it is not a filled-context benchmark.

## Run

The script uses Bash, curl, jq, Python 3, `sha256sum`, `nvidia-smi`, and a CUDA-enabled llama.cpp installation. It installs nothing. Stop other GPU inference processes first. From the repository root:

```bash
benchmarks/llama-context-sweep/run.sh --download
```

Resume an interrupted result directory without repeating points that already have the requested number of successful runs:

```bash
benchmarks/llama-context-sweep/run.sh \
  --resume benchmarks/llama-context-sweep/results/20261011-longhorn
```

Include the original nondefault `--repeats` and `--output-tokens` values when resuming. The script checks runtime and input compatibility plus the recorded slot count, Flash Attention, KV cache, fitting margin, prompt caching, and thinking settings before adding samples. Context sizes can be added to the same result set.

The script invokes its own model downloads sequentially. Ensure no other process is downloading the same model into the cache. To run a smaller smoke test or change the repetition count for a new result set:

```bash
benchmarks/llama-context-sweep/run.sh \
  --model gemma-4-e4b \
  --contexts 4096,16384 \
  --repeats 1 \
  --output-tokens 256
```

Edit [`models.tsv`](models.tsv) to add another model. Give each entry a stable ID, label, llama.cpp `-hf` reference, quantization name, and native context ceiling.

## Results

Each run creates a timestamped directory under `results/` containing:

- `results.csv`: one row per measured request or failed point.
- `summary.csv` and `summary.md`: median generation rates and ranges by model/context point.
- `metadata.json`: hardware, llama.cpp version, benchmark settings, and prompt and model-manifest hashes.
- `logs/`: timestamped llama-server startup and runtime logs for each attempt.
- `responses/`: numbered requests and full responses, retained so output length and errors can be audited.

Compare the median `generation_tps` for successful repetitions. Also inspect `generated_tokens` and `finish_reason`; a very short completion is a weaker throughput sample. `prompt_tps` uses uncached prompt evaluation but the portfolio prompt is small, so it should not be generalized to long-prompt ingestion.

Quantization is part of the result. The Gemma models use official Q4_0 files to match the already-downloaded 26B-A4B model. Qwen3.8 uses its official Q4_K_M file because the ggml-org repository does not publish a base-model Q4_0 file. GPT-OSS uses the publisher's native MXFP4 weights, so its result is not a controlled comparison of weight quantizers with Gemma.

The script skips requested contexts above a model's published native ceiling. It records load failures, request failures, and any actual-context mismatch rather than silently lowering the requested size. A failed request or response missing timing fields stops that point and releases the server; resume can retry the incomplete point. Resume mode requires the same host, GPU and driver, llama.cpp build, prompt, model manifest, repetition target, output-token limit, and recorded inference settings so incompatible measurements are not mixed.

Server shutdown is bounded: the harness sends `SIGTERM`, waits up to ten seconds, then force-stops only the server PID it started. It also refuses to start a point when the benchmark port is already occupied. These guards keep an interrupted or wedged request from contaminating the next context point.
