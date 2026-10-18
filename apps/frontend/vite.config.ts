import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  server: {
    // 5173–5176 are taken by other projects on this machine.
    port: 5178,
    strictPort: true,
    // Proxy /api to the backend so the browser sees one origin in development
    // and CORS never enters the picture.
    proxy: {
      '/api': { target: process.env.API_PROXY_TARGET ?? 'http://localhost:3002', changeOrigin: true },
    },
  },
  build: { outDir: 'dist', sourcemap: false },
})
