# Measured results

## Jolt motion and speed controls

Release build `f14180e` moves Flow, Touch following, Tilt physics and bead styling to Jolt RC.11. The retained bitmap still paints permanent ink. These runs use the default 1× speed, live FPS/RSS labels and a 728 × 852 bitmap. [Build metadata](results/jolt-refactor/environment.json).

| Run | UI callbacks/s | Largest interval | Mean painter callback | Sampled process RSS |
| --- | ---: | ---: | ---: | ---: |
| [Before, simulator](results/jolt-refactor/before/cadence-1.json) | 60.00 | 16.67 ms | 2.26 ms | 319.48–325.52 MiB |
| [Jolt, simulator 1](results/jolt-refactor/simulator/cadence-1.json) | 60.00 | 16.67 ms | 0.35 ms | 319.73–326.86 MiB |
| [Jolt, simulator 2](results/jolt-refactor/simulator/cadence-2.json) | 60.00 | 16.67 ms | 0.34 ms | 322.17–329.91 MiB |
| [Jolt, simulator 3](results/jolt-refactor/simulator/cadence-3.json) | 59.96 | 34.59 ms | 0.36 ms | 324.86–359.44 MiB |
| [Jolt, iPhone 17 Pro](results/jolt-refactor/iphone/cadence-1.json) | 59.99 | 16.70 ms | 0.26 ms | 111.44–119.17 MiB |

The baseline is one fresh-process Release run of `b01c343`. Host load was not isolated, and the third new simulator run includes a longer callback interval and a higher RSS sample. The shorter painter callback does **not** establish a rendering speedup: Jolt's animation work happens outside that callback. These measurements support keeping the UI cadence near 60/s for this workload, not a GPU-FPS or framework ranking.

One additional [physical-device offscreen run](results/jolt-refactor/iphone/offscreen-1.json) completed all 450 renders and passed every pixel check. Settled RSS moved from 117.45 to 112.81 MiB (−4.64 MiB); physical footprint changed by −5.53 MiB. This is the unchanged Core Image probe, separate from Jolt motion. Negative changes include process-wide reclamation.

Manual simulator checks covered Flow, Touch, 1×/1.5×/2×/3× changes, a complete cycle at 3×, pause/resume, background/foreground, ink/width selection, clear, undo and a valid 728 × 852 PNG export. Type checking and four unit tests passed. The signed build was installed on the iPhone for the cadence and offscreen runs. Tilt's physical feel still needs a hands-on device check; these automatic runs used Flow.

### Steady-angle Tilt regression

`adfd69b` keeps applying sensor acceleration when its values stay unchanged. Jolt's `replaySensor` supplied a constant synthetic gravity vector with X exactly zero through the native sensor pipeline. The body moved 109.32 points along Y in 900 ms, with no X drift; pausing held its position exactly for another 300 ms. The [replay report](results/jolt-refactor/simulator/tilt-check.json) passed. This validates the sensor-to-physics connection and pause behavior in the simulator, not physical sensor accuracy or feel. The Flow and offscreen figures above were collected before this Tilt-only correction.

## Initial measurements

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
