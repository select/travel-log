<template>
  <Teleport to="body">
    <div 
      v-if="isOpen" 
      class="fixed inset-0 z-[9999] flex items-center justify-center bg-black/90 backdrop-blur-sm"
      @click.self="close"
    >
      <!-- Close button at top -->
      <button 
        class="absolute top-4 right-4 w-10 h-10 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white text-2xl font-bold z-10"
        @click="close"
      >
        ×
      </button>
      
      <!-- Prev button -->
      <button 
        v-if="currentIndex > 0"
        class="absolute left-4 top-1/2 -translate-y-1/2 w-12 h-12 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white text-2xl z-10"
        @click="prev"
      >
        ‹
      </button>
      
      <!-- Image container -->
      <div class="max-w-[90vw] max-h-[90vh] relative z-0">
        <div v-if="currentPhoto" class="max-w-full max-h-[85vh] rounded-lg shadow-2xl overflow-hidden">
          <img 
            :key="`photo-${currentIndex}`"
            :src="imageUrl"
            class="block max-w-full max-h-[85vh] object-contain"
            :alt="currentPhoto.file"
          />
        </div>
      </div>
      
      <!-- Next button -->
      <button 
        v-if="currentIndex < photos.length - 1"
        class="absolute right-4 top-1/2 -translate-y-1/2 w-12 h-12 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white text-2xl z-10"
        @click="next"
      >
        ›
      </button>
      
      <!-- Image counter -->
      <div class="absolute bottom-4 left-1/2 -translate-x-1/2 text-white/80 text-sm">
        {{ currentIndex + 1 }} / {{ photos.length }}
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
interface Photo {
  file: string
  lat: string
  lon: string
  date: string
}

const props = defineProps<{
  photos: Photo[]
  initialIndex?: number
}>()

const emit = defineEmits<{
  close: []
}>()

const isOpen = ref(false)
const currentIndex = ref(0)
const imageUrl = ref('')

watch(() => props.initialIndex, (newIndex) => {
  if (newIndex !== undefined && newIndex !== null) {
    currentIndex.value = newIndex
    isOpen.value = true
    updateUrl()
  }
}, { immediate: true })

const currentPhoto = computed(() => props.photos[currentIndex.value])

function updateUrl() {
  if (currentPhoto.value) {
    imageUrl.value = `/images/${currentPhoto.value.file}?v=${Date.now()}-${currentIndex.value}`
  }
}

function close() {
  isOpen.value = false
  emit('close')
}

function prev() {
  if (currentIndex.value > 0) {
    currentIndex.value--
    updateUrl()
  }
}

function next() {
  if (currentIndex.value < props.photos.length - 1) {
    currentIndex.value++
    updateUrl()
  }
}

// Keyboard navigation
onMounted(() => {
  const handler = (e: KeyboardEvent) => {
    if (e.key === 'Escape') close()
    if (e.key === 'ArrowLeft') prev()
    if (e.key === 'ArrowRight') next()
  }
  window.addEventListener('keydown', handler)
  onUnmounted(() => window.removeEventListener('keydown', handler))
})
</script>