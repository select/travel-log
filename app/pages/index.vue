<template>
  <div class="relative flex flex-col h-screen h-dvh font-['Outfit',system-ui,sans-serif] overflow-hidden bg-[#e0e5ec]">
    <HeaderBar :stats="trackInfo" />
    <MapView @stats="trackInfo = $event" />
  </div>
</template>

<script setup lang="ts">
const trackInfo = ref<{ distance?: string; elevation?: string; duration?: string } | null>(null)
</script>
