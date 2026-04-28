import { defineConfig } from 'unocss'
import presetWebFonts from '@unocss/preset-web-fonts'

export default defineConfig({
  presets: [
    require('unocss/preset-uno'),
    require('unocss/preset-mini'),
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