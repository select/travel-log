<template>
  <div class="w-full flex-1 min-h-0 relative">
    <div ref="mapContainer" class="w-full h-full" style="touch-action: none;" />
    <PhotoOverlay
      v-if="selectedPhotoIndex !== null"
      :photos="photosData"
      :tour-id="tourId"
      :initial-index="selectedPhotoIndex"
      @close="selectedPhotoIndex = null"
    />
    
    <!-- Toggle controls - above zoom buttons -->
    <div class="absolute bottom-[106px] left-[12px] z-[1000] flex flex-col gap-0 rounded-xl overflow-hidden shadow-lg">
      <button
        @click="showThumbs = !showThumbs; if (showThumbs) showStats = false"
        class="w-8 h-8 flex items-center justify-center text-white bg-black border-0"
        :title="showThumbs ? 'Hide thumbnails' : 'Show thumbnails'"
      >
        <span :class="showThumbs ? 'i-mdi:image' : 'i-mdi:image-off'" class="text-base" />
      </button>
      <button
        @click="showStats = !showStats; if (showStats) showThumbs = false"
        class="w-8 h-8 flex items-center justify-center text-white bg-black border-0"
        :title="showStats ? 'Hide track stats' : 'Show track stats'"
      >
        <span :class="showStats ? 'i-mdi:map-marker' : 'i-mdi:map-marker-off'" class="text-base" />
      </button>
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
  tourId: string
}>()

const photos = ref<PhotoPoint[]>([])
const photosData = ref<PhotoPoint[]>([])
const selectedPhotoIndex = ref<number | null>(null)
const showThumbs = ref(true)
const showStats = ref(false)
const trackStats = ref<TrackStats[]>([])
const statsMarkers = ref<any[]>([])
const photoMarkers = ref<any[]>([])
const mapRef = ref<any>(null)

const config = useRuntimeConfig()
const baseUrl = config.app.baseURL || '/'
const tourUrl = `${baseUrl}tours/${props.tourId}/`

const emit = defineEmits<{
  stats: [data: { distance?: string; elevation?: string; duration?: string }]
}>()

const mapContainer = ref<HTMLElement | null>(null)
let disposed = false

onMounted(async () => {
  await nextTick()
  const L = (await import('leaflet')).default
  if (disposed) return
  const map = L.map(mapContainer.value!, { 
    center: [52.44, 13.43], 
    zoom: 13,
    zoomControl: false,
    tap: false, // Disable tap to prevent conflicts with marker clicks
    touchZoom: true,
    doubleClickZoom: true
  })
  
  mapRef.value = map
  L.control.zoom({ position: 'bottomleft' }).addTo(map)

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
  }).addTo(map)

  const allLatLngs: [number, number][][] = []
  const allElevations: number[][] = []
  
  // Load only the selected tour's tracks
  interface TrackInfo { id: string; name: string; file: string; color: string }
  let tracks: TrackInfo[] = []
  try {
    const tracksRes = await fetch(`${tourUrl}tracks.json`)
    if (!tracksRes.ok) throw new Error(`HTTP ${tracksRes.status}`)
    tracks = (await tracksRes.json()).tracks || []
    if (disposed) return
  } catch (e) {
    console.error('Failed to load tracks.json:', e)
  }
  
  if (disposed) return
  trackStats.value = []
  
  for (const track of tracks) {
    if (disposed) return
    try {
      const response = await fetch(`${tourUrl}${track.file}`)
      if (!response.ok) throw new Error(`HTTP ${response.status}: ${track.file}`)
      const gpxText = await response.text()
      if (disposed) return

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
        
        // Calculate track stats FIRST
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
            
            const speeds: number[] = []
            for (let i = 1; i < latlngs.length; i++) {
              const dist = map.distance(latlngs[i-1], latlngs[i])
              const time = timestamps[i] && timestamps[i-1] ? (timestamps[i].getTime() - timestamps[i-1].getTime()) / 1000 : 0
              if (time > 0) {
                const speed = (dist / time) * 3.6
                if (speed > 2 && speed < 50) speeds.push(speed)
              }
            }
            
            if (speeds.length > 0) {
              const maxSpeed = Math.max(...speeds)
              trackStat.maxSpeed = `${maxSpeed.toFixed(1)} km/h`
              
              if (trackDist > 0) {
                speeds.sort((a, b) => a - b)
                const medianSpeed = speeds[Math.floor(speeds.length / 2)]
                const movingHours = (trackDist / 1000) / medianSpeed
                trackStat.movingTime = formatDuration(movingHours * 3600000)
              }
            }
          }
        }
        
        trackStats.value.push(trackStat)
        
        // Add stats marker at track midpoint
        const midIdx = Math.floor(latlngs.length / 2)
        const midPoint = latlngs[midIdx]
        const nextPoint = latlngs[Math.min(midIdx + 5, latlngs.length - 1)]
        const offsetLat = midPoint[0] + (nextPoint[0] - midPoint[0]) * 0.02
        const offsetLon = midPoint[1] + (nextPoint[1] - midPoint[1]) * 0.02 + 0.005
        
        const statsLines: string[] = []
        if (trackStat.distance) statsLines.push(trackStat.distance)
        if (trackStat.maxSpeed) statsLines.push(`Max ${trackStat.maxSpeed}`)
        if (trackStat.ascent) statsLines.push(`↑ ${trackStat.ascent}`)
        if (trackStat.movingTime) statsLines.push(trackStat.movingTime)
        if (trackStat.totalTime) statsLines.push(trackStat.totalTime)
        
        if (statsLines.length > 0) {
          const statsHtml = `
            <div style="
              background: rgba(15,15,20,0.95);
              backdrop-filter: blur(12px);
              border: 1px solid rgba(255,255,255,0.08);
              border-radius: 8px;
              padding: 6px 10px;
              font-size: 11px;
              line-height: 1.4;
              box-shadow: 0 2px 12px rgba(0,0,0,0.4);
              white-space: nowrap;
            ">
              <div style="color: ${track.color}; font-weight: 500; margin-bottom: 2px;">Tag ${trackStats.value.length}</div>
              ${statsLines.map(line => `<div style="color: rgba(255,255,255,0.8);">${line}</div>`).join('')}
            </div>
          `
          
          const statsIcon = L.divIcon({
            html: statsHtml,
            className: 'track-stats-marker',
            iconSize: [120, 'auto'],
            iconAnchor: [0, 12],
          })
          
          const statsMarker = L.marker([offsetLat, offsetLon], { icon: statsIcon, interactive: false })
          if (showStats.value) {
            statsMarker.addTo(map)
          }
          statsMarkers.value.push(statsMarker)
        }
      }
      
    } catch (e) {
      console.error('GPX parse error:', e)
    }
  }
  
  if (disposed) return
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
    const photosRes = await fetch(`${tourUrl}images.json`)
    if (!photosRes.ok) throw new Error(`HTTP ${photosRes.status}`)
    const fetchedPhotos: PhotoPoint[] = (await photosRes.json()).filter((photo: PhotoPoint) => photo.lat && photo.lon)
    if (disposed) return
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
              <img src="${tourUrl}thumbnails/${photo.file}" style="width: 100%; height: 100%; object-fit: cover;" loading="lazy" />
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
    if (!disposed) console.error('Photos load error:', e)
  }
  
})

onUnmounted(() => {
  disposed = true
  mapRef.value?.remove()
  mapRef.value = null
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

// Watch for stats toggle changes
watch(showStats, (show) => {
  if (!mapRef.value) return
  
  if (show) {
    statsMarkers.value.forEach(marker => marker.addTo(mapRef.value))
  } else {
    statsMarkers.value.forEach(marker => {
      try { marker.remove() } catch(e) {}
    })
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

/* Track stats markers */
.track-stats-marker {
  background: transparent !important;
  border: none !important;
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
