#!/usr/bin/env python3
"""Run an installed Tinta build and keep each fresh process's raw report."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('udid')
parser.add_argument('--device', action='store_true', help='Use a physical iPhone through devicectl')
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


def launch(flags, directory):
    if not args.device:
        output = simctl('launch', '--terminate-running-process', args.udid, bundle, *flags)
        return int(output.rsplit(':', 1)[-1].strip())
    result = directory / 'launch.json'
    subprocess.run([
        'xcrun', 'devicectl', 'device', 'process', 'launch',
        '--device', args.udid, '--terminate-existing', '--json-output', str(result),
        bundle, *flags,
    ], check=True, stdout=subprocess.DEVNULL)
    return json.loads(result.read_text())['result']['process']['processIdentifier']


def read_report(name, directory):
    if not args.device:
        container = Path(simctl('get_app_container', args.udid, bundle, 'data'))
        report = container / 'Documents' / 'benchmarks' / name
        return json.loads(report.read_text()) if report.exists() else None
    report = directory / name
    report.unlink(missing_ok=True)
    result = subprocess.run([
        'xcrun', 'devicectl', 'device', 'copy', 'from', '--device', args.udid,
        '--domain-type', 'appDataContainer', '--domain-identifier', bundle,
        '--source', f'Documents/benchmarks/{name}', '--destination', str(report),
        '--timeout', '10', '--quiet',
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return json.loads(report.read_text()) if result.returncode == 0 and report.exists() else None


with tempfile.TemporaryDirectory(prefix='tinta-probe-') as temporary:
    directory = Path(temporary)
    for run in range(1, args.runs + 1):
        destination = args.output / f'{args.kind}-{run}.json'
        if destination.exists():
            raise SystemExit(f'{destination} already exists; choose a new --output directory.')
        name = 'canvas-cadence.json' if args.kind == 'cadence' else 'render-probe.json'
        previous = read_report(name, directory)
        flags = ['--tinta-cadence'] if args.kind == 'cadence' else ['--tinta-probe']
        if args.kind == 'no-blur':
            flags.append('--tinta-no-blur')
        pid = launch(flags, directory)
        print(f'Run {run}: PID {pid}', flush=True)
        deadline = time.monotonic() + 150
        # Leave the workload alone until its earliest expected finish.
        time.sleep(35 if args.kind == 'cadence' else 75)
        while time.monotonic() < deadline:
            data = read_report(name, directory)
            if data and data.get('pid') == pid and data != previous:
                break
            time.sleep(3)
        else:
            raise SystemExit('No fresh report; check that the app is running and the device is unlocked.')
        destination.write_text(json.dumps(data, indent=2) + '\n')
        if args.kind == 'cadence':
            if data['seconds'] < 30 or data['frames'] < 1 or data['mode'] != 0:
                raise SystemExit('The drawing capture did not complete in Flow mode.')
            print(f"{data['uiCallbackHz']:.2f} UI callbacks/s; {destination}", flush=True)
        else:
            print(f"RSS {data['growthMiB']:+.2f} MiB; pixels={data['pixelsValid']}; {destination}", flush=True)
            if data.get('physicalFootprintAvailable'):
                print(f"Physical footprint {data['physicalFootprintGrowthMiB']:+.2f} MiB", flush=True)
            expected = args.kind != 'no-blur'
            if data['pixelsValid'] != expected or data['frames'] != 450:
                raise SystemExit('Pixel/workload verification did not match the expected result.')
            if expected and not data['passed']:
                raise SystemExit('The 30 MiB settled-growth gate failed.')
