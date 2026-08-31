import { defineStore } from 'pinia'
import { ref } from 'vue'

type Mode = 'system' | 'light' | 'dark'
const KEY = 'qz_theme_mode'

export const useThemeStore = defineStore('theme', () => {
  const mode = ref<Mode>((uni.getStorageSync(KEY) as Mode) ?? 'system')
  const resolved = ref<'light' | 'dark'>('light')

  function applySystemListener() {
    const mql = typeof window !== 'undefined' ? window.matchMedia('(prefers-color-scheme: dark)') : null
    function update() {
      const wantDark = mode.value === 'dark' || (mode.value === 'system' && !!mql?.matches)
      resolved.value = wantDark ? 'dark' : 'light'
      if (typeof document !== 'undefined') {
        document.documentElement.setAttribute('data-theme', resolved.value)
      }
    }
    update()
    if (mql) mql.addEventListener('change', update)
  }

  function setMode(m: Mode) {
    mode.value = m
    uni.setStorageSync(KEY, m)
    applySystemListener()
  }

  return { mode, resolved, setMode, applySystemListener }
})
