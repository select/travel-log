<template>
  <div class="w-full flex-1 min-h-0 relative">
    <div ref="mapContainer" class="w-full h-full" style="touch-action: none;" />
    <PhotoOverlay
      v-if="selectedPhotoIndex !== null"
      :photos="photosData"
      :initial-index="selectedPhotoIndex"
      @close="selectedPhotoIndex = null"
    />
  </div>
</template>

<script setup lang="ts">
import 'leaflet/dist/leaflet.css'

interface PhotoPoint {
  file: string
  lat: string
  lon: string
  x?: number
  y?: number
}

const props = defineProps<{
  gpxUrl?: string
}>()

const photos = ref<PhotoPoint[]>([])
const photosData = ref<PhotoPoint[]>([])
const selectedPhotoIndex = ref<number | null>(null)

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
  const map = L.map(mapContainer.value!, { 
    center: [52.44, 13.43], 
    zoom: 13,
    zoomControl: false
  })
  
  L.control.zoom({ position: 'bottomleft' }).addTo(map)

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
  
  // Load photos and add as Leaflet markers
  try {
    const photosRes = await fetch(`${baseUrl}images.json`)
    const fetchedPhotos = await photosRes.json()
    photosData.value = fetchedPhotos
    
    fetchedPhotos.forEach((photo: PhotoPoint, index: number) => {
      const lat = parseGeoCoord(photo.lat)
      const lon = parseGeoCoord(photo.lon)
      
      // Speech bubble HTML - 40px circle with triangle like speech bubble (triangle points towards image)
      // All on RIGHT side: triangle points left (O>), image on right
      const bubbleHtml = `
        <div style="display: flex; align-items: center; gap: 0;">
          <div style="
            width: 0; 
            height: 0; 
            border-top: 6px solid transparent;
            border-bottom: 6px solid transparent;
            border-right: 8px solid white;
            flex-shrink: 0;
          "></div>
          <div style="
            width: 40px; 
            height: 40px; 
            border-radius: 50%;
            overflow: hidden;
            border: 2px solid white;
            box-shadow: 0 2px 6px rgba(0,0,0,0.3);
            flex-shrink: 0;
          ">
            <img src="${baseUrl}thumbnails/${photo.file}" style="width: 100%; height: 100%; object-fit: cover;" loading="lazy" />
          </div>
        </div>
      `
      
      const icon = L.divIcon({
        html: bubbleHtml,
        className: 'photo-marker cursor-pointer',
        iconSize: [48, 40],
        iconAnchor: [0, 20] // Tip of triangle at geo coord
      })
      
      L.marker([lat, lon], { icon, interactive: true }).on('click', () => {
        selectedPhotoIndex.value = index
      }).addTo(map)
    })
  } catch (e) {
    console.error('Photos load error:', e)
  }
})

function parseGeoCoord(coord: string): number {
  const match = coord.match(/(\d+)\s*deg\s*(\d+)'\s*([\d.]+)"\s*([NSEW])/)
  if (!match) return 0
  const [, deg, min, sec, dir] = match
  let value = parseFloat(deg) + parseFloat(min) / 60 + parseFloat(sec) / 3600
  if (dir === 'S' || dir === 'W') value *= -1
  return value
}
</script>

<style>
.photo-marker {
  background: transparent !important;
  border: none !important;
  cursor: pointer !important;
}
.photo-marker img {
  cursor: pointer !important;
}
</style>
