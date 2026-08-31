import { defineConfig, presetUno } from 'unocss'
export default defineConfig({
  presets: [presetUno()],
  theme: {
    colors: {
      primary: '#2E7DE6',
      'primary-light': '#D9E8FA',
      bg: '#FFFFFF', 'bg-card': '#FAFAFA',
      text: '#1A1A1A', 'text-variant': '#5F6368',
      divider: '#E0E0E0', error: '#BA1A1A', surface: '#F5F5F5',
    },
  },
})
