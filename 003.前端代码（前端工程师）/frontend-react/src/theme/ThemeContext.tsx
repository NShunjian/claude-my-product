import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'

/**
 * 主题模式三档:
 *   - 'system': 跟随系统 (prefers-color-scheme)
 *   - 'light':  强制浅色
 *   - 'dark':   强制深色
 *
 * 实际生效主题由 `effectiveTheme` 暴露;
 * 启动时通过 setInitialHtmlTheme() 在 main.tsx 顶部同步设 class,
 * 避免首屏浅色闪烁。
 */

export type ThemeMode = 'system' | 'light' | 'dark'
export type EffectiveTheme = 'light' | 'dark'

const STORAGE_KEY = 'qz_theme'

export interface ThemeContextValue {
  mode: ThemeMode
  effectiveTheme: EffectiveTheme
  setMode: (mode: ThemeMode) => void
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined)

function readStoredMode(): ThemeMode {
  if (typeof window === 'undefined') return 'system'
  const v = window.localStorage.getItem(STORAGE_KEY)
  if (v === 'light' || v === 'dark' || v === 'system') return v
  return 'system'
}

/**
 * 同步读取持久化值,立刻在 <html> 上加 .dark,
 * 必须早于 createRoot 之前调用以防 FOUC。
 */
export function setInitialHtmlTheme(): void {
  if (typeof document === 'undefined') return
  const mode = readStoredMode()
  const wantsDark =
    mode === 'dark' ||
    (mode === 'system' &&
      typeof window.matchMedia === 'function' &&
      window.matchMedia('(prefers-color-scheme: dark)').matches)
  document.documentElement.classList.toggle('dark', wantsDark)
}

function applyHtmlTheme(effective: EffectiveTheme): void {
  if (typeof document === 'undefined') return
  document.documentElement.classList.toggle('dark', effective === 'dark')
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [mode, setModeState] = useState<ThemeMode>(() => readStoredMode())
  const [systemPrefersDark, setSystemPrefersDark] = useState<boolean>(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return false
    return window.matchMedia('(prefers-color-scheme: dark)').matches
  })

  // 跟随系统:监听 prefers-color-scheme 变化
  useEffect(() => {
    if (mode !== 'system') return
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const onChange = (e: MediaQueryListEvent) => setSystemPrefersDark(e.matches)
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [mode])

  const effectiveTheme: EffectiveTheme =
    mode === 'system' ? (systemPrefersDark ? 'dark' : 'light') : mode

  // 把 effective 同步到 <html>.dark
  useEffect(() => {
    applyHtmlTheme(effectiveTheme)
  }, [effectiveTheme])

  const setMode = useCallback((next: ThemeMode) => {
    setModeState(next)
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(STORAGE_KEY, next)
    }
  }, [])

  const value = useMemo<ThemeContextValue>(
    () => ({ mode, effectiveTheme, setMode }),
    [mode, effectiveTheme, setMode],
  )

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be used within a ThemeProvider')
  return ctx
}