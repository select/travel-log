<template>
  <div class="relative flex flex-col h-screen h-dvh font-['Outfit',system-ui,sans-serif] overflow-hidden bg-[#e0e5ec]">
    <HeaderBar :stats="trackInfo" :tours="tours" :tour-id="tourId" @select-tour="selectTour" />
    <MapView v-if="tourId" :key="tourId" :tour-id="tourId" @stats="trackInfo = $event" />
    <div v-else class="flex-1 flex items-center justify-center text-gray-600">{{ error || 'Loading tours…' }}</div>
  </div>
</template>

<script setup lang="ts">
interface Tour { id: string; name: string }

const route = useRoute()
const router = useRouter()
const tours = ref<Tour[]>([])
const tourId = ref<string | null>(null)
const error = ref('')
const trackInfo = ref<{ distance?: string; elevation?: string; duration?: string } | null>(null)

onMounted(async () => {
  try {
    const base = useRuntimeConfig().app.baseURL || '/'
    const response = await fetch(`${base}tours.json`)
    if (!response.ok) throw new Error(`HTTP ${response.status}`)
    const data = await response.json()
    tours.value = data.tours
    if (!tours.value.length) throw new Error('No tours configured')
    const requested = route.query.tour
    tourId.value = tours.value.find(t => t.id === requested)?.id || tours.value[0]!.id
  } catch (e) {
    console.error('Failed to load tours:', e)
    error.value = 'Could not load tours.'
  }
})

watch(() => route.query.tour, (requested) => {
  if (tours.value.length) {
    trackInfo.value = null
    tourId.value = tours.value.find(t => t.id === requested)?.id || tours.value[0]!.id
  }
})

function selectTour(id: string) {
  if (!tours.value.some(t => t.id === id)) return
  trackInfo.value = null
  tourId.value = id
  router.replace({ query: { ...route.query, tour: id } })
}
</script>
