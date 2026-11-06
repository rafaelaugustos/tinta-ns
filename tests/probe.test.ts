import test from 'node:test'
import assert from 'node:assert/strict'
import { readProbeResult } from '../src/domain/probe.ts'

const sample = { frames: 450, pixelsValid: true, growthMiB: 1.5, baselineRSSMiB: 100, settledRSSMiB: 101.5, peakRSSMiB: 110, elapsedSeconds: 70 }

test('a complete report uses measured growth and pixel checks for its verdict', () => {
  assert.equal(readProbeResult(JSON.stringify(sample)).passed, true)
  assert.equal(readProbeResult(JSON.stringify({ ...sample, pixelsValid: false, passed: true })).passed, false)
  assert.equal(readProbeResult(JSON.stringify({ ...sample, growthMiB: 31, settledRSSMiB: 131, passed: true })).passed, false)
})

test('missing frames or unavailable measurements cannot become a passing report', () => {
  for (const change of [{ frames: 449 }, { baselineRSSMiB: -1 }, { elapsedSeconds: null }, { growthMiB: 0 }]) {
    assert.throws(() => readProbeResult(JSON.stringify({ ...sample, ...change })))
  }
  assert.throws(() => readProbeResult('{"error":"Buffer allocation failed"}'), /Buffer allocation/)
  assert.throws(() => readProbeResult('null'), /Incomplete/)
})
