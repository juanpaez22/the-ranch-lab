# Inference benchmarks

These harnesses measure local inference under repeatable settings. They provide evidence, not deployed configuration or a general model-quality ranking.

## Harnesses

- [Context sweep](context-sweep/README.md): allocated-context fit, load behavior, prompt processing, and generation throughput.
- [Coding eval](coding-eval/README.md): a small fixed set of deterministic coding edge cases.
- [Ranch simulator](ranch-sim-eval/README.md): tool-oriented homelab tasks evaluated from recorded model responses.

## Reports

- [2026-10-11 context allocation](reports/2026-10-11-context-allocation.md)
- [2026-10-31 GPT-OSS versus Gemma](reports/2026-10-31-gpt-oss-vs-gemma.md)
- [2026-11-12 Qwen quantization and Gemma follow-up](reports/2026-11-12-qwen-quantization.md)

Follow each harness README to reproduce a measurement. Commit concise inputs, metadata, summaries, and reports when they are useful for comparison; keep bulky raw responses and transient logs ignored and reproducible.
