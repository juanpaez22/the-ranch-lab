# Qwen3.8 27B IQ4_XS context benchmark, 2026-11-12

## Result

Unsloth's `Qwen3.8-27B-UD-IQ4_XS.gguf` loaded successfully on Longhorn's
16 GB RTX 5080 at configured contexts from 16K through 256K. At 16K through
64K, it generated about three to five times faster than the previously tested
official Q4_K_M artifact under the same llama.cpp harness settings.

| Configured context | UD-IQ4_XS tok/s | Range | Q4_K_M tok/s | IQ4_XS / Q4_K_M |
| ---: | ---: | ---: | ---: | ---: |
| 16,384 | 48.35 | 48.17 to 48.36 | 9.46 | 5.11x |
| 32,768 | 40.41 | 40.14 to 40.56 | 8.97 | 4.50x |
| 65,536 | 24.97 | 23.88 to 25.06 | 8.27 | 3.02x |
| 131,072 | 15.65 | 15.61 to 15.68 | 6.92 | 2.26x |
| 262,144 | 8.57 | 8.01 to 8.58 | 5.47 | 1.57x |

The IQ4_XS file is 14,352,911,264 bytes, 4,620,959,264 bytes or 24.4% smaller
than the 18,973,870,528-byte Q4_K_M file already cached on Longhorn. Automatic
GPU fitting kept pre-request GPU allocation near 15 GB for both artifacts. The
large throughput gain is consistent with more model work remaining on the GPU,
but the current server logs do not expose enough placement detail to claim an
exact layer split.

IQ4_XS is the better throughput candidate for this GPU from these measurements.
The initial context sweep did not compare answer quality or tool use. The later
filled-context follow-up below adds one coding and tool-use sample, but it is
still not a statistical model ranking.

## Method

The benchmark used llama.cpp build 11552 under WSL2 on Longhorn's RTX 5080.
Each point used one slot, Flash Attention, Q4_0 K/V cache, automatic fitting
with a 1,024 MiB target margin, disabled prompt caching, temperature zero, one
128-token warmup, and three measured 1,024-token generations. Every measured
request generated all 1,024 requested tokens.

The requested and actual slot sizes matched at all five points. The prompt was
only 290 tokens, so these results measure the cost of allocating larger context
windows, not generation after filling them with prompt and history.
Prompt-processing medians declined from 1,461.33 tok/s at 16K to 393.47 tok/s
at 256K, but the short prompt is not representative of long-context ingestion.

The 128K and 256K allocations were technically successful, but the WSL kernel
logged repeated DirectX bridge synchronization timeouts during both runs. No
OOM kill occurred. Given the generation slowdown, 2.2 GB swap use, and the same
timeout signature associated with an observed desktop freeze, these larger
allocations are poor interactive defaults on the current 32 GB host.

The comparison reuses the Q4_K_M medians from the 2026-10-11 sweep. Both runs
used the same host, GPU, llama.cpp build, prompt, generation length, slot count,
Flash Attention, Q4_0 K/V cache, and fitting target. They occurred on different
dates and used artifacts from different publishers, so the result is a practical
artifact comparison rather than a controlled quantizer-quality study.

The versioned result summary and CSV are under
[`20261112-qwen3.8-27b-iq4-xs`](../context-sweep/results/20261112-qwen3.8-27b-iq4-xs/summary.md).
Full responses and server logs remain ignored local artifacts.

## Operational outcome

The exact text-only file was downloaded from
[`unsloth/Qwen3.8-27B-GGUF`](https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/blob/main/Qwen3.8-27B-UD-IQ4_XS.gguf).
Its SHA-256 is
`4b194b34ecec99fdfb74caef84445ccd01c987de87d96ae8ca50dc434b4b0a38`,
matching the publisher metadata.
The inference router was stopped for isolation and restored after the sweep.
The model was initially left cached but undeployed. It was later added as the
selectable `qwen3.8-27b-iq4-xs-64k` router and OpenCode evaluation preset while
leaving Gemma as the default.

## Filled-context and tool-use follow-up

The installed OpenCode entry completed a read-only tool loop: it called the
Read tool for `README.md` and returned the correct first Markdown heading
without editing files. The router also returned exactly `ready` for a plain
completion and reported one actual 65,536-token slot.

The same ranch-simulator evaluation that exposed Gemma and GPT-OSS limitations
was then run at all three profiles with the original deterministic settings,
8,192-token output cap, and behavioral evaluator.

| Model | Actual prompt | Score | Prompt time | Generation time | Generation tok/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Qwen3.8 27B IQ4_XS | 8,363 | 16/16 | 5.44 s | 128.24 s | 22.78 |
| Qwen3.8 27B IQ4_XS | 32,162 | 16/16 | 28.72 s | 189.50 s | 16.86 |
| Qwen3.8 27B IQ4_XS | 60,063 | 16/16 | 44.63 s | 219.07 s | 13.29 |

Every response returned a complete Python module, stopped normally, emitted no
reasoning-only content, and passed all sixteen checks on the first attempt. The
old 60K repair phase was not applicable because there were no failed checks to
feed back. For comparison, the earlier single generations scored 15/16, 16/16,
and 15/16 for Gemma and 0/16, 15/16, and 13/16 for GPT-OSS.

The 60K Qwen request consumed 60,063 prompt tokens and generated 2,912 tokens,
for 62,975 occupied tokens inside the 65,536-token slot. It therefore validates
this task at that occupancy, not an arbitrary 60K prompt plus the full 8,192
output allowance. OpenCode's configured 57,344-token input limit reserves the
full 8,192-token output budget and may compact before reaching the API test's
60,063-token prompt size.

These are single greedy generations. The clean sweep is encouraging evidence
for trying Qwen as a daily driver, but repeated coding tasks and real multi-turn
OpenCode sessions are still needed before treating its reliability as settled.
The versioned results are in the
[2026-11-12 simulator summary](../ranch-sim-eval/summary-20261112.md).

## Q3_K_XL 64K follow-up

Unsloth's smaller `UD-Q3_K_XL` artifact loaded with an actual 65,536-token
slot and completed three full 1,024-token generations. It used the same host,
llama.cpp build, prompt, slot count, Flash Attention, Q4_0 K/V cache, fitting
target, and generation settings as the IQ4_XS allocation sweep.

| Quantization | File size | Median tok/s | Range | Pre-request GPU MiB |
| --- | ---: | ---: | ---: | ---: |
| UD-Q3_K_XL | 13,146,393,504 bytes | 50.59 | 50.57 to 50.80 | 14,893 |
| UD-IQ4_XS | 14,352,911,264 bytes | 24.97 | 23.88 to 25.06 | 15,147 |

Q3_K_XL was 2.03 times faster and used about 254 MiB less GPU memory in this
test. The kernel logged no new DirectX bridge timeout during its load or three
requests. This short-prompt allocation result does not establish answer quality
or prove that a filled 64K interactive session will avoid the desktop freeze
observed with IQ4_XS.

The downloaded file's SHA-256 is
`7b20f0679da6f5c6ec7971e241630f44fe1e123e5c99bfea90c433268b355723`,
matching the publisher metadata. The versioned result summary and CSV are under
[`20261112-qwen3.8-27b-q3-k-xl`](../context-sweep/results/20261112-qwen3.8-27b-q3-k-xl/summary.md).

## Gemma control after the OpenCode upgrade

Gemma was rerun on 2026-11-13 after OpenCode was upgraded from 2.0.26 to 2.2.7. The ranch-simulator harness calls the authenticated llama.cpp API directly, so it does not include OpenCode's system prompt, Code Mode instructions, tools, or compaction. This is therefore a repeatability control, not a test of the repaired OpenCode tool-routing path.

| Profile | Original score | Rerun score | Rerun generation tok/s | Rerun failure |
| --- | ---: | ---: | ---: | --- |
| 8K | 15/16 | 15/16 | 82.50 | Detached simulation history |
| 32K | 16/16 | 16/16 | 74.15 | None |
| 60K | 15/16 | 15/16 | 65.52 | Insufficient-coin validation |

All three responses stopped normally with complete code and no reasoning-only output. Prompt and completion token counts matched the original runs exactly, as did the score and failed check at each profile. No inference-service, CUDA, or WSL GPU error was logged during the rerun. Gemma was explicitly unloaded afterward, returning GPU allocation near idle. The unchanged result supports the diagnosis that the OpenCode upgrade repaired the agent harness rather than changing Gemma's underlying generation behavior.
