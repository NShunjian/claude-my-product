import { useState, useCallback, type ReactNode } from 'react'

interface ConfirmOptions {
  title: string
  body: ReactNode
  danger?: boolean
}

interface ConfirmApi {
  confirm: (opts: ConfirmOptions) => Promise<boolean>
  dialog: ConfirmOptions | null
  onCancel: () => void
  onConfirm: () => void
}

let externalConfirm: ((opts: ConfirmOptions) => Promise<boolean>) | null = null

/**
 * 注册全局 confirm —— Provider 初始化时调用,后续组件直接 confirm({...})。
 *
 * 用法:
 *   <ConfirmProvider />
 *   ...
 *   const ok = await confirm({ title: '确定删除?', body: '...', danger: true })
 */
export function ConfirmProvider(): ConfirmApi {
  const [dialog, setDialog] = useState<ConfirmOptions | null>(null)
  const [resolver, setResolver] = useState<((v: boolean) => void) | null>(null)

  const confirm = useCallback((opts: ConfirmOptions) => {
    setDialog(opts)
    return new Promise<boolean>((resolve) => setResolver(() => resolve))
  }, [])

  // 暴露给外部 hook
  externalConfirm = confirm

  const onCancel = useCallback(() => {
    resolver?.(false); setResolver(null); setDialog(null)
  }, [resolver])
  const onConfirm = useCallback(() => {
    resolver?.(true); setResolver(null); setDialog(null)
  }, [resolver])

  return {
    confirm, dialog, onCancel, onConfirm,
  } as ConfirmApi
}

export function ConfirmDialogRender({ api }: { api: ReturnType<typeof ConfirmProvider> }) {
  if (!api.dialog) return null
  return (
    <div className="fixed inset-0 z-[60] bg-black/40 flex items-center justify-center">
      <div className="bg-bg-card rounded-xl shadow-xl max-w-sm w-full mx-4 p-6">
        <h2 className="text-lg font-bold mb-2">{api.dialog.title}</h2>
        <div className="text-sm text-on-surface-variant mb-6">{api.dialog.body}</div>
        <div className="flex justify-end gap-2">
          <button onClick={api.onCancel} className="px-4 py-2 rounded-lg border border-divider">
            取消
          </button>
          <button
            onClick={api.onConfirm}
            className={
              'px-4 py-2 rounded-lg text-on-primary ' +
              (api.dialog.danger ? 'bg-error' : 'bg-primary')
            }
          >
            确定
          </button>
        </div>
      </div>
    </div>
  )
}

/** 业务组件调用此函数弹窗 —— 必须在 ConfirmProvider 范围内才能用 */
export function confirm(opts: ConfirmOptions): Promise<boolean> {
  if (!externalConfirm) throw new Error('confirm called without ConfirmProvider')
  return externalConfirm(opts)
}
