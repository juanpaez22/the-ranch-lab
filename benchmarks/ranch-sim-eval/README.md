# Filled-context ranch simulator evaluation

This benchmark compares coding behavior when a deterministic multi-class Python
task is embedded in approximately 8K, 32K, and 60K tokens of repository-like
context. The canonical contract appears near the beginning, retired engineering
history fills the middle, and the implementation request appears at the end.
The longer profiles are supersets of the shorter historical context.

The task requires dataclasses for animals, plots, and state; a simulator with
atomic commands; deterministic weather and events; daily resource/health/growth
transitions; harvesting; detached persistence; and multi-day history. Sixteen
behavior-focused checks score the generated module. This is intentionally more
representative than a single-function exercise, but it remains synthetic and
does not reproduce the error accumulation of a real 60K-token interactive
agent session.

Build ignored prompt artifacts:

```bash
python3 benchmarks/ranch-sim-eval/build_prompts.py
```

Run one model/profile through the authenticated local router:

```bash
python3 benchmarks/ranch-sim-eval/run.py \
  --model gpt-oss-20b-mxfp4 \
  --profile 32k
```

Use `gemma-4-26b-a4b-q4` for the current default. GPT-OSS uses low reasoning
effort; Gemma uses its thinking-disabled template control. Both use temperature
zero, an 8,192-token output limit, disabled prompt caching, the same prompt
artifact, and the production 131,072-token slot.

After an initial result, run one agent-like repair turn using only the failed
test names and errors:

```bash
python3 benchmarks/ranch-sim-eval/repair.py \
  --model gpt-oss-20b-mxfp4 \
  --profile 60k
```

The repair request retains the original long prompt and prior implementation,
so it measures whether the model can recover after test feedback while the
conversation is already large.

Raw responses, generated prompts, and per-run summaries remain ignored local
artifacts until reviewed. The evaluator executes model-generated Python in an
isolated interpreter process with a timeout, but generated code is still
untrusted and should be inspected before reuse.
