#!/usr/bin/env python3
"""Grade a ranch-simulator chat completion with behavior-focused tests."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


TEST_PROGRAM = r'''
import copy
import json

results = []

def check(name, function):
    try:
        function()
    except Exception as error:
        results.append({"name": name, "passed": False, "error": f"{type(error).__name__}: {error}"})
    else:
        results.append({"name": name, "passed": True, "error": ""})

def expect_error(function):
    try:
        function()
    except SimulationError:
        return
    raise AssertionError("expected SimulationError")

def defaults_and_independence():
    first = RanchState()
    second = RanchState()
    assert (first.day, first.coins, first.feed, first.water, first.score, first.weather) == (1, 10, 4, 6, 0, "clear")
    first.animals["a"] = Animal("a", "cow")
    first.plots["p"] = Plot("p", "corn")
    first.log.append("x")
    assert not second.animals and not second.plots and not second.log

def setup_validation():
    sim = RanchSimulator(0)
    animal = sim.add_animal("bessie", "cow")
    plot = sim.add_plot("north", "corn")
    assert animal == Animal("bessie", "cow")
    assert plot == Plot("north", "corn")
    expect_error(lambda: sim.add_animal("bessie", "goat"))
    expect_error(lambda: sim.add_animal("", "cow"))
    expect_error(lambda: sim.add_animal("x", "horse"))
    expect_error(lambda: sim.add_plot("north", "berry"))
    expect_error(lambda: sim.add_plot("x", "wheat"))

def supplied_state_is_copied():
    state = RanchState()
    state.animals["a"] = Animal("a", "goat")
    sim = RanchSimulator(2, state)
    state.animals["a"].health = 1
    state.log.append("external")
    assert sim.state.animals["a"].health == 10
    assert sim.state.log == []

def deterministic_weather():
    assert RanchSimulator(0).weather_for(1) == "clear"
    assert RanchSimulator(2).weather_for(1) == "rain"
    assert RanchSimulator(1).weather_for(1) == "storm"
    assert RanchSimulator(0).weather_for(5) == "rain"

def clear_feed_and_growth():
    state = RanchState(feed=2)
    state.animals["a"] = Animal("a", "cow", energy=4, hunger=5)
    state.plots["p"] = Plot("p", "carrot", growth=0, water=1)
    sim = RanchSimulator(0, state)
    result = sim.advance_day([{"action": "feed", "target": "a"}])
    assert result.day == 2 and result.weather == "clear"
    assert (result.feed, result.animals["a"].hunger, result.animals["a"].energy, result.animals["a"].health) == (1, 4, 4, 10)
    assert (result.plots["p"].growth, result.plots["p"].water, result.plots["p"].ready) == (2, 0, False)
    assert "day 1: weather=clear" in result.log

def rain_waters_then_grows():
    state = RanchState()
    state.plots["p"] = Plot("p", "berry", growth=3, water=0)
    sim = RanchSimulator(2, state)
    sim.advance_day([])
    plot = sim.state.plots["p"]
    assert sim.state.weather == "rain"
    assert (plot.growth, plot.water, plot.ready) == (4, 0, False)

def storm_penalties():
    state = RanchState()
    state.animals["a"] = Animal("a", "goat", energy=2, hunger=5, health=10)
    state.plots["p"] = Plot("p", "corn", growth=2, water=1)
    sim = RanchSimulator(1, state)
    sim.advance_day([])
    animal = sim.state.animals["a"]
    plot = sim.state.plots["p"]
    assert sim.state.weather == "storm"
    assert (animal.energy, animal.hunger, animal.health) == (0, 7, 7)
    assert (plot.growth, plot.water) == (2, 1)

def duplicate_target_rolls_back():
    state = RanchState(feed=3)
    state.animals["a"] = Animal("a", "cow", energy=2, hunger=4)
    sim = RanchSimulator(0, state)
    before = sim.snapshot()
    expect_error(lambda: sim.advance_day([
        {"action": "feed", "target": "a"},
        {"action": "rest", "target": "a"},
    ]))
    assert sim.snapshot() == before

def resource_failure_rolls_back():
    state = RanchState(water=0)
    state.plots["p"] = Plot("p", "carrot")
    sim = RanchSimulator(0, state)
    before = sim.snapshot()
    expect_error(lambda: sim.advance_day([{"action": "water", "target": "p"}]))
    assert sim.snapshot() == before

def buy_feed_and_validation():
    sim = RanchSimulator(0, RanchState(coins=10, feed=1))
    sim.advance_day([{"action": "buy_feed", "amount": 3}])
    assert (sim.state.coins, sim.state.feed) == (4, 4)
    for amount in (0, -1, True, 1.5):
        bad = RanchSimulator(0, RanchState(coins=10, feed=1))
        before = bad.snapshot()
        expect_error(lambda amount=amount: bad.advance_day([{"action": "buy_feed", "amount": amount}]))
        assert bad.snapshot() == before
    poor = RanchSimulator(0, RanchState(coins=1))
    expect_error(lambda: poor.advance_day([{"action": "buy_feed", "amount": 1}]))

def harvest_resets_and_rewards():
    state = RanchState(coins=2, score=4)
    state.plots["p"] = Plot("p", "corn", growth=5, water=2, ready=True)
    sim = RanchSimulator(0, state)
    sim.advance_day([{"action": "harvest", "target": "p"}])
    plot = sim.state.plots["p"]
    assert (sim.state.coins, sim.state.score) == (8, 5)
    assert (plot.crop, plot.growth, plot.water, plot.ready) == ("corn", 0, 0, False)

def ready_plot_is_stable():
    state = RanchState()
    state.plots["p"] = Plot("p", "berry", growth=5, water=3, ready=True)
    sim = RanchSimulator(2, state)
    sim.advance_day([])
    plot = sim.state.plots["p"]
    assert (plot.growth, plot.water, plot.ready) == (5, 3, True)

def fox_and_market_events():
    fox = RanchSimulator(6, RanchState(feed=5))
    fox.advance_day([])
    assert fox.state.feed == 3
    market = RanchSimulator(12, RanchState(coins=5))
    market.advance_day([])
    assert market.state.coins == 8

def unknown_command_rolls_back():
    sim = RanchSimulator(0)
    before = sim.snapshot()
    expect_error(lambda: sim.advance_day([{"action": "dance", "target": "x"}]))
    assert sim.snapshot() == before

def snapshot_round_trip_and_detachment():
    sim = RanchSimulator(3)
    sim.add_animal("a", "chicken")
    sim.add_plot("p", "berry")
    sim.state.log.append("kept")
    payload = sim.snapshot()
    untouched = copy.deepcopy(payload)
    restored = RanchSimulator.from_snapshot(3, payload)
    assert restored.state == sim.state
    payload["animals"]["a"]["health"] = 1
    payload["log"].append("external")
    assert sim.state.animals["a"].health == 10
    assert restored.state.animals["a"].health == 10
    assert restored.state.log == ["kept"]
    assert untouched["animals"]["a"]["animal_id"] == "a"

def simulation_history_is_detached():
    sim = RanchSimulator(0)
    sim.add_animal("a", "cow")
    sim.add_plot("p", "carrot")
    history = sim.simulate([
        [{"action": "feed", "target": "a"}],
        [{"action": "water", "target": "p"}],
    ])
    assert len(history) == 2
    assert (history[0]["day"], history[1]["day"], sim.state.day) == (2, 3, 3)
    history[0]["animals"]["a"]["health"] = 0
    history[1]["log"].append("external")
    assert sim.state.animals["a"].health != 0
    assert "external" not in sim.state.log

tests = [
    ("defaults_and_independence", defaults_and_independence),
    ("setup_validation", setup_validation),
    ("supplied_state_is_copied", supplied_state_is_copied),
    ("deterministic_weather", deterministic_weather),
    ("clear_feed_and_growth", clear_feed_and_growth),
    ("rain_waters_then_grows", rain_waters_then_grows),
    ("storm_penalties", storm_penalties),
    ("duplicate_target_rolls_back", duplicate_target_rolls_back),
    ("resource_failure_rolls_back", resource_failure_rolls_back),
    ("buy_feed_and_validation", buy_feed_and_validation),
    ("harvest_resets_and_rewards", harvest_resets_and_rewards),
    ("ready_plot_is_stable", ready_plot_is_stable),
    ("fox_and_market_events", fox_and_market_events),
    ("unknown_command_rolls_back", unknown_command_rolls_back),
    ("snapshot_round_trip_and_detachment", snapshot_round_trip_and_detachment),
    ("simulation_history_is_detached", simulation_history_is_detached),
]

for name, function in tests:
    check(name, function)

passed = sum(item["passed"] for item in results)
print(json.dumps({"passed": passed, "total": len(results), "tests": results}, sort_keys=True))
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
    required = ("class SimulationError", "class Animal", "class Plot", "class RanchState", "class RanchSimulator")
    missing = [name for name in required if name not in content]
    if missing:
        raise ValueError(f"response is missing required definitions: {', '.join(missing)}")
    return content.rstrip() + "\n"


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: evaluate.py RESPONSE_JSON", file=sys.stderr)
        return 2

    try:
        code = extract_code(Path(sys.argv[1]))
    except (json.JSONDecodeError, KeyError, IndexError, TypeError, ValueError) as error:
        print(json.dumps({"passed": 0, "total": 16, "error": str(error)}, sort_keys=True))
        return 1

    with tempfile.TemporaryDirectory(prefix="ranch-sim-eval-") as directory:
        program = Path(directory) / "candidate.py"
        program.write_text(code + "\n" + TEST_PROGRAM, encoding="utf-8")
        try:
            completed = subprocess.run(
                [sys.executable, "-I", "-S", str(program)],
                check=False,
                capture_output=True,
                text=True,
                timeout=20,
            )
        except subprocess.TimeoutExpired:
            print(json.dumps({"passed": 0, "total": 16, "error": "candidate timed out"}, sort_keys=True))
            return 1

    if completed.returncode != 0:
        print(json.dumps({"passed": 0, "total": 16, "error": completed.stderr.strip() or "candidate exited nonzero"}, sort_keys=True))
        return 1
    lines = [line for line in completed.stdout.splitlines() if line.strip()]
    if not lines:
        print(json.dumps({"passed": 0, "total": 16, "error": "candidate produced no test result"}, sort_keys=True))
        return 1
    print(lines[-1])
    result = json.loads(lines[-1])
    return 0 if result["passed"] == result["total"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
