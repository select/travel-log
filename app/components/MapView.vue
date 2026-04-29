<template>
  <div class="w-full flex-1 min-h-0 relative">
    <div ref="mapContainer" class="w-full h-full" style="touch-action: none;" />
    <PhotoOverlay
      v-if="selectedPhotoIndex !== null"
      :photos="photosData"
      :initial-index="selectedPhotoIndex"
      @close="selectedPhotoIndex = null"
    />
    
    <!-- Controls panel -->
    <div class="absolute bottom-20 left-4 z-[1000] flex flex-col gap-2">
      <button
        @click="showThumbs = !showThumbs"
        class="w-10 h-10 rounded-lg bg-[#0f0f14] border border-white/[0.08] flex items-center justify-center text-white shadow-lg hover:bg-white/10 transition-colors"
        :title="showThumbs ? 'Hide thumbnails' : 'Show thumbnails'"
      >
        <span :class="showThumbs ? 'i-mdi:image' : 'i-mdi:image-off'" class="text-xl" />
      </button>
      <button
        @click="showStats = !showStats"
        class="w-10 h-10 rounded-lg bg-[#0f0f14] border border-white/[0.08] flex items-center justify-center text-white shadow-lg hover:bg-white/10 transition-colors"
        :title="showStats ? 'Hide stats' : 'Show stats'"
      >
        <span :class="showStats ? 'i-mdi:chart-line' : 'i-mdi:chart-line-variant'" class="text-xl" />
      </button>
    </div>
    
    <!-- Track stats panel -->
    <div v-if="showStats && trackStats.length > 0" class="absolute bottom-20 left-16 z-[1000] bg-[#0f0f14]/95 backdrop-blur-xl rounded-xl border border-white/[0.08] shadow-lg p-3 max-w-[200px]">
      <div class="text-xs text-white/50 mb-2 uppercase tracking-wide">Tracks</div>
      <div v-for="stat in trackStats" :key="stat.name" class="mb-2 last:mb-0">
        <div class="text-sm font-medium" :style="{ color: stat.color }">{{ stat.name }}</div>
        <div class="text-xs text-white/70 space-y-0.5">
          <div v-if="stat.distance">{{ stat.distance }}</div>
          <div v-if="stat.maxSpeed">Max: {{ stat.maxSpeed }}</div>
          <div v-if="stat.ascent">↑ {{ stat.ascent }}</div>
          <div v-if="stat.movingTime">Moving: {{ stat.movingTime }}</div>
          <div v-if="stat.totalTime">Total: {{ stat.totalTime }}</div>
        </div>
      </div>
    </div>
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

interface TrackStats {
  name: string
  color: string
  distance?: string
  maxSpeed?: string
  ascent?: string
  movingTime?: string
  totalTime?: string
}

const props = defineProps<{
  gpxUrl?: string
}>()

const photos = ref<PhotoPoint[]>([])
const photosData = ref<PhotoPoint[]>([])
const selectedPhotoIndex = ref<number | null>(null)
const showThumbs = ref(true)
const showStats = ref(true)
const trackStats = ref<TrackStats[]>([])
const photoMarkers = ref<any[]>([])
const mapRef = ref<any>(null)

const config = useRuntimeConfig()
const baseUrl = config.app.baseURL || ''

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
    zoomControl: false,
    tap: false, // Disable tap to prevent conflicts with marker clicks
    touchZoom: true,
    doubleClickZoom: true
  })
  
  L.control.zoom({ position: 'bottomleft' }).addTo(map)

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map)

  const config = useRuntimeConfig()
  const baseUrl = config.app.baseURL || ''
  
  const allLatLngs: [number, number][][] = []
  const allElevations: number[][] = []
  
  // Load track list from tracks.json
  interface TrackInfo { id: string; name: string; file: string; color: string }
  const tracks: TrackInfo[] = [{ id: 'part-1', name: 'From Britz to Vienna', file: '2026-part-1.gpx', color: '#3b82f6' }]
  try {
    const tracksRes = await fetch(`${baseUrl}tracks.json`)
    const tracksData = await tracksRes.json()
    if (tracksData.tracks) {
      tracks.length = 0
      tracksData.tracks.forEach((t: TrackInfo) => tracks.push(t))
    }
  } catch (e) {
    console.error('Failed to load tracks.json, using defaults')
  }
  
  trackStats.value = []
  
  for (const track of tracks) {
    try {
      const response = await fetch(`${baseUrl}${track.file}`)
      const gpxText = await response.text()
      
      const parser = new DOMParser()
      const gpxDoc = parser.parseFromString(gpxText, 'application/xml')
      const trkpts = gpxDoc.querySelectorAll('trkpt')
      
      const latlngs: [number, number][] = []
      const elevations: number[] = []
      const timestamps: Date[] = []
      
      trkpts.forEach((pt) => {
        const lat = parseFloat(pt.getAttribute('lat') || '0')
        const lon = parseFloat(pt.getAttribute('lon') || '0')
        const eleEl = pt.querySelector('ele')
        const ele = eleEl ? parseFloat(eleEl.textContent || '0') : 0
        const timeEl = pt.querySelector('time')
        const time = timeEl ? new Date(timeEl.textContent || '') : null
        
        latlngs.push([lat, lon])
        elevations.push(ele)
        if (time && !isNaN(time.getTime())) timestamps.push(time)
      })
      
      if (latlngs.length > 0) {
        const polyline = L.polyline(latlngs, { color: track.color, weight: 4, opacity: 0.85 })
        polyline.addTo(map)
        allLatLngs.push(latlngs)
        allElevations.push(elevations)
        
        // Calculate track stats
        const trackStat: TrackStats = { name: track.name, color: track.color }
        
        // Distance
        let trackDist = 0
        for (let i = 1; i < latlngs.length; i++) {
          trackDist += map.distance(latlngs[i-1], latlngs[i])
        }
        if (trackDist > 0) trackStat.distance = `${(trackDist / 1000).toFixed(1)} km`
        
        // Ascent (sum of positive elevation changes)
        let ascent = 0
        for (let i = 1; i < elevations.length; i++) {
          const diff = elevations[i] - elevations[i-1]
          if (diff > 0) ascent += diff
        }
        if (ascent > 0) trackStat.ascent = `${Math.round(ascent)}m`
        
        // Time calculations (if timestamps available)
        if (timestamps.length > 1) {
          const firstTime = timestamps[0].getTime()
          const lastTime = timestamps[timestamps.length - 1].getTime()
          const totalMs = lastTime - firstTime
          
          if (totalMs > 0) {
            trackStat.totalTime = formatDuration(totalMs)
            
            // Calculate moving time (gaps > 60s likely stopped)
            let movingMs = 0
            let gapStart = 0
            for (let i = 1; i < timestamps.length; i++) {
              const gap = timestamps[i].getTime() - timestamps[i-1].getTime()
              if (gap > 60000) {
                // Stopped, don't count this gap
                movingMs += timestamps[gapStart].getTime() - timestamps[0].getTime() - (gapStart > 0 ? (timestamps[gapStart].getTime() - timestamps[gapStart-1].getTime()) : 0)
                gapStart = i
              }
            }
            // Add remaining time
            movingMs = totalMs - (timestamps.length > 10 ? timestamps.slice(-10).reduce((a, t, i) => i === 0 ? 0 : a + (t.getTime() - timestamps[i-1].getTime()), 0) : 0)
            
            // Simpler approach: use median speed to estimate moving time
            const speeds: number[] = []
            for (let i = 1; i < latlngs.length; i++) {
              const dist = map.distance(latlngs[i-1], latlngs[i])
              const time = timestamps[i] && timestamps[i-1] ? (timestamps[i].getTime() - timestamps[i-1].getTime()) / 1000 : 0
              if (time > 0) {
                const speed = (dist / time) * 3.6 // km/h
                if (speed > 2 && speed < 50) speeds.push(speed)
              }
            }
            
            // Max speed
            if (speeds.length > 0) {
              const maxSpeed = Math.max(...speeds)
              trackStat.maxSpeed = `${maxSpeed.toFixed(1)} km/h`
              
              // Moving time: total dist / median speed
              if (trackDist > 0 && speeds.length > 0) {
                speeds.sort((a, b) => a - b)
                const medianSpeed = speeds[Math.floor(speeds.length / 2)]
                const movingHours = (trackDist / 1000) / medianSpeed
                trackStat.movingTime = formatDuration(movingHours * 3600000)
              }
            }
          }
        }
        
        trackStats.value.push(trackStat)
      }
      
    } catch (e) {
      console.error('GPX parse error:', e)
    }
  }
  
  // Calculate total stats (simplified)
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
  
  photoMarkers.value = []
  
  if (allLatLngs.length > 0) {
    const allPoints = allLatLngs.flat()
    map.fitBounds(L.latLngBounds(allPoints))
  }
  
  // Load photos and add as Leaflet markers
  try {
    const photosRes = await fetch(`${baseUrl}images.json`)
    const fetchedPhotos = await photosRes.json()
    photosData.value = fetchedPhotos
    
    if (showThumbs.value) {
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
          className: 'photo-marker',
          iconSize: [48, 40],
          iconAnchor: [0, 20], // Tip of triangle at geo coord
          interactive: true
        })
        
        const marker = L.marker([lat, lon], { icon, interactive: true }).on('click', (e: L.LeafletMouseEvent) => {
          L.DomEvent.stopPropagation(e.originalEvent)
          selectedPhotoIndex.value = index
        }).addTo(map)
        
        photoMarkers.value.push(marker)
      })
    }
  } catch (e) {
    console.error('Photos load error:', e)
  }
  
  mapRef.value = map
})

// Watch for thumbnail toggle changes
watch(showThumbs, (show) => {
  if (!mapRef.value) return
  
  if (show) {
    photoMarkers.value.forEach(marker => marker.addTo(mapRef.value))
  } else {
    photoMarkers.value.forEach(marker => marker.remove())
  }
})

function formatDuration(ms: number): string {
  const hours = Math.floor(ms / 3600000)
  const mins = Math.floor((ms % 3600000) / 60000)
  if (hours > 0) return `${hours}h ${mins}m`
  return `${mins}m`
}

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
  pointer-events: auto !important;
}
.photo-marker img {
  cursor: pointer !important;
  pointer-events: none !important;
}
.photo-marker > * {
  pointer-events: auto !important;
}

/* Leaflet zoom buttons - dark theme */
.leaflet-control-zoom a {
  background: #0f0f14 !important;
  color: white !important;
  border: 1px solid rgba(255,255,255,0.08) !important;
  width: 32px !important;
  height: 32px !important;
  line-height: 30px !important;
  font-size: 16px !important;
}
.leaflet-control-zoom a:hover {
  background: rgba(255,255,255,0.08) !important;
}
.leaflet-control-zoom {
  border: none !important;
  box-shadow: 0 4px 24px rgba(0,0,0,0.5) !important;
  border-radius: 10px !important;
  overflow: hidden;
}
.leaflet-control-zoom-in {
  border-radius: 10px 10px 0 0 !important;
}
.leaflet-control-zoom-out {
  border-radius: 0 0 10px 10px !important;
}
</style>
