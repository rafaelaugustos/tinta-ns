# iOS render checks

These are two separate workloads. Neither reports hardware presentation FPS or establishes a framework ranking.

## Offscreen memory

The workload follows the shape of [tgfx PR #19](https://github.com/margelo/react-native-tgfx/pull/19): 450 renders at 512 × 512, a changing RGBA upload, a Gaussian blur with radius 4, an alternating red rectangle, synchronous pixel readback, and 150 ms between renders. Frames 0, 1 and 449 check the rectangle, uploaded blue channel and blurred boundary. Bypassing blur must fail the boundary assertion.

Tinta uses Core Image for this probe. It retains one `CIContext`, two 1 MiB CPU buffers, and drains an autorelease pool after every render. The context's intermediate cache is disabled. The native worker owns its input through synchronous readback before reusing the buffer.

There are 60 warmup renders. After a two-second wait, seven RSS readings are taken 120 ms apart; their median is the baseline. After the 450 measured renders, the same wait and sampling procedure gives the settled RSS. The context and buffers remain alive for both measurements. The sampled peak is taken every 15 renders and is not a high-frequency peak measurement. Reports include every sampled value, pixel checks and the process ID.

RSS comes from `mach_task_basic_info.resident_size`, in MiB. It includes the entire process, not just GPU memory. The drawing canvas is paused while this test runs. The growth gate is 30 MiB, matching the gate described in the tgfx PR. Passing that gate does not establish that memory use is lower than tgfx.

The renderer, warmup, filtering implementation and measurement method differ from the tgfx harness. A direct comparison requires running both pinned implementations on the same simulator or device with the same protocol. The supplied Tilt Pen clip is an app demonstration on an earlier tgfx build, separate from its 450-render regression test. Its absolute RSS figures cannot be compared directly to this app's footprint.

## Drawing cadence

A second run measures 30 seconds of the app's automatic ink flow at the default 1× speed. Jolt animates the bead; a native `CADisplayLink` samples its presentation position and paints into a retained Core Graphics bitmap. The report records callback count, elapsed callback intervals, maximum gap, mean time spent inside the native callback, and process RSS sampled every 60 callbacks. Reports from before `f14180e` used the canvas's own movement integration.

The callback rate is **UI scheduling cadence**, not GPU presentation FPS. The callback duration includes CPU drawing/submission, not asynchronous GPU completion. In the Jolt version it also excludes Jolt's separate animation and physics work, so before/after callback durations are not total rendering-cost comparisons. Capture this run separately from screen recording. The visible FPS/RSS labels sample the canvas once a second and stop updating in the background. Reports identify whether these labels were present.

## Reproduce

Build and install the app first. Each run starts a fresh process; the script requires a changed report with the launched process's PID, and refuses to overwrite recorded runs.

```sh
npm run build:ios
xcrun simctl install <udid> platforms/ios/build/Debug-iphonesimulator/tinta.app
npm run benchmark -- <udid> --runs 3
npm run benchmark -- <udid> --kind no-blur --runs 1
npm run benchmark -- <udid> --kind cadence --runs 3
```

The no-blur control is expected to fail pixel validation. The command treats that failure as the expected control result; it does not turn it into a passing render report.

Reports are written to `Documents/benchmarks` inside the app and copied to `benchmarks/results` by the runner. Keep the build configuration, OS, simulator/device, source revision and background workload alongside any published results. A simulator run says nothing about physical-device battery use or Apple Pencil input latency.

## Synthetic Tilt check

With a build installed, launch `xcrun simctl launch --terminate-running-process <udid> dev.rafaelaugusto.tinta --tinta-check-tilt`. After opening, the app replays constant gravity through Jolt's native sensor pipeline, checks movement along Y while X stays zero, and verifies that pause holds the body. The result is written to `Documents/benchmarks/tilt-check.json` in the app container, with its process ID and `synthetic: true`. This command works without simulator sensor hardware. It does not replace a test of the physical iPhone's sensor response.

## Physical iPhone

Sign a Release build with your development team, install it, and leave the phone unlocked with Tinta in the foreground:

```sh
npm run ios -- --device <iphone-udid> --release --team-id <team-id>
npm run benchmark -- <iphone-udid> --device --runs 3 --output benchmarks/iphone
npm run benchmark -- <iphone-udid> --device --kind no-blur --runs 1 --output benchmarks/iphone
npm run benchmark -- <iphone-udid> --device --kind cadence --runs 3 --output benchmarks/iphone
```

The device runner uses Xcode's `devicectl` to launch the app and copy its reports. After launch it waits until the expected finish window before reading files. Keep results from different OS versions and build configurations in separate directories.

New builds also record `task_vm_info.phys_footprint`, with the same settled-median procedure as RSS. The two metrics have different accounting and must be reported separately. These in-process footprint readings are not an Instruments trace. Unavailable footprint readings are marked explicitly; they do not affect the RSS gate. The original simulator reports predate this additional metric.

The reference PR also tested an iPhone 15 Pro in Release on iOS 27.0. Both its base and fixed workers showed about +2.4 MiB of settled physical-footprint growth in Instruments. That device run did not reproduce the simulator leak or demonstrate a hardware memory reduction.
