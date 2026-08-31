import { createContext, useCallback, useContext, useState, type ReactNode } from 'react'

type ToastKind = 'success' | 'error' | 'info'
interface Toast {
  id: number
  kind: ToastKind
  message: string
}
interface ToastApi {
  toasts: Toast[]
  show: (kind: ToastKind, message: string) => void
}

const ToastContext = createContext<ToastApi | null>(null)
let nextId = 1

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])

  const show = useCallback((kind: ToastKind, message: string) => {
    const id = nextId++
    setToasts((prev) => [...prev, { id, kind, message }])
    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id))
    }, 3000)
  }, [])

  return (
    <ToastContext.Provider value={{ toasts, show }}>
      {children}
      <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={
              'rounded-lg px-4 py-2 shadow-lg text-sm text-white transition-opacity ' +
              (t.kind === 'success' ? 'bg-success' :
               t.kind === 'error' ? 'bg-error' : 'bg-on-surface-variant')
            }
            role="status"
          >
            {t.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}

export function useToast(): ToastApi {
  const ctx = useContext(ToastContext)
  if (!ctx) throw new Error('useToast must be inside ToastProvider')
  return ctx
}

// Convenience wrappers —— 调用方可以 import { toast } 然后 toast.success('...')
export const toast = {
  success: (msg: string) => useToast().show('success', msg),
  error: (msg: string) => useToast().show('error', msg),
  info: (msg: string) => useToast().show('info', msg),
}
