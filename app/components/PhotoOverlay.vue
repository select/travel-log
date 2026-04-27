<template>
  <Teleport to="body">
    <div 
      v-if="isOpen" 
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/90 backdrop-blur-sm"
      @click.self="close"
    >
      <!-- Close button -->
      <button 
        class="absolute top-4 right-4 w-10 h-10 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white text-2xl font-bold"
        @click="close"
      >
        ×
      </button>
      
      <!-- Prev button -->
      <button 
        v-if="currentIndex > 0"
        class="absolute left-4 top-1/2 -translate-y-1/2 w-12 h-12 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white text-2xl"
        @click="prev"
      >
        ‹
      </button>
      
      <!-- Image container -->
      <div class="max-w-[90vw] max-h-[90vh] relative">
        <img 
          :src="`/img/${currentPhoto.file}`" 
          class="max-w-full max-h-[85vh] object-contain rounded-lg shadow-2xl"
          :alt="currentPhoto.file"
        />
      </div>
      
      <!-- Next button -->
      <button 
        v-if="currentIndex < photos.length - 1"
        class="absolute right-4 top-1/2 -translate-y-1/2 w-12 h-12 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white text-2xl"
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

const isOpen = ref(true)
const currentIndex = ref(props.initialIndex || 0)

const currentPhoto = computed(() => props.photos[currentIndex.value])

function close() {
  isOpen.value = false
  emit('close')
}

function prev() {
  if (currentIndex.value > 0) {
    currentIndex.value--
  }
}

function next() {
  if (currentIndex.value < props.photos.length - 1) {
    currentIndex.value++
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
