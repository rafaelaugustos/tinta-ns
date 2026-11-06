import { Color, View } from '@nativescript/core'

export class InkView extends View {
  get canvas() { return this.nativeViewProtected as TintaCanvas }
  override createNativeView() { return TintaCanvas.alloc().initWithFrame(CGRectZero) }
  override onLoaded() {
    super.onLoaded()
    this.canvas.running = false
    this.canvas.modeChanged = mode => this.notify({ eventName: 'modeChanged', object: this, mode })
    this.notify({ eventName: 'canvasReady', object: this })
  }
  setInk(color: string) { this.canvas.inkColor = new Color(color).ios }
  override disposeNativeView() { this.canvas.shutdown(); super.disposeNativeView() }
}
