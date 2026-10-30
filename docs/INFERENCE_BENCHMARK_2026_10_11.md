# Longhorn llama.cpp context benchmark, 2026-10-11

## Findings

On longhorn's RTX 5080, Gemma 4 E4B was the fastest model and held about 126 generated tokens per second through its 128K native ceiling. Gemma 4 12B held about 76 tokens per second from 4K through 256K. Gemma 4 26B-A4B held about 109 tokens per second through 32K, then declined to 89 at 128K and 76 at 256K.

The dense Gemma 4 31B and Qwen3.8-27B models did not fit wholly in the 16 GB GPU at these quantizations. Automatic layer placement kept GPU use near capacity and offloaded work to the host, producing about 10 tokens per second at 4K and 5 tokens per second at 256K. They are usable for batch work but much less responsive than the Gemma 4 mixture-of-experts model on this hardware.

This benchmark measures throughput, not answer quality. Every measured response reached the fixed 1,024-token output cap, so it does not establish which model produced the best or most complete portfolio site.

## Results

Values are median generation rates across successful measured requests. Each request generated 1,024 tokens.

| Model | Quant | 4K | 16K | 32K | 64K | 128K | 256K |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Gemma 4 E4B Instruct | Q4_0 | 126.48 | 126.78 | 126.45 | 126.51 | 126.36 | unsupported |
| Gemma 4 12B Unified Instruct | Q4_0 | 76.57 | 76.36 | 76.41 | 76.49 | 76.29 | 76.24 |
| Gemma 4 26B-A4B Instruct | Q4_0 | 109.20 | 109.16 | 108.83 | 100.69 | 89.08 | 75.61 |
| Gemma 4 31B Dense Instruct | Q4_0 | 10.47 | 10.00 | 9.07 | 8.00 | 6.34 | 4.65 |
| Qwen3.8 27B | Q4_K_M | 10.45 | 9.46 | 8.97 | 8.27 | 6.92 | 5.47 |

From the smallest to largest supported slot, E4B declined 0.1%, 12B declined 0.4%, 26B-A4B declined 30.8%, 31B declined 55.6%, and Qwen3.8-27B declined 47.7%. The 26B-A4B result at 256K was approximately as fast as 12B across its full range.

The detailed [summary](../benchmarks/llama-context-sweep/results/20261011-longhorn/summary.md) includes run counts, ranges, prompt-processing rates, and pre-request GPU memory observations. The [CSV](../benchmarks/llama-context-sweep/results/20261011-longhorn/summary.csv) is suitable for further analysis.

## Method

The benchmark ran llama.cpp build 11552 under WSL2 on longhorn with an NVIDIA GeForce RTX 5080 and 16,303 MiB reported VRAM. Every point used:

- one server slot and one request at a time;
- Flash Attention;
- Q4_0 K/V cache;
- automatic GPU fitting with a 1,024 MiB target margin;
- disabled prompt caching and model thinking;
- temperature zero;
- the same static HTML portfolio prompt, about 290 input tokens depending on tokenizer;
- one 128-token warmup followed by at least three measured 1,024-token generations. A resumed Qwen3.8-27B 16K point retained four successful samples.

The harness verified the live model alias and allocated context through the server API. Every summarized point used the requested context. E4B's 256K point was skipped because the [official model card](https://huggingface.co/google/gemma-4-E4B-it) specifies a 128K context limit. The [Gemma 4 12B](https://huggingface.co/google/gemma-4-12B-it), [Gemma 4 26B-A4B](https://huggingface.co/google/gemma-4-26B-A4B-it), [Gemma 4 31B](https://huggingface.co/google/gemma-4-31B), and [Qwen3.8-27B](https://huggingface.co/Qwen/Qwen3.8-27B) model cards specify 256K support.

The Gemma models used official ggml-org Q4_0 GGUFs. Qwen used the official Q4_K_M GGUF because its base-model repository did not publish Q4_0. That quantization difference prevents a perfectly controlled cross-family comparison.

## Interpretation and limits

The active sequence was short at every point. The results isolate the cost of reserving a larger slot and any resulting GPU placement changes. They do not measure prompt ingestion or attention cost when 128K or 256K tokens are actually occupied. A filled-context benchmark requires long input fixtures and should report prompt processing separately from generation. A quality comparison also needs a larger output allowance and a scoring rubric because all responses in this sweep stopped at the output limit.

GPU memory readings are point observations, not complete power or memory profiles. The results are specific to this llama.cpp build, WSL2, driver, quantization, cache types, and automatic fitting behavior. Concurrency was one. Medians include only successful runs; failed attempts from interruption and lifecycle debugging remain in `results.csv` for audit but are not treated as model limitations.

For this workstation, E4B had the highest generation throughput, 12B's generation throughput varied least across context allocations, and 26B-A4B was much faster than the two dense large models across the tested allocations. Model quality and filled-context behavior must be evaluated separately before selecting a default.

## Repeat the benchmark

The [benchmark README](../benchmarks/llama-context-sweep/README.md) documents prerequisites, execution, resume behavior, and output. From the repository root:

```bash
benchmarks/llama-context-sweep/run.sh --download
```

Add another model to [`models.tsv`](../benchmarks/llama-context-sweep/models.tsv) with its stable ID, label, llama.cpp Hugging Face reference, quantization, and published native context ceiling. The script downloads selected models sequentially and refuses to begin while its benchmark port is occupied.
