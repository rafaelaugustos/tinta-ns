import test from 'node:test'
import assert from 'node:assert/strict'
import { beadRadius, flowFrames, flowPeriod, flowPoint } from '../src/domain/flow.ts'

const paper = { width: 364, height: 426 }

test('the repeated path closes without drawing a line across the paper', () => {
  const first = flowPoint(paper, 1.5)
  const last = flowPoint(paper, 1.5 + flowPeriod)
  assert.ok(Math.hypot(first.x - last.x, first.y - last.y) < 1e-8)
  const frames = flowFrames(paper, 1.5, flowPeriod)
  for (const x of frames.x) assert.ok(x >= 0 && x <= paper.width - beadRadius * 2)
  for (const y of frames.y) assert.ok(y >= 0 && y <= paper.height - beadRadius * 2)
})

test('starting Flow preserves the current position and joins its repeating curve', () => {
  const start = { x: 42, y: 330 }
  const frames = flowFrames(paper, 0, 1.5, start)
  assert.equal(frames.x[0], start.x - beadRadius)
  assert.equal(frames.y[0], start.y - beadRadius)
  const join = flowPoint(paper, 1.5)
  assert.ok(Math.abs(frames.x.at(-1)! + beadRadius - join.x) < .01)
  assert.ok(Math.abs(frames.y.at(-1)! + beadRadius - join.y) < .01)
})
