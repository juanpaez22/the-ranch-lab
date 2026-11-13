#!/usr/bin/env python3
"""Create versioned summaries from ignored ranch-simulator run artifacts."""

from __future__ import annotations

import csv
import json
from pathlib import Path


def main() -> int:
    root = Path(__file__).parent
    results = root / "results"
    rows = []
    for summary_path in results.glob("*-summary.json"):
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        error = summary.get("error", "")
        if "SyntaxError:" in error:
            error = "SyntaxError:" + error.rsplit("SyntaxError:", 1)[1]
        response_name = summary_path.name.removesuffix("-summary.json") + ".json"
        response = json.loads((results / response_name).read_text(encoding="utf-8"))
        timings = response["timings"]
        rows.append(
            {
                "model": summary["model"],
                "profile": summary["profile"],
                "phase": summary.get("phase", "initial"),
                "prompt_tokens": summary["prompt_tokens"],
                "completion_tokens": summary["completion_tokens"],
                "prompt_seconds": f"{timings['prompt_ms'] / 1000:.2f}",
                "generation_seconds": f"{timings['predicted_ms'] / 1000:.2f}",
                "generation_tps": f"{summary['generation_tps']:.2f}",
                "finish_reason": summary["finish_reason"],
                "passed": summary["passed"],
                "total": summary["total"],
                "error": error,
            }
        )

    profile_order = {"8k": 0, "32k": 1, "60k": 2}
    rows.sort(key=lambda row: (profile_order[row["profile"]], row["phase"], row["model"]))
    fields = list(rows[0])
    with (root / "summary-20261031.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    with (root / "summary-20261031.md").open("w", encoding="utf-8") as handle:
        handle.write("# Filled-context ranch simulator summary, 2026-10-31\n\n")
        handle.write("| Model | Profile | Phase | Prompt tokens | Score | Prompt s | Generation s | Generation tok/s | Finish |\n")
        handle.write("| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |\n")
        for row in rows:
            handle.write(
                f"| {row['model']} | {row['profile']} | {row['phase']} | {row['prompt_tokens']} "
                f"| {row['passed']}/{row['total']} | {row['prompt_seconds']} | {row['generation_seconds']} "
                f"| {row['generation_tps']} | {row['finish_reason']} |\n"
            )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
