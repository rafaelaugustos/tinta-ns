# Measured results

The initial simulator runs were measured on 2026-11-06 using source `691f30b`, a Debug build, and an iPhone 17 Pro simulator on iOS 27.0 (24A434). The host ran macOS 26.6.2. Two other simulators were booted. No screen recording was running during these measurements. Full build metadata is in [environment.json](environment.json).

## Offscreen render probe

| Fresh process | Baseline RSS | Settled RSS | Change | Pixel checks |
| --- | ---: | ---: | ---: | --- |
| 1 | 370.64 MiB | 364.45 MiB | -6.19 MiB | Pass |
| 2 | 370.27 MiB | 377.73 MiB | +7.47 MiB | Pass |
| 3 | 370.36 MiB | 364.81 MiB | -5.55 MiB | Pass |

All three runs completed 450 measured renders after 60 warmup renders and passed the 30 MiB settled-growth gate. The changing blue channel, moving red rectangle and blurred boundary passed on frames 0, 1 and 449.

The median RSS change was −5.55 MiB; the largest increase was +7.47 MiB. Negative deltas include reclamation elsewhere in the process and are not renderer memory savings. The spread is a reason to retain every run rather than report only the median.

**These results do not establish an improvement over tgfx’s reported +2 MiB.** The implementations and measurement protocols differ, and no paired tgfx build was run here. The original Tilt Pen clip’s multi-gigabyte RSS is not a valid baseline for this app.

Raw reports: [run 1](results/offscreen-1.json), [run 2](results/offscreen-2.json), [run 3](results/offscreen-3.json). See the [protocol](PROTOCOL.md) for the workload and accounting.

## Failure control

With blur disabled, all three boundary checks returned 255 and pixel validation failed, as intended. The render report remained a failure even though RSS grew by only +7.70 MiB. See the [no-blur report](results/no-blur-1.json).

## Drawing cadence

Each fresh process ran Flow for 30 seconds at a 728 × 852 bitmap size.

| Run | Callbacks | UI callback rate | Largest display-link interval | Mean native callback work |
| --- | ---: | ---: | ---: | ---: |
| [1](results/cadence-1.json) | 1800 | 60.00/s | 16.67 ms | 2.16 ms |
| [2](results/cadence-2.json) | 1800 | 60.00/s | 16.67 ms | 1.99 ms |
| [3](results/cadence-3.json) | 1800 | 60.00/s | 16.67 ms | 2.03 ms |

Intervals use `CADisplayLink.timestamp`. They describe UI scheduling, not GPU presentation FPS or end-to-end input latency. The native callback duration measures CPU work before asynchronous presentation. The third run overlapped with the start of a local Release build; it is retained here, not treated as an isolated timing result.

## Release sampler check

After adding physical-footprint sampling in `d557c3e`, one Release simulator run completed the same workload and passed all pixel checks. RSS changed by -5.23 MiB; physical footprint changed by -5.94 MiB. This checks the additional sampler and runner, not a repeated Release performance result. It is separate from the three Debug runs above.

[Report](results/release-simulator/offscreen-1.json) · [Build metadata](results/release-simulator/environment.json).

## Physical iPhone

An iPhone 17 Pro completed three fresh-process Release runs on iOS 27.3 (24C5037i), source `d557c3e`. These runs preceded the live FPS/RSS labels. The phone had just finished an OS update; thermal state and background system work were not controlled.

| Run | Baseline RSS | Settled RSS | RSS change | Physical-footprint change | Pixel checks |
| --- | ---: | ---: | ---: | ---: | --- |
| [1](results/iphone-release/offscreen-1.json) | 117.16 MiB | 110.64 MiB | -6.52 MiB | -7.59 MiB | Pass |
| [2](results/iphone-release/offscreen-2.json) | 114.80 MiB | 109.44 MiB | -5.36 MiB | -5.48 MiB | Pass |
| [3](results/iphone-release/offscreen-3.json) | 116.08 MiB | 99.14 MiB | -16.94 MiB | -5.16 MiB | Pass |

All runs completed 450 renders and passed the 30 MiB RSS-growth gate. Physical footprint was read through `task_vm_info`, separately from RSS. Negative deltas include process-wide reclamation; they do not mean rendering frees memory or establish a long-term leak-free result. This is not a paired test against tgfx. [Device metadata](results/iphone-release/environment.json).

### Live readout and interactive capture

Build `b01c343` adds live canvas callback FPS and process RSS labels. Both were visible on the physical iPhone; pause/resume was also checked in the simulator.

The first device cadence capture recorded 1,799 callbacks over 30.005 seconds, but input changed during capture and its final mode was Tilt. The runner rejected it as a Flow benchmark and stopped the sequence. It is retained as an [interactive capture](results/iphone-live-metrics/cadence-interactive.json), not included in the controlled Flow table. No further automatic launches were made while the phone was being used. [Build metadata](results/iphone-live-metrics/environment.json).
