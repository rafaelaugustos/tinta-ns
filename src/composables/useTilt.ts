import { ref, onBeforeUnmount } from 'nativescript-vue'
import { motionScope } from '@rafaelaugusto/jolt'
import { sensor, type GravitySensor } from '@rafaelaugusto/jolt/sensors'

export function useTilt(deliver: (x: number, y: number) => void) {
  const available = ref(true)
  let gravity: GravitySensor | undefined
  const scope = motionScope()
  function start() {
    if (!gravity) {
      gravity = sensor('gravity', { interval: 32, scope, reducedMotion: 'continue', onStatus: status => { available.value = status !== 'unavailable' && status !== 'error' } })
      scope.use(() => {
        let previous = -Infinity
        return gravity!.x.subscribe((x, time) => {
          if (time - previous < 32) return
          previous = time
          deliver(x, gravity!.y.get())
        })
      })
    } else gravity.play()
    available.value = gravity.available
    return available.value
  }
  function stop() { gravity?.pause(); deliver(0, 0) }
  onBeforeUnmount(() => scope.dispose())
  return { available, start, stop }
}
