<script setup lang="ts">
import { onBeforeUnmount } from 'nativescript-vue'
import type { EventData, GridLayout, View } from '@nativescript/core'
import { motionScope, reducedMotion, type MotionScope } from '@rafaelaugusto/jolt'
import type { ProbeResult } from '../domain/studio'
import ToolButton from './ToolButton.vue'
const props = defineProps<{ width: number; height: number; busy: boolean; frame: number; phase: string; result: ProbeResult | null }>()
const emit = defineEmits<{ close: []; run: [] }>()
let scope: MotionScope | undefined
function loaded(event: EventData) {
  const root = event.object as GridLayout
  scope = motionScope()
  scope.animate(root.getViewById<View>('lab-panel'), { opacity: [0, 1], y: reducedMotion() ? 0 : [50, 0] }, { type: 'spring', duration: 550, bounce: .06 })
}
onBeforeUnmount(() => scope?.dispose())
const signed = (value: number) => `${value >= 0 ? '+' : ''}${value.toFixed(2)}`
</script>
<template>
  <GridLayout :width="width" :height="height" backgroundColor="rgba(28,30,24,.28)" @loaded="loaded">
    <GridLayout id="lab-panel" verticalAlignment="bottom" rows="54,42,60,90,48,54,56,36" padding="24" borderRadius="30 30 0 0" backgroundColor="#F4F1E9">
      <GridLayout columns="*,44">
        <Label text="Render lab" fontSize="28" fontWeight="700" letterSpacing="-0.035" verticalAlignment="center" />
        <ToolButton col="1" icon="close" label="Close render lab" @tap="emit('close')" />
      </GridLayout>
      <Label row="1" text="A small test. Real allocations." color="#77796C" fontSize="13" verticalAlignment="center" />
      <Label row="2" text="450 offscreen renders. A moving rectangle, uploaded pixels and a Gaussian blur. Each result is read back; pixels are checked." fontSize="13" textWrap="true" lineHeight="3" color="#505349" />
      <GridLayout row="3" columns="*,*" backgroundColor="#EAE8DF" borderRadius="16" padding="14">
        <StackLayout>
          <Label :text="result ? signed(result.growthMiB) : '—'" fontSize="28" fontWeight="600" color="#273AE8" />
          <Label text="MiB · settled RSS change" fontSize="10" color="#74776B" />
        </StackLayout>
        <StackLayout col="1" paddingLeft="12">
          <Label :text="busy ? `${frame} / 450` : result ? (result.pixelsValid ? 'Verified' : 'Failed') : '512 × 512'" fontSize="22" fontWeight="600" />
          <Label :text="busy ? phase : result ? 'pixel assertions' : 'pixels · blur radius 4'" fontSize="10" color="#74776B" />
        </StackLayout>
      </GridLayout>
      <GridLayout row="4" verticalAlignment="center" height="4" borderRadius="2" backgroundColor="#DEDED5">
        <GridLayout horizontalAlignment="left" :width="(width-48) * frame / 450" height="4" borderRadius="2" backgroundColor="#273AE8" />
      </GridLayout>
      <Label row="5" :text="result?.error || 'Core Image workload, separate from the drawing canvas. Process RSS includes the whole app. This is not a tgfx comparison or a GPU FPS measurement.'" textWrap="true" fontSize="11" color="#77796C" lineHeight="2" />
      <GridLayout row="6" borderRadius="28" :backgroundColor="busy ? '#C6C7DC' : '#273AE8'" @tap="!busy && emit('run')" accessible="true" accessibilityRole="button" accessibilityLabel="Run 450 render test" automationText="Run 450 render test">
        <Label :text="busy ? 'Measuring · about 75 seconds' : result ? 'Run again' : 'Run memory test'" fontSize="14" fontWeight="600" color="white" textAlignment="center" verticalAlignment="center" />
      </GridLayout>
      <Label row="7" text="The JSON report is saved on this device." fontSize="10" color="#87897F" textAlignment="center" verticalAlignment="center" />
    </GridLayout>
  </GridLayout>
</template>
