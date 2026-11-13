#!/usr/bin/env python3
"""Evaluate one chat-completion response for the missing-ranges task."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


TEST_PROGRAM = r'''
tests = [
    (([0, 1, 3, 50, 75], 0, 99), [(2, 2), (4, 49), (51, 74), (76, 99)]),
    (([], 1, 3), [(1, 3)]),
    (([1, 2, 3], 1, 3), []),
    (([3, 1, 1, 9, -5, 5], 1, 5), [(2, 2), (4, 4)]),
    (([-3, -1, 0, 2], -3, 2), [(-2, -2), (1, 1)]),
    (([4], 5, 4), []),
    (([7, 7, 6, 8], 7, 7), []),
    (([-10, 100], -1, 1), [(-1, 1)]),
]

for index, (args, expected) in enumerate(tests, start=1):
    original = list(args[0])
    actual = find_missing_ranges(*args)
    assert actual == expected, f"test {index}: expected {expected!r}, got {actual!r}"
    assert args[0] == original, f"test {index}: input was mutated"

print(f"passed {len(tests)}/{len(tests)} tests")
'''


def extract_code(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        content = text
    else:
        content = payload["choices"][0]["message"]["content"]

    if not isinstance(content, str):
        raise ValueError("response content is not text")
    content = content.strip()
    if content.startswith("```"):
        lines = content.splitlines()
        if len(lines) < 3 or not lines[-1].strip().startswith("```"):
            raise ValueError("response has an incomplete Markdown code fence")
        content = "\n".join(lines[1:-1])
        if content.startswith("python\n"):
            content = content.removeprefix("python\n")
    if "def find_missing_ranges" not in content:
        raise ValueError("response does not define find_missing_ranges")
    return content.rstrip() + "\n"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: evaluate.py RESPONSE_JSON_OR_CODE", file=sys.stderr)
        return 2

    try:
        code = extract_code(Path(sys.argv[1]))
    except (KeyError, IndexError, TypeError, ValueError) as error:
        print(f"invalid response: {error}", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory(prefix="ranch-coding-eval-") as directory:
        program = Path(directory) / "candidate.py"
        program.write_text(code + "\n" + TEST_PROGRAM, encoding="utf-8")
        try:
            completed = subprocess.run(
                [sys.executable, "-I", "-S", str(program)],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
        except subprocess.TimeoutExpired:
            print("failed: candidate timed out", file=sys.stderr)
            return 1

    if completed.returncode != 0:
        print(completed.stderr.rstrip() or "failed: candidate exited nonzero", file=sys.stderr)
        return 1
    print(completed.stdout.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
