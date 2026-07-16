# M10 Instruments Evidence

This file records the final Instruments pass required by the M10 performance target. The simulator performance verifier is repeatable local evidence, but this file must be filled from a signed Release build running on a trusted physical device before shipping.

Every Evidence cell must cite the observed profiling proof, not only say "passed". The verifier checks for these proof terms: P01 `home`, `launch`, `ms`; P02 `camera`, `preview`, `ms`; P03 `scroll` plus either `fps` or `no dropped`; P04 `memory`, `mb`; P05 `time profiler`, `allocations`, `trace`.

The `Time Profiler trace` and `Allocations trace` metadata values must point to retained trace files or directories. Relative paths are resolved from this evidence file's directory.

## Metadata

| Field | Value |
| --- | --- |
| Device model | TBD |
| iOS version | TBD |
| Release build | TBD |
| Signed archive | TBD |
| Tester | TBD |
| Date | TBD |
| Time Profiler trace | TBD |
| Allocations trace | TBD |
| Home launch duration | TBD |
| Camera ready duration | TBD |
| Home scroll FPS | TBD |
| Home steady memory | TBD |

## Criteria

| ID | Criterion | Result | Evidence |
| --- | --- | --- | --- |
| P01 | Cold launch reaches Home in under 900 ms on an iPhone 12-class or better physical device. | Pending | TBD |
| P02 | Tapping `Snap to sell` opens a live camera preview within 400 ms on the physical device. | Pending | TBD |
| P03 | Home history with 500 rows sustains 120 fps on ProMotion devices or records no dropped frames at native refresh. | Pending | TBD |
| P04 | Home steady-state memory stays under 120 MB in Allocations. | Pending | TBD |
| P05 | Time Profiler and Allocations traces are recorded and retained with this release evidence. | Pending | TBD |

## Commands

Record a complete Instruments pass:

```sh
bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```

Until signed Release hardware profiling is complete, record the known blocker:

```sh
ALLOW_PENDING_INSTRUMENTS=1 bash Scripts/verify_m10_instruments_evidence.sh M10_INSTRUMENTS.md
```
