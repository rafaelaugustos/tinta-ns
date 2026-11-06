import { GridLayout, Property } from '@nativescript/core'
import { shape, type Shape } from '@rafaelaugusto/jolt/shapes'

const paths: Record<string, string> = {
  pause: 'M8 5 L8 19 M16 5 L16 19',
  play: 'M8 5 L19 12 L8 19 Z',
  undo: 'M8 5 L3 10 L8 15 M3 10 L14 10 C22 10 22 21 14 21',
  clear: 'M4 7 L20 7 M9 7 L9 4 L15 4 L15 7 M6 7 L7 21 L17 21 L18 7 M10 11 L10 17 M14 11 L14 17',
  share: 'M12 16 L12 2 M7 7 L12 2 L17 7 M5 12 L5 21 L19 21 L19 12',
  close: 'M6 6 L18 18 M18 6 L6 18',
  lab: 'M9 3 L15 3 M10 3 L10 10 L4 19 Q3 22 7 22 L17 22 Q21 22 20 19 L14 10 L14 3 M7 16 L17 16',
  arrow: 'M4 12 L20 12 M14 6 L20 12 L14 18',
  expand: 'M9 3 L3 3 L3 9 M15 3 L21 3 L21 9 M3 15 L3 21 L9 21 M15 21 L21 21 L21 15',
  controls: 'M4 7 L8 7 M12 7 L20 7 M4 17 L14 17 M18 17 L20 17 M10 4 L10 10 M16 14 L16 20',
}
export class InkIcon extends GridLayout {
  declare name: string
  declare ink: string
  private drawing?: Shape
  constructor() { super(); this.isUserInteractionEnabled = false; this.accessibilityHidden = true }
  override onLoaded() { super.onLoaded(); this.draw() }
  draw() {
    if (!this.isLoaded) return
    this.drawing?.dispose()
    this.drawing = shape(this, { viewBox: [0, 0, 24, 24], d: paths[this.name] ?? paths.play!, fill: 'transparent', stroke: this.ink, strokeWidth: 1.7, lineCap: 'round', lineJoin: 'round' })
  }
  override onUnloaded() { this.drawing?.dispose(); this.drawing = undefined; super.onUnloaded() }
}
new Property<InkIcon,string>({ name: 'name', defaultValue: 'play', valueChanged: target => target.draw() }).register(InkIcon)
new Property<InkIcon,string>({ name: 'ink', defaultValue: '#23241F', valueChanged: target => target.draw() }).register(InkIcon)
