<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref } from 'nativescript-vue'
import { Application } from '@nativescript/core'

const props = defineProps<{ read: () => { fps: number, rss: number } }>()
const fps = ref('0.0'), rss = ref('—')
let timer: ReturnType<typeof setInterval> | undefined
function sample() {
  const value = props.read()
  fps.value = value.fps.toFixed(1)
  rss.value = value.rss >= 0 ? `${value.rss.toFixed(1)} MiB` : '—'
}
function stop() { clearInterval(timer); timer = undefined }
function start() { stop(); sample(); timer = setInterval(sample, 1000) }
onMounted(() => {
  start()
  Application.on(Application.suspendEvent, stop)
  Application.on(Application.resumeEvent, start)
})
onBeforeUnmount(() => {
  stop()
  Application.off(Application.suspendEvent, stop)
  Application.off(Application.resumeEvent, start)
})
</script>

<template>
  <GridLayout columns="*,*" rows="22,12">
    <Label :text="fps" fontSize="18" fontWeight="600" color="#45473F" />
    <Label row="1" text="UI callback FPS" fontSize="9" color="#8A8C7F" />
    <Label col="1" :text="rss" fontSize="18" fontWeight="600" color="#45473F" />
    <Label col="1" row="1" text="RAM · process RSS" fontSize="9" color="#8A8C7F" />
  </GridLayout>
</template>
