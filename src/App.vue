<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref, watch } from 'nativescript-vue'
import { ApplicationSettings, knownFolders, type EventData, type GridLayout, type View } from '@nativescript/core'
import { motionScope, onReducedMotion, reducedMotion } from '@rafaelaugusto/jolt'
import type { InkView } from './canvas/ink-view'
import { inks, modes, type InputMode, type ProbeResult } from './domain/studio'
import { readProbeResult } from './domain/probe'
import { useTilt } from './composables/useTilt'
import ToolButton from './components/ToolButton.vue'
import Opening from './components/Opening.vue'
import RenderLab from './components/RenderLab.vue'
import PerformanceReadout from './components/PerformanceReadout.vue'

const width = ref(402), height = ref(790)
const opening = ref(true), playing = ref(!reducedMotion()), lab = ref(false), busy = ref(false)
const selectedInk = ref(Math.max(0, Math.min(3, ApplicationSettings.getNumber('tinta.ink', 0))))
const brush = ref(3.2), mode = ref<InputMode>('flow'), hint = ref('Let it wander. Or make your own mark.')
const progress = ref(0), phase = ref('Ready'), result = ref<ProbeResult | null>(null)
const canvasTop = 130
const canvasHeight = computed(() => Math.max(200, height.value - 350))
const toolsTop = computed(() => canvasTop + canvasHeight.value + 18)
const motion = motionScope()
let ink: InkView | undefined, root: GridLayout | undefined
let hintTimer: ReturnType<typeof setTimeout> | undefined
let autoProbe: ReturnType<typeof setTimeout> | undefined
const tilt = useTilt((x, y) => ink?.canvas.setGravityXY(x, y))
function layout(event: EventData) {
  root = event.object as GridLayout
  const size = root.getActualSize()
  if (size.width > 0 && size.height > 0) { width.value = Math.min(size.width, 560); height.value = size.height }
}
function sync() {
  if (!ink) return
  ink.canvas.mode = modes.indexOf(mode.value)
  ink.canvas.brushWidth = brush.value
  ink.canvas.running = playing.value && !opening.value && !lab.value && !busy.value
  ink.setInk(inks[selectedInk.value]!.color)
}
function readPerformance() {
  return { fps: ink?.canvas.callbackFPS ?? 0, rss: ink?.canvas.processRSSMiB ?? -1 }
}
function ready(event: EventData) { ink = event.object as InkView; sync() }
async function enter() {
  if (!opening.value) return
  opening.value = false
  await nextTick()
  if (root) {
    const target = (id: string) => root!.getViewById<View>(id)
    motion.timeline([
      [target('studio-header'), { opacity: [0, 1], y: reducedMotion() ? 0 : [-8, 0] }, { at: 0, duration: 450 }],
      [target('paper'), { opacity: [0, 1], scale: reducedMotion() ? 1 : [.96, 1] }, { at: 100, type: 'spring', duration: 800, bounce: .04 }],
      [target('tools'), { opacity: [0, 1], y: reducedMotion() ? 0 : [20, 0] }, { at: 250, type: 'spring', duration: 650, bounce: .08 }],
    ])
  }
  sync()
  if (NSProcessInfo.processInfo.arguments.containsObject('--tinta-probe')) autoProbe = setTimeout(runProbe, 2500)
  if (NSProcessInfo.processInfo.arguments.containsObject('--tinta-cadence')) autoProbe = setTimeout(() => ink?.canvas.beginCapture(), 3000)
}
function message(text: string) {
  clearTimeout(hintTimer); hint.value = text
  hintTimer = setTimeout(() => { hint.value = 'Let it wander. Or make your own mark.' }, 3500)
}
function chooseMode(value: InputMode) {
  if (value === 'tilt' && !tilt.start()) { message('Tilt needs a device. Try Touch or Flow here.'); return }
  if (value !== 'tilt') tilt.stop()
  mode.value = value; playing.value = true
}
function fromCanvas(event: EventData & { mode: number }) { mode.value = modes[event.mode]!; playing.value = true; tilt.stop() }
function chooseInk(index: number) { selectedInk.value = index; ApplicationSettings.setNumber('tinta.ink', index) }
function undo() { playing.value = false; message(ink?.canvas.undo() ? 'One step back.' : 'Draw a stroke or clear the paper first.') }
function clear() { ink?.canvas.clearPaper(); message('A fresh sheet.') }
function share() {
  const path = ink?.canvas.exportPNG()
  if (!path) { message('Could not export this sheet.'); return }
  const controller = UIActivityViewController.alloc().initWithActivityItemsApplicationActivities([NSURL.fileURLWithPath(path)], null)
  const host = root?.page?.ios as UIViewController | undefined
  if (!host) return
  if (controller.popoverPresentationController) {
    controller.popoverPresentationController.sourceView = host.view
    controller.popoverPresentationController.sourceRect = CGRectMake(width.value/2, height.value-60, 1, 1)
  }
  host.presentViewControllerAnimatedCompletion(controller, true, () => {})
}
function runProbe() {
  if (busy.value) return
  lab.value = true; busy.value = true; result.value = null; progress.value = 0; phase.value = 'Warming up'; tilt.stop(); sync()
  const directory = `${knownFolders.documents().path}/benchmarks`
  TintaRenderProbe.runInDirectoryProgressCompletion(directory, (frame, state) => {
    progress.value = frame; phase.value = state
  }, json => {
    try { result.value = readProbeResult(json) } catch (error) { message(error instanceof Error ? error.message : 'Could not read the render report.') }
    busy.value = false; progress.value = 450; sync()
  })
}
motion.use(() => onReducedMotion(value => { if (value) playing.value = false }))
watch([mode, playing, opening, lab, busy, brush, selectedInk], sync)
onBeforeUnmount(() => { clearTimeout(hintTimer); clearTimeout(autoProbe); motion.dispose() })
</script>

<template>
  <Page actionBarHidden="true" backgroundColor="#F4F1E9" statusBarStyle="dark">
    <GridLayout iosOverflowSafeArea="false" iosOverflowSafeAreaEnabled="false" @loaded="layout" @layoutChanged="layout" backgroundColor="#F4F1E9" clipToBounds="true">
      <AbsoluteLayout :width="width" :height="height">
        <GridLayout id="studio-header" left="24" top="10" :width="width-48" height="80" columns="*,44">
          <StackLayout>
            <Label text="tinta." fontSize="43" fontWeight="800" letterSpacing="-0.06" />
            <Label text="INK, IN MOTION" fontSize="9" color="#8A8C7F" letterSpacing="0.16" />
          </StackLayout>
          <ToolButton col="1" icon="lab" label="Open render lab" @tap="lab = true" verticalAlignment="center" />
        </GridLayout>
        <PerformanceReadout left="26" top="86" :width="width-52" height="38" :read="readPerformance" />
        <GridLayout id="paper" left="18" :top="canvasTop" :width="width-36" :height="canvasHeight" borderRadius="24" borderWidth="1" borderColor="#E2DED1" clipToBounds="true" backgroundColor="#F9F7F1">
          <InkView @canvasReady="ready" @modeChanged="fromCanvas" />
        </GridLayout>
        <GridLayout id="tools" left="24" :top="toolsTop" :width="width-48" height="162" rows="48,70,44">
          <GridLayout columns="*,126" rows="48">
            <StackLayout orientation="horizontal" verticalAlignment="center">
              <GridLayout v-for="(item,index) in inks" :key="item.name" width="36" height="36" marginRight="6" borderRadius="18" :borderWidth="selectedInk===index ? 1.5 : 0" :borderColor="item.color" padding="5" @tap="chooseInk(index)" accessible="true" accessibilityRole="button" :accessibilityLabel="item.name">
                <GridLayout :backgroundColor="item.color" borderRadius="14" />
              </GridLayout>
            </StackLayout>
            <GridLayout col="1" columns="*,*,*" height="34" borderRadius="17" backgroundColor="#EAE8DF" verticalAlignment="center" padding="3">
              <GridLayout v-for="(value,index) in [1.5,3.2,7]" :key="value" :col="index" borderRadius="14" :backgroundColor="brush===value ? '#FDFCF8' : 'transparent'" @tap="brush=value" accessible="true" accessibilityRole="button" :accessibilityLabel="['Fine ink','Medium ink','Bold ink'][index]">
                <GridLayout :width="index*3+3" :height="index*3+3" borderRadius="5" backgroundColor="#45473F" />
              </GridLayout>
            </GridLayout>
          </GridLayout>
          <GridLayout row="1" columns="*,44" rows="62" marginTop="8">
            <GridLayout columns="*,*,*" rows="38" height="46" backgroundColor="#EAE8DF" borderRadius="23" padding="4" marginRight="12" verticalAlignment="center">
              <GridLayout v-for="(item,index) in modes" :key="item" :col="index" borderRadius="20" :backgroundColor="mode===item ? '#273AE8' : 'transparent'" @tap="chooseMode(item)" accessible="true" accessibilityRole="button" :accessibilityLabel="item+' mode'">
                <Label :text="item[0]!.toUpperCase()+item.slice(1)" fontSize="12" fontWeight="600" :color="mode===item ? 'white' : '#787B6F'" textAlignment="center" verticalAlignment="center" />
              </GridLayout>
            </GridLayout>
            <ToolButton col="1" :icon="playing ? 'pause' : 'play'" :label="playing ? 'Pause ink' : 'Resume ink'" @tap="playing = !playing" verticalAlignment="center" />
          </GridLayout>
          <GridLayout row="2" columns="*,44,44,44" rows="44">
            <Label :text="inks[selectedInk]!.name" fontSize="11" color="#8A8C7F" verticalAlignment="center" />
            <ToolButton col="1" icon="undo" label="Undo last stroke" background="transparent" @tap="undo" />
            <ToolButton col="2" icon="clear" label="Clear paper" background="transparent" @tap="clear" />
            <ToolButton col="3" icon="share" label="Export drawing" background="transparent" @tap="share" />
          </GridLayout>
        </GridLayout>
        <Label left="24" :top="height-28" :width="width-48" height="18" :text="hint" textAlignment="center" fontSize="10" color="#96988C" />
        <Opening v-if="opening" left="0" top="0" :width="width" :height="height" @finished="enter" />
        <RenderLab v-if="lab" left="0" top="0" :width="width" :height="height" :busy="busy" :frame="progress" :phase="phase" :result="result" @close="lab=false" @run="runProbe" />
      </AbsoluteLayout>
    </GridLayout>
  </Page>
</template>
