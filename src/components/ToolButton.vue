<script setup lang="ts">
import { onBeforeUnmount } from 'nativescript-vue'
import type { EventData, View } from '@nativescript/core'
import { motionScope, type MotionScope } from '@rafaelaugusto/jolt'
withDefaults(defineProps<{ icon: string; label: string; ink?: string; background?: string }>(), { ink: '#262620', background: '#EBE9E1' })
const emit = defineEmits<{ tap: [] }>()
let scope: MotionScope | undefined
function loaded(event: EventData) { scope?.dispose(); scope = motionScope(); scope.press(event.object as View, { scale: .9 }) }
onBeforeUnmount(() => scope?.dispose())
</script>
<template>
  <GridLayout width="44" height="44" borderRadius="22" iosIgnoreSafeArea="true" :backgroundColor="background" @loaded="loaded" @tap="emit('tap')" accessible="true" accessibilityRole="button" :accessibilityLabel="label" :automationText="label">
    <InkIcon :name="icon" :ink="ink" width="20" height="20" />
  </GridLayout>
</template>
