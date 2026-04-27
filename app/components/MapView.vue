<template>
  <div class="w-full flex-1 min-h-0">
    <div ref="mapContainer" class="w-full h-full" />
  </div>
</template>

<script setup lang="ts">
import 'leaflet/dist/leaflet.css'

const props = defineProps<{
  gpxUrl?: string
}>()

const tracks = [
  { gpxUrl: `2026-part-1.gpx`, color: '#3b82f6' },
  { gpxUrl: `2026-part-2.gpx`, color: '#ef4444' },
]

const emit = defineEmits<{
  stats: [data: { distance?: string; elevation?: string; duration?: string }]
}>()

const mapContainer = ref<HTMLElement | null>(null)

onMounted(async () => {
  await nextTick()
  
  const L = (await import('leaflet')).default
  const map = L.map(mapContainer.value!, { center: [52.44, 13.43], zoom: 13 })

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map)

  const config = useRuntimeConfig()
  const baseUrl = config.app.baseURL || ''
  
  const allLatLngs: [number, number][][] = []
  const allElevations: number[][] = []
  
  for (const track of tracks) {
    try {
      const response = await fetch(`${baseUrl}${track.gpxUrl}`)
      const gpxText = await response.text()
      
      const parser = new DOMParser()
      const gpxDoc = parser.parseFromString(gpxText, 'application/xml')
      const trkpts = gpxDoc.querySelectorAll('trkpt')
      
      const latlngs: [number, number][] = []
      const elevations: number[] = []
      
      trkpts.forEach((pt) => {
        const lat = parseFloat(pt.getAttribute('lat') || '0')
        const lon = parseFloat(pt.getAttribute('lon') || '0')
        const eleEl = pt.querySelector('ele')
        const ele = eleEl ? parseFloat(eleEl.textContent || '0') : 0
        
        latlngs.push([lat, lon])
        elevations.push(ele)
      })
      
      if (latlngs.length > 0) {
        const polyline = L.polyline(latlngs, { color: track.color, weight: 4, opacity: 0.85 })
        polyline.addTo(map)
        allLatLngs.push(latlngs)
        allElevations.push(elevations)
      }
      
    } catch (e) {
      console.error('GPX parse error:', e)
    }
  }
  
  if (allLatLngs.length > 0) {
    let totalDist = 0
    for (const latlngs of allLatLngs) {
      for (let i = 1; i < latlngs.length; i++) {
        totalDist += map.distance(latlngs[i-1], latlngs[i])
      }
    }
    
    const allEle = allElevations.flat()
    const minEle = Math.min(...allEle)
    const maxEle = Math.max(...allEle)
    
    const stats = {
      distance: `${(totalDist / 1000).toFixed(1)} km`,
      elevation: `${Math.round(minEle)}m – ${Math.round(maxEle)}m`,
    }
    
    emit('stats', stats)
  }
  
  if (allLatLngs.length > 0) {
    const allPoints = allLatLngs.flat()
    map.fitBounds(L.latLngBounds(allPoints))
  }
})
</script>
