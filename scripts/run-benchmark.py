#!/usr/bin/env python3
"""Run the installed iOS app's probe and keep its raw report."""
import argparse
import json
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('udid')
parser.add_argument('--runs', type=int, default=3)
parser.add_argument('--kind', choices=['offscreen', 'cadence', 'no-blur'], default='offscreen')
parser.add_argument('--output', type=Path, default=Path('benchmarks/results'))
args = parser.parse_args()
if args.runs < 1:
    parser.error('--runs must be positive')
args.output.mkdir(parents=True, exist_ok=True)
bundle = 'dev.rafaelaugusto.tinta'

def simctl(*values):
    return subprocess.check_output(['xcrun', 'simctl', *values], text=True).strip()

for run in range(1, args.runs + 1):
    name = 'canvas-cadence.json' if args.kind == 'cadence' else 'render-probe.json'
    container = Path(simctl('get_app_container', args.udid, bundle, 'data'))
    report = container / 'Documents' / 'benchmarks' / name
    previous = report.stat().st_mtime_ns if report.exists() else 0
    flags = ['--tinta-cadence'] if args.kind == 'cadence' else ['--tinta-probe']
    if args.kind == 'no-blur':
        flags.append('--tinta-no-blur')
    launched = simctl('launch', '--terminate-running-process', args.udid, bundle, *flags)
    pid = int(launched.rsplit(':', 1)[-1].strip())
    print(f'Run {run}: PID {pid}', flush=True)
    deadline = time.monotonic() + 150
    while time.monotonic() < deadline:
        if report.exists() and report.stat().st_mtime_ns > previous:
            data = json.loads(report.read_text())
            if data.get('pid') == pid:
                break
        time.sleep(1)
    else:
        raise SystemExit('No fresh report; the app may have stopped or failed to start.')
    destination = args.output / f'{args.kind}-{run}.json'
    destination.write_text(json.dumps(data, indent=2) + '\n')
    if args.kind == 'cadence':
        print(f"{data['uiCallbackHz']:.2f} UI callbacks/s; {destination}")
    else:
        print(f"{data['growthMiB']:+.2f} MiB; pixels={data['pixelsValid']}; {destination}")
        expected = args.kind != 'no-blur'
        if data['pixelsValid'] != expected or data['frames'] != 450:
            raise SystemExit('Pixel/workload verification did not match the expected result.')
        if expected and not data['passed']:
            raise SystemExit('The 30 MiB settled-growth gate failed.')
