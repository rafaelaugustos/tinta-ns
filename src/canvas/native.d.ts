declare class TintaCanvas extends UIView {
  static alloc(): TintaCanvas
  initWithFrame(frame: CGRect): this
  mode: number
  running: boolean
  brushWidth: number
  inkColor: UIColor
  modeChanged: ((mode: number) => void) | null
  setGravityXY(x: number, y: number): void
  clearPaper(): void
  undo(): boolean
  exportPNG(): string
  beginCapture(): void
  shutdown(): void
}
declare class TintaRenderProbe extends NSObject {
  static runInDirectoryProgressCompletion(directory: string, progress: (frame: number, phase: string) => void, completion: (json: string) => void): void
}
