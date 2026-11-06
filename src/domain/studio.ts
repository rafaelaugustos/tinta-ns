export type InputMode = 'flow' | 'touch' | 'tilt'
export const modes: InputMode[] = ['flow', 'touch', 'tilt']
export const inks = [
  { name: 'Ultramarine', color: '#2232E8' },
  { name: 'Vermilion', color: '#E95031' },
  { name: 'Carbon', color: '#292C29' },
  { name: 'Moss', color: '#487C59' },
] as const
export interface ProbeResult {
  frames: number; pixelsValid: boolean; growthMiB: number
  baselineRSSMiB: number; settledRSSMiB: number; peakRSSMiB: number
  elapsedSeconds: number; passed: boolean; error?: string
}
