<template>
  <header class="absolute top-4 left-4 right-4 z-1000 flex items-center justify-between gap-4 px-5 py-2.5 bg-[rgba(224,_229,_236,_0.85)] backdrop-blur-xl rounded-2xl shadow-[6px_6px_12px_rgba(163,_168,_178,_0.5),-6px_-6px_12px_rgba(255,_255,_255,_0.8)]">
    <h1 class="text-base font-bold bg-gradient-to-r from-violet-600 to-purple-600 bg-clip-text text-transparent">Travel Log</h1>
    <div v-if="stats" class="flex gap-4 text-xs font-medium text-slate-600">
      <span v-if="stats.distance">📏 {{ stats.distance }}</span>
      <span v-if="stats.elevation">⛰ {{ stats.elevation }}</span>
    </div>
  </header>
</template>

<script setup lang="ts">
defineProps<{
  stats?: { distance?: string; elevation?: string; duration?: string } | null
}>()
</script>
