<script setup lang="ts">
import { onBeforeUnmount } from 'nativescript-vue'
import type { EventData, GridLayout, View } from '@nativescript/core'
import { motionScope, reducedMotion, type MotionScope } from '@rafaelaugusto/jolt'
const emit = defineEmits<{ finished: [] }>()
let scope: MotionScope | undefined
let done = false
function finish() { if (!done) { done = true; emit('finished') } }
function loaded(event: EventData) {
  const root = event.object as GridLayout, view = (id: string) => root.getViewById<View>(id)
  scope = motionScope()
  const sequence = scope.timeline([
    [view('art'), { opacity: [0, 1], scale: reducedMotion() ? 1 : [.85, 1] }, { at: 0, type: 'spring', duration: 1100, bounce: .08 }],
    [view('word'), { opacity: [0, 1], y: reducedMotion() ? 0 : [18, 0] }, { at: 230, duration: 650, ease: 'easeOut' }],
    [view('caption'), { opacity: [0, 1] }, { at: 600, duration: 650 }],
    [view('enter'), { opacity: [0, 1], y: reducedMotion() ? 0 : [10, 0] }, { at: 950, duration: 450 }],
    [view('art'), { opacity: [1, 1] }, { at: 2350, duration: 450 }],
  ])
  sequence.finished.then(finish)
}
onBeforeUnmount(() => { done = true; scope?.dispose() })
</script>
<template>
  <GridLayout rows="*,300,90,60,*,60,32" backgroundColor="#F4F1E9" padding="28" @loaded="loaded">
    <Image row="1" id="art" src="~/assets/tinta-icon.png" width="300" height="300" stretch="aspectFit" opacity="0" />
    <Label row="2" id="word" text="tinta." textAlignment="center" fontSize="72" fontWeight="800" letterSpacing="-0.06" color="#24251F" opacity="0" />
    <Label row="3" id="caption" text="INK, IN MOTION." textAlignment="center" fontSize="11" letterSpacing="0.22" color="#77796C" opacity="0" />
    <GridLayout row="5" id="enter" columns="*,24" backgroundColor="#273AE8" borderRadius="28" padding="0 24" @tap="finish" opacity="0" accessible="true" accessibilityRole="button" accessibilityLabel="Open studio">
      <Label text="Open studio" fontSize="15" fontWeight="600" color="white" verticalAlignment="center" />
      <InkIcon col="1" name="arrow" ink="white" width="22" height="22" />
    </GridLayout>
  </GridLayout>
</template>
