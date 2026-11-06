# iOS validation

Checked on 2026-11-06.

- TypeScript/Vue typecheck passes.
- Both render-report validation tests pass, including failed pixels, missing frames and inconsistent memory deltas.
- Debug and Release simulator builds pass; the signed Release device build installs and launches on an iPhone 17 Pro running iOS 27.3.
- Flow, touch drawing, color and width changes, pause/resume, clear and one-step undo were exercised in the simulator.
- PNG export opened the share sheet. The exported 728 × 852 image contained the drawn Vermilion stroke.
- Tilt correctly reports unavailable in the simulator. Physical gravity responsiveness still needs a hands-on check.
- Live metrics were visually checked on both the simulator and physical iPhone. They show a measured callback rate and process RSS. Pausing changes the callback readout to 0.0.
- The opening and Flow capture in `media/` comes from the running Release simulator app.

The [benchmark reports](../benchmarks/RESULTS.md) record the measured workloads and their limits. Physical iPhone memory results and simulator memory results are kept separately. Build warnings remain in the Jolt dependency and NativeScript's generated Xcode scripts; the builds complete successfully.
