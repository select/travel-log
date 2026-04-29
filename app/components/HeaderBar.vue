<template>
  <header class="absolute top-4 left-4 right-4 z-[1000] flex items-center justify-between px-4 py-2 bg-[#0f0f14] backdrop-blur-xl rounded-xl shadow-[0_4px_24px_rgba(0,0,0,0.5)] border border-white/[0.08]">
    <h1 class="font-['Fraunces'] text-xl font-bold leading-tight m-0 flex items-baseline gap-0">
      <span class="text-white bg-black px-1 not-italic">Travel</span><span class="text-[#e8a020] italic font-light">log</span>
    </h1>
    <div v-if="stats?.distance" class="font-sans text-sm text-white/50">
      📏 {{ stats.distance }}
    </div>
  </header>
</template>

<script setup lang="ts">
defineProps<{
  stats?: { distance?: string; elevation?: string; duration?: string } | null
}>()
</script>
