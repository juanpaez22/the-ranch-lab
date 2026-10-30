#!/usr/bin/env python3
"""Summarize llama-context-sweep results without third-party dependencies."""

from __future__ import annotations

import csv
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def median(rows: list[dict[str, str]], field: str) -> float:
    return statistics.median(float(row[field]) for row in rows)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: summarize.py RESULT_DIRECTORY", file=sys.stderr)
        return 2

    result_dir = Path(sys.argv[1])
    input_path = result_dir / "results.csv"
    if not input_path.is_file():
        print(f"missing results file: {input_path}", file=sys.stderr)
        return 1

    with input_path.open(newline="", encoding="utf-8") as handle:
        input_rows = list(csv.DictReader(handle))

    grouped: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    order: list[tuple[str, str]] = []
    for row in input_rows:
        key = (row["model_id"], row["configured_context"])
        if key not in grouped:
            order.append(key)
        grouped[key].append(row)

    summary_rows: list[dict[str, str]] = []
    for key in order:
        rows = grouped[key]
        successful = [row for row in rows if row["status"] == "ok"]
        first = rows[0]
        if successful:
            generation_values = [float(row["generation_tps"]) for row in successful]
            summary_rows.append(
                {
                    "model_id": first["model_id"],
                    "label": first["label"],
                    "quantization": first["quantization"],
                    "configured_context": first["configured_context"],
                    "actual_context": successful[0]["actual_context"],
                    "status": "ok",
                    "successful_runs": str(len(successful)),
                    "median_prompt_tokens": f"{median(successful, 'prompt_tokens'):.0f}",
                    "median_generated_tokens": f"{median(successful, 'generated_tokens'):.0f}",
                    "median_prompt_tps": f"{median(successful, 'prompt_tps'):.2f}",
                    "median_generation_tps": f"{statistics.median(generation_values):.2f}",
                    "min_generation_tps": f"{min(generation_values):.2f}",
                    "max_generation_tps": f"{max(generation_values):.2f}",
                    "median_total_seconds": f"{median(successful, 'total_seconds'):.2f}",
                    "gpu_memory_used_mib": f"{median(successful, 'gpu_memory_used_mib'):.0f}",
                }
            )
        else:
            statuses = sorted({row["status"] for row in rows})
            summary_rows.append(
                {
                    "model_id": first["model_id"],
                    "label": first["label"],
                    "quantization": first["quantization"],
                    "configured_context": first["configured_context"],
                    "actual_context": first["actual_context"],
                    "status": "+".join(statuses),
                    "successful_runs": "0",
                    "median_prompt_tokens": "",
                    "median_generated_tokens": "",
                    "median_prompt_tps": "",
                    "median_generation_tps": "",
                    "min_generation_tps": "",
                    "max_generation_tps": "",
                    "median_total_seconds": "",
                    "gpu_memory_used_mib": "",
                }
            )

    fields = list(summary_rows[0]) if summary_rows else []
    with (result_dir / "summary.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(summary_rows)

    with (result_dir / "summary.md").open("w", encoding="utf-8") as handle:
        handle.write("# llama.cpp context sweep summary\n\n")
        handle.write("Generation values are medians across successful measured runs.\n\n")
        handle.write(
            "| Model | Quant | Context | Status | Runs | Generated tokens | "
            "Generation tok/s | Range | Prompt tok/s | Pre-request GPU MiB |\n"
        )
        handle.write("| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |\n")
        for row in summary_rows:
            generation = row["median_generation_tps"] or ""
            generation_range = (
                f"{row['min_generation_tps']} to {row['max_generation_tps']}"
                if generation
                else ""
            )
            handle.write(
                f"| {row['label']} | {row['quantization']} | {row['configured_context']} "
                f"| {row['status']} | {row['successful_runs']} | {row['median_generated_tokens']} "
                f"| {generation} | {generation_range} | {row['median_prompt_tps']} "
                f"| {row['gpu_memory_used_mib']} |\n"
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
