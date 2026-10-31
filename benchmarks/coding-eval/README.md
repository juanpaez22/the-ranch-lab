# Coding evaluation

This small evaluation compares whether models can implement one self-contained
Python function correctly. The prompt is fixed, temperature is zero, and both
models receive the same output limit. The evaluator checks eight unshown cases,
including duplicates, unsorted and out-of-range values, negative bounds, an
empty interval, and input mutation.

Save a llama.cpp `/v1/chat/completions` response under the ignored `results/`
directory, then run:

```bash
python3 benchmarks/coding-eval/evaluate.py \
  benchmarks/coding-eval/results/<model>.json
```

The evaluator executes generated Python in an isolated interpreter process
with a ten-second timeout. Model-generated code is still untrusted code;
inspect the response before running this evaluator on models or prompts that
are not under your control.

This is a smoke test, not a general coding benchmark. One task cannot establish
overall model quality, and a pass does not measure maintainability, explanation
quality, tool use, or performance on repository-scale changes.
