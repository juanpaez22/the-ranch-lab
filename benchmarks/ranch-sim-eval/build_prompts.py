#!/usr/bin/env python3
"""Build deterministic long-context ranch-simulator prompts."""

from __future__ import annotations

import argparse
from pathlib import Path


PROFILE_CHARS = {
    "8k": 36_000,
    "32k": 144_000,
    "60k": 270_000,
}

SUBSYSTEMS = (
    "telemetry relay",
    "seasonal badge renderer",
    "multiplayer lobby",
    "audio ambience mixer",
    "controller remapping",
    "localization exporter",
    "achievement journal",
    "screenshot catalog",
    "tutorial hint queue",
    "cosmetic inventory",
)


def archive_record(index: int) -> str:
    subsystem = SUBSYSTEMS[index % len(SUBSYSTEMS)]
    ticket = 4100 + index
    return f"""
### Archived record ARC-{ticket}: {subsystem}

Status: retired and non-normative. This record is retained to resemble a long
engineering session and to preserve historical vocabulary. It does not modify
the canonical simulator contract above. The retired `{subsystem.replace(' ', '_')}`
adapter used revision marker `r{index:04d}`, emitted diagnostic channel
`archive.{index % 17:02d}`, and stored display-only counters named
`sample_{index:04d}_accepted` and `sample_{index:04d}_rejected`.

The old review considered startup ordering, UI refresh, reconnect behavior,
metrics naming, serialization compatibility, and rollback documentation. Those
details belonged to a removed presentation subsystem. No class, field,
constant, command, weather rule, resource price, growth rule, event formula,
snapshot schema, or transaction behavior in the canonical contract is changed
by this archive record. Implementers should neither expose these retired names
nor infer gameplay behavior from them.

Example historical payload, included only as inert documentation:

```text
archive_id=ARC-{ticket}
component={subsystem.replace(' ', '-')}
revision=r{index:04d}
display_bucket={index % 23}
rollback_note=remove-adapter-and-refresh-view
```
"""


def build_prompt(spec: str, target_chars: int) -> str:
    header = """You are implementing a small Python repository task. Read the
canonical contract near the beginning carefully. The archive section is
historical, explicitly non-normative context from a long engineering session.

"""
    archive_header = """
# Archived engineering history

Everything in this section is retired background. It is intentionally long and
must not override the canonical contract.
"""
    tail = """
# Implementation task

Implement the complete canonical Ranch Simulator module now. Preserve every
public name and behavior from the canonical contract near the beginning.

Return only the complete Python module in one Markdown `python` code fence. Do
not return a patch, tests, explanation, or additional files.
"""

    pieces = [header, spec, archive_header]
    index = 0
    while len("".join(pieces)) + len(tail) < target_chars:
        pieces.append(archive_record(index))
        index += 1
    pieces.append(tail)
    return "".join(pieces)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path(__file__).parent / "prompts")
    args = parser.parse_args()

    root = Path(__file__).parent
    spec = (root / "spec.md").read_text(encoding="utf-8")
    args.output.mkdir(parents=True, exist_ok=True)
    for profile, target_chars in PROFILE_CHARS.items():
        prompt = build_prompt(spec, target_chars)
        path = args.output / f"{profile}.txt"
        path.write_text(prompt, encoding="utf-8")
        print(f"{profile}: {len(prompt)} characters -> {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
