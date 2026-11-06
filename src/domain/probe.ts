import type { ProbeResult } from './studio'

/** Reject incomplete reports before presenting a successful memory result. */
export function readProbeResult(json: string): ProbeResult {
  const result = JSON.parse(json)
  if (result?.error) throw new Error(String(result.error))
  const numbers = ['growthMiB', 'baselineRSSMiB', 'settledRSSMiB', 'peakRSSMiB', 'elapsedSeconds']
  if (result?.frames !== 450 || numbers.some(key => typeof result[key] !== 'number' || !Number.isFinite(result[key])) || typeof result.pixelsValid !== 'boolean') {
    throw new Error('Incomplete render report')
  }
  if (result.baselineRSSMiB < 0 || result.settledRSSMiB < 0) throw new Error('RSS measurement unavailable')
  const growth = result.settledRSSMiB - result.baselineRSSMiB
  if (Math.abs(growth - result.growthMiB) > .01) throw new Error('Inconsistent RSS readings')
  return { ...result, passed: result.pixelsValid && growth <= 30 }
}
