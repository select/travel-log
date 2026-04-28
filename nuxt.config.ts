// https://nuxt.com/docs/api/configuration/nuxt-config
const isGitHubPages = process.env.GITHUB_PAGES === 'true'

export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: true },
  modules: ['@unocss/nuxt'],
  css: ['leaflet/dist/leaflet.css'],
  app: {
    baseURL: isGitHubPages ? '/travel-log/' : '/',
  },
  nitro: {
    preset: isGitHubPages ? 'github-pages' : undefined,
  },
})