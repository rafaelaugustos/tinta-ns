import { AbsoluteLayout, Application, GridLayout, View } from '@nativescript/core'
import { GestureSurface } from '@rafaelaugusto/jolt/gestures'
import type { InputMode } from '../domain/studio'
import { InkMotion } from './ink-motion'
import { edgeOvershoot } from '../domain/flow'

class PaperView extends View {
  override createNativeView() { return TintaCanvas.alloc().initWithFrame(CGRectZero) }
  override disposeNativeView() { (this.nativeViewProtected as TintaCanvas).shutdown(); super.disposeNativeView() }
}

export class InkView extends GestureSurface {
  private readonly content = new AbsoluteLayout()
  private readonly paper = new PaperView()
  private readonly stage = new GridLayout()
  private readonly actor = new GridLayout()
  private readonly finish = new GridLayout()
  private motion?: InkMotion
  private ink = ''
  get canvas() { return this.paper.nativeViewProtected as TintaCanvas }

  constructor() {
    super()
    this.iosIgnoreSafeArea = true
    this.content.iosIgnoreSafeArea = true
    this.paper.iosIgnoreSafeArea = true
    this.stage.iosIgnoreSafeArea = true
    this.actor.iosIgnoreSafeArea = true
    this.finish.iosIgnoreSafeArea = true
    this.paper.isUserInteractionEnabled = false
    this.actor.width = this.actor.height = 30
    this.actor.horizontalAlignment = 'left'; this.actor.verticalAlignment = 'top'
    this.actor.clipToBounds = false
    this.finish.boxShadow = '0 5 10 0 rgba(0,0,0,0.2)'
    this.finish.borderRadius = 15; this.finish.clipToBounds = true
    this.finish.isUserInteractionEnabled = false
    this.actor.addChild(this.finish)
    this.stage.horizontalAlignment = 'left'; this.stage.verticalAlignment = 'top'
    AbsoluteLayout.setLeft(this.stage, -edgeOvershoot)
    AbsoluteLayout.setTop(this.stage, -edgeOvershoot)
    this.stage.isPassThroughParentEnabled = true
    this.stage.addChild(this.actor)
    this.content.addChild(this.paper); this.content.addChild(this.stage)
    this.addChild(this.content)
    this.on('layoutChanged', () => this.prepareMotion())
    this.actor.on('layoutChanged', () => this.prepareMotion())
  }

  private prepareMotion() {
    if (!this.isLoaded || !this.canvas || this.getActualSize().width <= 0 || this.getActualSize().height <= 0) return
    const size = this.getActualSize()
    this.paper.width = size.width; this.paper.height = size.height
    this.stage.width = size.width + edgeOvershoot * 2
    this.stage.height = size.height + edgeOvershoot * 2
    // The surface's first layout event can precede its children's layout.
    const actorSize = this.actor.getActualSize()
    if (actorSize.width !== 30 || actorSize.height !== 30) return
    if (this.motion) { this.motion.resize(); return }
    this.canvas.running = false
    this.motion = new InkMotion(this, this.stage, this.canvas, this.actor, this.finish, () => this.notify({ eventName: 'modeChanged', object: this, mode: 1 }))
    this.ink = ''
    this.notify({ eventName: 'canvasReady', object: this })
  }
  configure(mode: InputMode, running: boolean, interactive: boolean, width: number, ink: string, speed: number) {
    if (!this.motion) return
    this.canvas.brushWidth = width
    if (this.ink !== ink) { this.ink = ink; this.motion.setInk(ink) }
    this.motion.setMode(mode)
    this.motion.setSpeed(speed)
    this.motion.setInteractive(interactive)
    this.motion.setRunning(running)
  }
  tiltAvailable() { return this.motion?.tiltAvailable() ?? false }
  checkTilt() { return this.motion?.checkTilt() }
  override onLoaded() { super.onLoaded(); this.prepareMotion() }
  override onUnloaded() {
    if (!Application.suspended) {
      this.motion?.dispose(); this.motion = undefined
      if (this.canvas) this.canvas.running = false
    }
    super.onUnloaded()
  }
  override disposeNativeView() {
    this.motion?.dispose(); this.motion = undefined
    super.disposeNativeView()
  }
}
