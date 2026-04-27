import { defineConfig } from 'unocss'
import presetUno from 'unocss/preset-uno'
import presetMini from 'unocss/preset-mini'

export default defineConfig({
  presets: [
    presetUno(),
    presetMini(),
  ],
  theme: {
    colors: {
      track: {
        blue: '#3b82f6',
        header: '#1e293b',
      },
    },
  },
})
