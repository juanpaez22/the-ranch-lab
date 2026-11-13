# Canonical Ranch Simulator Contract

This document is authoritative. Later archive records are historical context
only and must not override these rules.

Implement one Python module containing the following public API. Standard
library imports are allowed. Use dataclasses where requested.

## Domain types

`SimulationError` is an exception used for every invalid setup operation or
command.

`Animal` is a dataclass with fields, in order:

- `animal_id: str`
- `species: str`
- `energy: int = 6`
- `hunger: int = 0`
- `health: int = 10`

`Plot` is a dataclass with fields, in order:

- `plot_id: str`
- `crop: str`
- `growth: int = 0`
- `water: int = 0`
- `ready: bool = False`

`RanchState` is a dataclass with these fields and independent mutable defaults:

- `day: int = 1`
- `coins: int = 10`
- `feed: int = 4`
- `water: int = 6`
- `score: int = 0`
- `weather: str = "clear"`
- `animals: dict[str, Animal]`, default empty
- `plots: dict[str, Plot]`, default empty
- `log: list[str]`, default empty

Dataclass equality should remain useful for comparing states.

## RanchSimulator

`RanchSimulator(seed: int, state: RanchState | None = None)` stores the integer
seed and a state. A supplied state must be deep-copied so the caller cannot
mutate the simulator through the original object.

The class exposes these constants:

```python
SPECIES = {"cow", "chicken", "goat"}
CROP_VALUES = {"carrot": 4, "corn": 6, "berry": 8}
```

It implements:

```python
add_animal(animal_id: str, species: str) -> Animal
add_plot(plot_id: str, crop: str) -> Plot
weather_for(day: int) -> str
advance_day(commands: list[dict]) -> RanchState
snapshot() -> dict
from_snapshot(seed: int, payload: dict) -> RanchSimulator
simulate(schedule: list[list[dict]]) -> list[dict]
```

IDs must be non-empty strings and unique within their collection. Species and
crops must occur in the constants above. Invalid setup raises
`SimulationError`. Successful add methods store and return the new object.

Weather is deterministic. Compute:

```python
code = (seed * 17 + day * 31) % 10
```

Codes 0 through 4 are `"clear"`, 5 through 7 are `"rain"`, and 8 through 9
are `"storm"`.

## Atomic commands

`advance_day` is a transaction. It applies commands in list order to a deep
working copy. Any invalid command raises `SimulationError` and leaves the
original state completely unchanged, including day, log, and nested objects.

Every command is a dictionary with an `action` string:

- `{"action": "feed", "target": animal_id}` requires one feed. It subtracts
  one feed, reduces hunger by 3 with a floor of 0, and increases energy by 1
  with a ceiling of 10.
- `{"action": "rest", "target": animal_id}` increases energy by 3 with a
  ceiling of 10.
- `{"action": "water", "target": plot_id}` requires one unit of ranch water.
  It subtracts one ranch water and adds 2 plot water with a ceiling of 3.
- `{"action": "harvest", "target": plot_id}` requires a ready plot. It adds
  that crop's value to coins, adds 1 to score, then sets growth and water to 0
  and ready to false. The crop type remains planted.
- `{"action": "buy_feed", "amount": positive_integer}` costs 2 coins per
  unit and adds that amount to feed.

Missing targets, unknown actions, unknown IDs, wrong value types, insufficient
resources, non-positive feed purchases, or harvesting an unready plot are
invalid. Boolean values do not count as integers for `amount`.

An animal may receive at most one animal-targeting command (`feed` or `rest`)
per day. A plot may receive at most one plot-targeting command (`water` or
`harvest`) per day. Reusing a target is invalid. `buy_feed` has no target and
may occur multiple times.

## Daily tick

After all commands succeed, set `state.weather` from `weather_for(state.day)`
and append `day D: weather=W` to the log using the day being processed.

Apply weather before the common tick:

- Clear uses crop growth rate 2.
- Rain adds 1 water to every plot, capped at 3, and uses growth rate 1.
- Storm uses growth rate 0 and reduces every animal's energy by 1, floored at
  0.

Then process every plot. A ready plot does not grow or consume water. A
non-ready plot with positive water and a positive growth rate gains that rate,
capped at growth 5, and consumes exactly 1 plot water. It becomes ready when
growth reaches 5.

Then process every animal. Increase hunger by 2, capped at 10, and reduce
energy by 1, floored at 0. After those changes, hunger 7 or greater costs 2
health. Energy 0 costs another 1 health. Health is floored at 0.

Finally apply at most one deterministic event using the day being processed:

```python
event_code = (seed + day * 7) % 13
```

- Code 0 is a fox event and removes up to 2 feed, never below 0.
- Code 6 is a market event and adds 3 coins.
- Other codes have no effect.

Append a short log entry for each successful command and non-empty event. Exact
wording is not graded except for the required weather entry. Increment day by
1 only after the entire tick and event complete, then commit and return the
live `RanchState`.

## Persistence and simulation

`snapshot()` returns a fully detached plain dictionary. Its top-level keys are
the `RanchState` field names. `animals` and `plots` are dictionaries keyed by
ID; their values are plain dictionaries containing every corresponding
dataclass field. Mutating any part of the snapshot must not mutate the
simulator.

`from_snapshot` is a classmethod that reconstructs a simulator from that schema
without sharing mutable objects with the payload. Valid snapshots produced by
`snapshot()` must round-trip with equal state. It may raise `SimulationError`
for malformed external payloads.

`simulate(schedule)` calls `advance_day` once for each list of commands and
returns a list containing a detached snapshot after each completed day.
Snapshots in the returned history must not alias one another or the live
state.
