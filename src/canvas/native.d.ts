declare class TintaCanvas extends UIView {
  static alloc(): TintaCanvas
  initWithFrame(frame: CGRect): this
  mode: number
  running: boolean
  brushWidth: number
  readonly callbackFPS: number
  readonly processRSSMiB: number
  inkColor: UIColor
  trackedView: UIView | null
  readonly currentPoint: CGPoint
  resetTracking(): void
  saveUndo(): void
  clearPaper(): void
  undo(): boolean
  exportPNG(): string
  beginCapture(): void
  shutdown(): void
}
declare class TintaRenderProbe extends NSObject {
  static runInDirectoryProgressCompletion(directory: string, progress: (frame: number, phase: string) => void, completion: (json: string) => void): void
}

declare class TintaContactObserver extends UIGestureRecognizer {
  static attachToViewContact(view: UIView, contact: (x: number, y: number) => void): TintaContactObserver
  dispose(): void
}
