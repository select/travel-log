import { defineConfig } from 'unocss'
import presetUno from 'unocss/preset-uno'
import presetMini from 'unocss/preset-mini'
import presetWebFonts from '@unocss/preset-web-fonts'

export default defineConfig({
  presets: [
    presetUno(),
    presetMini(),
    presetWebFonts({
      provider: 'google',
      fonts: {
        sans: 'DM Sans:400,500',
        serif: 'Fraunces:400,700',
        mono: 'IBM Plex Mono:400,500',
      },
    }),
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