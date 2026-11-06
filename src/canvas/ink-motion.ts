import { Color, GridLayout } from '@nativescript/core'
import { bind, motionScope, set, springValue, type PlaybackAnimation, type SpringValue } from '@rafaelaugusto/jolt'
import { gestures, type GestureSurface, type Gestures } from '@rafaelaugusto/jolt/gestures'
import { physicsWorld, type PhysicsWorld } from '@rafaelaugusto/jolt/physics'
import { sensor, type GravitySensor } from '@rafaelaugusto/jolt/sensors'
import { shape } from '@rafaelaugusto/jolt/shapes'
import type { InputMode } from '../domain/studio'
import { beadRadius, clampPoint, flowFrames, flowPeriod, type Point, type PaperSize } from '../domain/flow'

export class InkMotion {
  private readonly scope = motionScope()
  private readonly input: Gestures
  private readonly contact: TintaContactObserver
  private readonly finishGradient: ReturnType<typeof this.scope.gradient>
  private flow?: PlaybackAnimation
  private world?: PhysicsWorld
  private gravity?: GravitySensor
  private releaseGravity?: () => void
  private followers: SpringValue[] = []
  private unbind?: () => void
  private generation = 0
  private speed = 1
  private flowOffset = 0
  private mode?: InputMode
  private running = false
  private interactive = false
  private disposed = false
  private offset: Point = { x: 0, y: 0 }
  private size: PaperSize
  private initialPoint: Point

  constructor(
    private readonly surface: GestureSurface,
    private readonly paper: TintaCanvas,
    private readonly actor: GridLayout,
    private readonly finish: GridLayout,
    private readonly touched: () => void,
  ) {
    this.size = surface.getActualSize()
    this.initialPoint = { x: this.size.width * .3, y: this.size.height * .5 }
    paper.trackedView = actor.nativeViewProtected
    this.place(this.initialPoint)
    paper.resetTracking()
    this.finishGradient = this.scope.gradient(finish, {
      type: 'linear', angle: 145, colors: ['#676DFF', '#273AE8', '#141D8B'], stops: [0, .45, 1],
    })
    this.scope.use(() => shape(finish, {
      viewBox: [0, 0, 30, 30], d: 'M9 9 L13 6.5', stroke: '#FFFFFFA6', strokeWidth: 3.5, lineCap: 'round',
    }))
    this.input = gestures(surface, {
      pan: { threshold: 1 },
      spring: { stiffness: 36, damping: 12, mass: 1 },
      onEnd: event => {
        if (this.mode !== 'touch' || !this.running) return
        // Native Jolt gesture springs carry release velocity to a bounded landing.
        this.input.settleTo({ x: event.x + event.velocityX * .12, y: event.y + event.velocityY * .12 })
      },
      onContactEnd: () => {
        if (!this.disposed) this.scope.animate(finish, { scale: 1 }, { type: 'spring', duration: 350, bounce: .08 })
      },
    })
    // Only the initial absolute contact crosses to JS. Pan and follower frames
    // remain in Jolt; its gesture values otherwise describe relative movement.
    this.contact = TintaContactObserver.attachToViewContact(surface.nativeViewProtected, (x, y) => this.beginTouch({ x, y }))
    this.setInteractive(false)
  }

  setInk(value: string) {
    const color = new Color(value)
    const rgb = (r: number, g: number, b: number) => new Color(255, Math.round(r), Math.round(g), Math.round(b))
    this.paper.inkColor = color.ios
    this.finishGradient.animate({ colors: [
      rgb(Math.min(255, color.r + 64), Math.min(255, color.g + 64), Math.min(255, color.b + 38)),
      color, rgb(color.r * .5, color.g * .5, color.b * .6),
    ] }, { duration: 160 })
  }

  private position(): Point { return this.paper.currentPoint }
  private place(point: Point) { set(this.actor, { x: point.x - beadRadius, y: point.y - beadRadius }) }

  private stopDriver() {
    // The initial placement has not reached Core Animation's presentation yet.
    const point = this.mode ? this.position() : this.initialPoint
    this.generation++
    this.flow?.stop(); this.flow = undefined
    this.unbind?.(); this.unbind = undefined
    this.followers.forEach(value => value.dispose()); this.followers = []
    this.gravity?.pause()
    this.world?.dispose(); this.world = undefined
    this.place(point)
    return point
  }

  setMode(mode: InputMode) {
    if (this.mode === mode) return
    const point = this.stopDriver()
    this.mode = mode
    this.paper.mode = ['flow', 'touch', 'tilt'].indexOf(mode)
    if (mode === 'flow' && this.running) this.startFlow(point)
    if (mode === 'touch') this.followTouch(point, point)
    if (mode === 'tilt') {
      // Physics owns this dedicated view's native transform. Restore Core's
      // model before handing it over; Jolt starts the body at the visible pose.
      set(this.actor, { x: 0, y: 0 })
      this.world = physicsWorld(this.surface, [{ id: 'ink', view: this.actor, radius: beadRadius, ...clampPoint(point, this.size) }], {
        gravity: { x: 0, y: 0 }, damping: 1.8, restitution: .65, reducedMotion: 'continue',
      })
      if (!this.running) this.world.pause()
    }
    this.paper.resetTracking()
    this.applyRunning()
  }

  private startFlow(point: Point, offset = 0) {
    const generation = this.generation
    const introSeconds = 1.5
    this.flowOffset = offset
    this.flow = this.scope.animate(this.actor, flowFrames(this.size, offset, introSeconds, point), { duration: introSeconds * 1000 / this.speed, ease: 'linear' })
    this.flow.finished.then(completed => {
      if (!completed || this.disposed || generation !== this.generation) return
      this.loopFlow((offset + introSeconds) % flowPeriod, generation)
    })
    if (!this.running) this.flow.pause()
  }

  private loopFlow(offset: number, generation: number) {
    this.flowOffset = offset
    this.flow = this.scope.animate(this.actor, flowFrames(this.size, offset, flowPeriod), { duration: flowPeriod * 1000 / this.speed, ease: 'linear' })
    this.flow.finished.then(completed => {
      if (completed && !this.disposed && generation === this.generation) this.loopFlow(offset, generation)
    })
    if (!this.running) this.flow.pause()
  }

  private followTouch(point: Point, target: Point) {
    this.unbind?.()
    this.followers.forEach(value => value.dispose())
    const position = this.input.position
    this.offset = { x: target.x - beadRadius - position.x, y: target.y - beadRadius - position.y }
    this.input.updateBounds({ left: -this.offset.x, right: this.size.width - 30 - this.offset.x, top: -this.offset.y, bottom: this.size.height - 30 - this.offset.y })
    const mapped = (axis: 'x' | 'y') => this.input[axis].to([-10000, 10000], [-10000 + this.offset[axis], 10000 + this.offset[axis]], { clamp: false })
    const spring = { stiffness: 324 * this.speed ** 2, damping: 36 * this.speed }
    const x = springValue(mapped('x'), { ...spring, initial: point.x - beadRadius })
    const y = springValue(mapped('y'), { ...spring, initial: point.y - beadRadius })
    this.followers = [x, y]
    this.unbind = bind(this.actor, { x, y })
    if (!this.running) this.followers.forEach(value => value.pause())
  }

  private beginTouch(target: Point) {
    if (!this.interactive || this.disposed) return
    this.paper.saveUndo()
    const point = this.stopDriver()
    this.mode = 'touch'; this.paper.mode = 1; this.running = true
    this.followTouch(point, clampPoint(target, this.size))
    this.paper.running = true
    this.scope.animate(this.finish, { scale: .94 }, { type: 'spring', duration: 200, bounce: 0 })
    this.touched()
  }

  tiltAvailable() {
    if (!this.gravity) {
      this.gravity = sensor('gravity', { interval: 32, reducedMotion: 'continue', scope: this.scope })
      let previous = -Infinity
      this.releaseGravity = this.gravity.x.subscribe((x, time) => {
        const elapsed = time - previous
        if (elapsed < 32) return
        previous = time
        if (!this.running || this.mode !== 'tilt' || !this.world) return
        const dt = Number.isFinite(elapsed) ? Math.min(.05, elapsed / 1000) : .032
        this.world.impulse('ink', { x: x * 110 * this.speed * dt, y: -this.gravity!.y.get() * 110 * this.speed * dt })
      })
      this.gravity.pause()
    }
    return this.gravity.available
  }

  setRunning(value: boolean) { this.running = value; this.applyRunning() }
  setSpeed(value: number) {
    if (!Number.isFinite(value) || value < 1 || value > 3 || value === this.speed) return
    const point = this.position()
    const elapsed = this.flow ? this.flow.progress * this.flow.duration : 0
    const offset = (this.flowOffset + elapsed * this.speed / 1000) % flowPeriod
    this.speed = value
    if (this.flow) {
      this.generation++; this.flow.stop(); this.flow = undefined
      this.place(point); this.startFlow(point, offset)
    } else if (this.mode === 'touch') {
      const position = this.input.position
      this.followTouch(point, { x: position.x + this.offset.x + beadRadius, y: position.y + this.offset.y + beadRadius })
    }
  }
  private applyRunning() {
    this.paper.running = this.running
    if (this.running) {
      if (this.mode === 'flow' && !this.flow) this.startFlow(this.position())
      this.flow?.play(); this.followers.forEach(value => value.play()); this.world?.play()
      if (this.mode === 'tilt') { this.tiltAvailable(); this.gravity?.play() }
    } else {
      this.flow?.pause(); this.followers.forEach(value => value.pause()); this.world?.pause(); this.gravity?.pause()
    }
  }
  setInteractive(value: boolean) {
    this.interactive = value; this.contact.enabled = value
    if (value) this.input.play(); else this.input.pause()
  }
  resize() {
    const size = this.surface.getActualSize()
    if (size.width === this.size.width && size.height === this.size.height) return
    const mode = this.mode
    const point = this.stopDriver()
    this.mode = undefined; this.size = size; this.initialPoint = clampPoint(point, size)
    if (mode) this.setMode(mode)
  }
  dispose() {
    if (this.disposed) return
    this.disposed = true; this.contact.dispose(); this.input.dispose()
    this.stopDriver(); this.releaseGravity?.(); this.scope.dispose()
    this.paper.trackedView = null
  }
}
