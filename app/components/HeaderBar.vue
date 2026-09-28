<template>
  <header class="absolute top-4 left-4 right-4 z-[1000] flex items-center justify-between px-4 py-2 bg-[#0f0f14] backdrop-blur-xl rounded-xl shadow-[0_4px_24px_rgba(0,0,0,0.5)] border border-white/[0.08]">
    <h1 class="font-['Fraunces'] text-xl font-bold leading-tight m-0 flex items-baseline gap-0">
      <span class="text-white bg-black px-1 not-italic">Travel</span><span class="text-[#e8a020] italic font-light">log</span>
    </h1>
    <div class="flex items-center gap-3 min-w-0">
      <label for="tour-select" class="sr-only">Tour</label>
      <select
        id="tour-select"
        :value="tourId || ''"
        class="min-w-0 max-w-[45vw] rounded-lg border border-white/20 bg-[#0f0f14] px-2 py-1 text-sm text-white"
        @change="$emit('select-tour', ($event.target as HTMLSelectElement).value)"
      >
        <option v-for="tour in tours" :key="tour.id" :value="tour.id">{{ tour.name }}</option>
      </select>
      <div v-if="stats?.distance" class="hidden sm:block font-sans text-sm text-white/50 whitespace-nowrap">
        📏 {{ stats.distance }}
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
defineProps<{
  stats?: { distance?: string; elevation?: string; duration?: string } | null
  tours: { id: string; name: string }[]
  tourId: string | null
}>()

defineEmits<{ 'select-tour': [id: string] }>()
</script>
