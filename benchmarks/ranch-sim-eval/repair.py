#!/usr/bin/env python3
"""Run one test-feedback repair turn for a filled-context candidate."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.request
from pathlib import Path

from run import request_payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--profile", choices=("8k", "32k", "60k"), required=True)
    parser.add_argument("--endpoint", default="http://127.0.0.1:19331/v1/chat/completions")
    parser.add_argument("--key-file", type=Path, default=Path.home() / ".config/llama.cpp/api.key")
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "results")
    args = parser.parse_args()

    root = Path(__file__).parent
    original_path = args.output / f"{args.model}-{args.profile}.json"
    summary_path = args.output / f"{args.model}-{args.profile}-summary.json"
    original = json.loads(original_path.read_text(encoding="utf-8"))
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    content = original["choices"][0]["message"].get("content") or ""
    failures = [test for test in summary.get("tests", []) if not test["passed"]]
    if summary.get("error"):
        failures.append({"name": "module_load", "error": summary["error"]})
    feedback_lines = [f"- {item['name']}: {item['error']}" for item in failures]
    feedback = """The implementation was run against behavioral tests and did not fully pass.

Failing checks:
{failures}

Re-read the canonical contract in the original request and repair the implementation. Return the complete corrected Python module in one `python` code fence, with no explanation or tests.
""".format(failures="\n".join(feedback_lines) or "- none reported")

    prompt = (root / "prompts" / f"{args.profile}.txt").read_text(encoding="utf-8")
    payload = request_payload(args.model, prompt)
    payload["messages"] = [
        {"role": "user", "content": prompt},
        {"role": "assistant", "content": content},
        {"role": "user", "content": feedback},
    ]

    key = args.key_file.read_text(encoding="utf-8").strip()
    request = urllib.request.Request(
        args.endpoint,
        data=json.dumps(payload).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=900) as response:
        repaired = json.load(response)

    response_path = args.output / f"{args.model}-{args.profile}-repair.json"
    response_path.write_text(json.dumps(repaired, indent=2) + "\n", encoding="utf-8")
    evaluator = subprocess.run(
        [sys.executable, str(root / "evaluate.py"), str(response_path)],
        check=False,
        capture_output=True,
        text=True,
    )
    score = json.loads(evaluator.stdout.strip().splitlines()[-1])
    result = {
        "model": args.model,
        "profile": args.profile,
        "phase": "repair",
        "prompt_tokens": repaired.get("timings", {}).get("prompt_n"),
        "completion_tokens": repaired.get("timings", {}).get("predicted_n"),
        "prompt_tps": repaired.get("timings", {}).get("prompt_per_second"),
        "generation_tps": repaired.get("timings", {}).get("predicted_per_second"),
        "finish_reason": repaired["choices"][0].get("finish_reason"),
        "content_chars": len(repaired["choices"][0]["message"].get("content") or ""),
        "reasoning_chars": len(repaired["choices"][0]["message"].get("reasoning_content") or ""),
        "passed": score.get("passed", 0),
        "total": score.get("total", 16),
        "tests": score.get("tests", []),
        "error": score.get("error", ""),
    }
    repair_summary = args.output / f"{args.model}-{args.profile}-repair-summary.json"
    repair_summary.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
