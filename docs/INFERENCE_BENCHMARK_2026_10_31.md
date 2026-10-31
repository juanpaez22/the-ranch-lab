# GPT-OSS 20B and Gemma 4 26B-A4B comparison, 2026-10-31

## Result

GPT-OSS 20B generated tokens substantially faster than the current Gemma 4
26B-A4B default on Longhorn. Both models passed the same small Python coding
task. GPT-OSS also completed a read-only OpenCode tool loop, but this single
task is not enough evidence to replace the default model.

| Model | Weights | 4K slot | 128K slot | Coding tests |
| --- | --- | ---: | ---: | ---: |
| GPT-OSS 20B | MXFP4 | 176.82 tok/s | 177.90 tok/s | 8/8 |
| Gemma 4 26B-A4B | Q4_0 | 103.50 tok/s | 84.75 tok/s | 8/8 |

At 4K, GPT-OSS was 1.71 times Gemma's measured generation rate. At 128K,
it was 2.10 times Gemma's rate. These are local engine measurements, not a
general claim about either model or other runtimes.

The fixed coding task asked for a Python `find_missing_ranges` implementation.
The evaluator checked unsorted inputs, duplicates, out-of-range values,
negative bounds, empty intervals, and input mutation. GPT-OSS used low reasoning
effort and generated 418 completion tokens at 167.42 tok/s; Gemma used its
thinking-disabled template control and generated 243 completion tokens at
84.75 tok/s. Their generation phases took 2.49 and 2.86 seconds respectively,
excluding model load. Different tokenizers and reasoning behavior mean token
counts and prompt-processing rates are not directly comparable.

## Method

Both throughput runs used llama.cpp build 11552 under WSL2 on Longhorn's RTX
5080. Each point used one slot, Flash Attention, Q4_0 K/V cache, automatic
fitting with a 1,024 MiB target margin, disabled prompt caching, temperature
zero, one 128-token warmup, and three measured 1,024-token generations. The
prompt and request structure matched the earlier context sweep. The reported
values are medians.

The test allocated 4,096-token and 131,072-token slots but supplied only a
short prompt. It measures the cost of reserving those contexts, not generation
with a filled context. The models also use different weight formats, so this is
a comparison of the installed artifacts rather than a controlled quantizer
study.

GPT-OSS used its 1,024-token budget entirely in `reasoning_content` during the
throughput prompt and did not reach visible HTML. Gemma's measured tokens were
visible HTML. The GPT-OSS rates therefore describe raw reasoning/output token
generation, not useful visible-output throughput. The coding evaluation used a
larger budget and low reasoning effort so GPT-OSS reached a final answer.

The source rows and generated summaries are stored under:

- [`20261031-gpt-oss-20b`](../benchmarks/llama-context-sweep/results/20261031-gpt-oss-20b/summary.md)
- [`20261031-gemma-4-26b-a4b`](../benchmarks/llama-context-sweep/results/20261031-gemma-4-26b-a4b/summary.md)

Full responses and server logs remain ignored local artifacts. The coding prompt
and evaluator are versioned under [`benchmarks/coding-eval`](../benchmarks/coding-eval/README.md).

## Installation and validation

The official ggml-org `gpt-oss-20b-MXFP4.gguf` was downloaded once through
llama.cpp. Its 12,109,566,624-byte size and SHA-256
`27cd6c432c7672cb812a92f611cf3ba7bbc35928262bb1e1253ff4ee6ae35901`
matched the publisher metadata. No partial-download marker remained.

The router allocated one 131,072-token slot and loaded the model with 13,856 MiB
of GPU memory reported in use. The production preset, OpenCode entry, plain
completion, coding response, and read-only OpenCode Read-tool loop all worked.
The OpenCode loop returned the first README heading without modifying files.
Gemma remains the configured OpenCode default; GPT-OSS is an explicitly
selectable coding/reasoning alternative.

## Interpretation

GPT-OSS is the more promising interactive coding option from this small test:
it fits the workstation, has much higher raw generation throughput, passed the
coding cases, and exercised native tool calling successfully. Keep Gemma as the
default until a broader set of repository tasks measures correctness, tool-call
reliability, edit quality, and tendency to spend the output budget on reasoning.

Official OpenAI documentation describes GPT-OSS 20B as a 21B-parameter model
with 3.6B active parameters, configurable low/medium/high reasoning effort, and
a 131,072-token context window. The model is intended for local or specialized
use and supports function calling. See the
[official model page](https://developers.openai.com/api/docs/models/gpt-oss-20b),
the [llama.cpp GPT-OSS guide](https://github.com/ggml-org/llama.cpp/discussions/15396),
and the [official GGUF repository](https://huggingface.co/ggml-org/gpt-oss-20b-GGUF).

## Filled-context simulator follow-up

A second evaluation used a substantially larger multi-class Python task. The
canonical ranch-simulator contract appeared near the beginning, followed by
explicitly non-normative archived engineering notes, with the implementation
request at the end. The longer prompts were supersets of the shorter archived
context. Sixteen behavioral checks covered dataclass defaults, setup validation,
deep-copy boundaries, deterministic weather/events, transactional rollback,
resource accounting, crop/animal ticks, harvesting, persistence, and multi-day
history.

| Model | Actual prompt | Score | Prompt time | Generation time | Generation tok/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| GPT-OSS 20B | 7,833 | 0/16 | 1.49 s | 28.56 s | 131.13 |
| Gemma 4 26B-A4B | 8,629 | 15/16 | 3.14 s | 29.98 s | 81.41 |
| GPT-OSS 20B | 29,814 | 15/16 | 3.60 s | 41.73 s | 78.62 |
| Gemma 4 26B-A4B | 33,286 | 16/16 | 11.61 s | 34.44 s | 70.39 |
| GPT-OSS 20B | 55,581 | 13/16 | 7.65 s | 53.97 s | 54.75 |
| Gemma 4 26B-A4B | 62,188 | 15/16 | 21.56 s | 39.98 s | 60.78 |

GPT-OSS's 8K implementation had an unmatched parenthesis and could not load.
At 30K it missed only the rule that booleans are not valid integer purchase
amounts. At 56K it retained that bug and also omitted rain's automatic plot
watering and consumed plot water during storms despite zero growth. Its low
reasoning trace shortened from roughly 4.4K characters at 30K to 2.5K at 56K.

Gemma's 8K implementation passed 15 checks but called `snapshot()` on the
`RanchState` returned by `advance_day` during multi-day simulation. Its 33K
implementation passed every check. At 62K it omitted the insufficient-coins
guard for feed purchases and passed 15 checks. Its generated implementation
remained compact and structurally consistent across profiles.

One agent-like repair turn retained the original 60K prompt, previous module,
and failing test names/errors. GPT-OSS received 58,039 prompt tokens, spent the
full 8,192-token output cap in reasoning for 167.56 seconds, emitted no code,
and scored 0/16. Gemma received 64,697 prompt tokens and returned a complete
module, but it failed to add the missing insufficient-coins check and remained
at 15/16.

These are single greedy generations per profile, not statistical quality
estimates. The synthetic archived context tests attention pressure but does not
fully reproduce a real agent session's accumulated decisions, tool outputs,
partial edits, and contradictory hypotheses. Even with that limitation, the
60K results reproduce the reported operational pattern: generation slows,
early requirements are dropped, and GPT-OSS can spend the entire output budget
reasoning without completing the requested repair. Gemma was materially more
reliable on this workload.

The versioned [benchmark definition](../benchmarks/ranch-sim-eval/README.md)
and [result summary](../benchmarks/ranch-sim-eval/summary-20261031.md) preserve
the task, controls, and measurements. Generated prompts and full model
responses remain ignored local artifacts.
