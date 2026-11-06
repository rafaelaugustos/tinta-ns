export interface Point { x: number; y: number }
export interface PaperSize { width: number; height: number }

const speed = .63
const response = 7
export const flowPeriod = 20 * Math.PI / speed
export const beadRadius = 15

// The same wandering curve as the original canvas, with its low-pass response
// solved ahead of time. Jolt receives keyframes once, rather than JS per frame.
export function flowPoint(size: PaperSize, seconds: number): Point {
  const wave = (frequency: number, phase = 0) => {
    const ratio = frequency / response
    return Math.sin(frequency * seconds + phase - Math.atan(ratio)) / Math.sqrt(1 + ratio * ratio)
  }
  return {
    x: size.width * (.5 + .36 * wave(speed) + .035 * wave(speed * 3)),
    y: size.height * (.5 + .31 * wave(speed * 1.7, .4)),
  }
}

export function flowFrames(size: PaperSize, offset: number, duration: number, start?: Point) {
  const count = Math.ceil(duration * 30)
  const initial = flowPoint(size, offset)
  const x: number[] = [], y: number[] = []
  for (let i = 0; i <= count; i++) {
    const time = duration * i / count
    const point = flowPoint(size, offset + time)
    const weight = start ? Math.exp(-response * time) : 0
    x.push(point.x + ((start?.x ?? 0) - initial.x) * weight - beadRadius)
    y.push(point.y + ((start?.y ?? 0) - initial.y) * weight - beadRadius)
  }
  return { x, y }
}

export function clampPoint(point: Point, size: PaperSize): Point {
  return {
    x: Math.max(beadRadius, Math.min(size.width - beadRadius, point.x)),
    y: Math.max(beadRadius, Math.min(size.height - beadRadius, point.y)),
  }
}
