#!/usr/bin/env python3
"""Run filled-context ranch-simulator evaluations through llama.cpp."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.request
from pathlib import Path


def request_payload(model: str, prompt: str) -> dict:
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0,
        "max_tokens": 8192,
        "cache_prompt": False,
    }
    if model.startswith("gpt-oss"):
        payload["reasoning_effort"] = "low"
    else:
        payload["chat_template_kwargs"] = {"enable_thinking": False}
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--profile", choices=("8k", "32k", "60k"), required=True)
    parser.add_argument("--endpoint", default="http://127.0.0.1:19331/v1/chat/completions")
    parser.add_argument("--key-file", type=Path, default=Path.home() / ".config/llama.cpp/api.key")
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "results")
    args = parser.parse_args()

    root = Path(__file__).parent
    prompt_path = root / "prompts" / f"{args.profile}.txt"
    prompt = prompt_path.read_text(encoding="utf-8")
    key = args.key_file.read_text(encoding="utf-8").strip()
    if not key:
        raise SystemExit("API key file is empty")

    body = json.dumps(request_payload(args.model, prompt)).encode()
    request = urllib.request.Request(
        args.endpoint,
        data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=900) as response:
        payload = json.load(response)

    args.output.mkdir(parents=True, exist_ok=True)
    response_path = args.output / f"{args.model}-{args.profile}.json"
    response_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    evaluator = subprocess.run(
        [sys.executable, str(root / "evaluate.py"), str(response_path)],
        check=False,
        capture_output=True,
        text=True,
    )
    score = json.loads(evaluator.stdout.strip().splitlines()[-1])
    summary = {
        "model": args.model,
        "profile": args.profile,
        "prompt_tokens": payload.get("timings", {}).get("prompt_n"),
        "completion_tokens": payload.get("timings", {}).get("predicted_n"),
        "prompt_tps": payload.get("timings", {}).get("prompt_per_second"),
        "generation_tps": payload.get("timings", {}).get("predicted_per_second"),
        "finish_reason": payload["choices"][0].get("finish_reason"),
        "content_chars": len(payload["choices"][0]["message"].get("content") or ""),
        "reasoning_chars": len(payload["choices"][0]["message"].get("reasoning_content") or ""),
        "passed": score.get("passed", 0),
        "total": score.get("total", 16),
        "tests": score.get("tests", []),
        "error": score.get("error", ""),
    }
    summary_path = args.output / f"{args.model}-{args.profile}-summary.json"
    summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
