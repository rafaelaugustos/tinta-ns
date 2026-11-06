import test from 'node:test'
import assert from 'node:assert/strict'
import { beadRadius, edgeOvershoot, flowFrames, flowPeriod, flowPoint } from '../src/domain/flow.ts'

const paper = { width: 364, height: 426 }

test('the repeated path closes without drawing a line across the paper', () => {
  const first = flowPoint(paper, 1.5)
  const last = flowPoint(paper, 1.5 + flowPeriod)
  assert.ok(Math.hypot(first.x - last.x, first.y - last.y) < 1e-8)
  const frames = flowFrames(paper, 1.5, flowPeriod)
  for (const x of frames.x) assert.ok(x >= 0 && x <= paper.width + edgeOvershoot * 2 - beadRadius * 2)
  for (const y of frames.y) assert.ok(y >= 0 && y <= paper.height + edgeOvershoot * 2 - beadRadius * 2)
})

test('starting Flow preserves the current position and joins its repeating curve', () => {
  const start = { x: 42, y: 330 }
  const frames = flowFrames(paper, 0, 1.5, start)
  assert.equal(frames.x[0], start.x + edgeOvershoot - beadRadius)
  assert.equal(frames.y[0], start.y + edgeOvershoot - beadRadius)
  const join = flowPoint(paper, 1.5)
  assert.ok(Math.abs(frames.x.at(-1)! + beadRadius - edgeOvershoot - join.x) < .01)
  assert.ok(Math.abs(frames.y.at(-1)! + beadRadius - edgeOvershoot - join.y) < .01)
})

test('Flow crosses all four display edges and turns back within the motion stage', () => {
  for (const size of [{ width: 320, height: 568 }, { width: 402, height: 874 }]) {
    const frames = flowFrames(size, 0, flowPeriod)
    for (const [values, length] of [[frames.x, size.width], [frames.y, size.height]] as const) {
      const first = Math.min(...values), last = Math.max(...values)
      assert.ok(first >= 0 && last <= length + edgeOvershoot * 2 - beadRadius * 2)
      assert.ok(first + beadRadius - edgeOvershoot < -beadRadius)
      assert.ok(last + beadRadius - edgeOvershoot > length + beadRadius)
    }
  }
})
