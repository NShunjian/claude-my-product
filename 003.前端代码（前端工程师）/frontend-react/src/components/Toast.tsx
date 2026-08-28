import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  useState,
} from 'react'
import type { ReactNode } from 'react'

interface ToastItem {
  id: number
  message: string
}

interface ToastApi {
  show: (message: string) => void
}

const ToastContext = createContext<ToastApi | undefined>(undefined)

const DEFAULT_DURATION_MS = 3500

/**
 * 轻量全局 Toast 系统 — 屏幕中央显示,默认 3.5s 自动消失。
 * 用法:在组件中 const toast = useToast(); toast.show('xxx')
 */
export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([])
  const idRef = useRef(0)
  const timersRef = useRef<Map<number, ReturnType<typeof setTimeout>>>(new Map())
  // 同 message 短时间窗口内去重(React StrictMode 在 dev 下会让 useEffect 触发两次,导致 toast 重复弹)
  const lastShowRef = useRef<{ msg: string; ts: number } | null>(null)
  const DEDUP_WINDOW_MS = 1500

  const dismiss = useCallback((id: number) => {
    setItems((prev) => prev.filter((t) => t.id !== id))
    const timer = timersRef.current.get(id)
    if (timer) {
      clearTimeout(timer)
      timersRef.current.delete(id)
    }
  }, [])

  const show = useCallback(
    (message: string) => {
      const now = Date.now()
      const last = lastShowRef.current
      if (last && last.msg === message && now - last.ts < DEDUP_WINDOW_MS) {
        return
      }
      lastShowRef.current = { msg: message, ts: now }
      const id = ++idRef.current
      setItems((prev) => [...prev, { id, message }])
      const timer = setTimeout(() => dismiss(id), DEFAULT_DURATION_MS)
      timersRef.current.set(id, timer)
    },
    [dismiss],
  )

  const api = useMemo<ToastApi>(() => ({ show }), [show])

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div
        aria-live="polite"
        aria-atomic="false"
        className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 z-50 flex flex-col items-center gap-2 pointer-events-none"
      >
        {items.map((t) => (
          <div
            key={t.id}
            role="status"
            className="pointer-events-auto flex items-center gap-3 px-6 py-4 rounded-xl border border-error/40 bg-bg-card shadow-2xl font-headline-md text-headline-md text-on-surface"
          >
            <span
              className="material-symbols-outlined text-error"
              style={{ fontSize: '24px', fontVariationSettings: "'FILL' 1" }}
              aria-hidden="true"
            >
              error
            </span>
            <span>{t.message}</span>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}

export function useToast(): ToastApi {
  const ctx = useContext(ToastContext)
  if (!ctx) {
    throw new Error('useToast must be used within ToastProvider')
  }
  return ctx
}