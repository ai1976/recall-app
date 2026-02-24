import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // Core React runtime — loaded on every page
          'vendor-react': ['react', 'react-dom', 'react-router-dom'],
          // Supabase client — needed for auth on every page
          'vendor-supabase': ['@supabase/supabase-js'],
          // Radix UI primitives — large, shared across many components
          'vendor-radix': [
            '@radix-ui/react-dialog',
            '@radix-ui/react-dropdown-menu',
            '@radix-ui/react-select',
            '@radix-ui/react-popover',
            '@radix-ui/react-label',
            '@radix-ui/react-slot',
            '@radix-ui/react-switch',
            '@radix-ui/react-toast',
            '@radix-ui/react-progress',
          ],
        }
      }
    }
  }
})
