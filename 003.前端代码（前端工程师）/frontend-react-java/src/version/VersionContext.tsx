import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { getSystemVersion } from '../api/version'

/**
 * 版本号 Context（最小可工作版）：
 *   - 启动时从后端 GET /api/version 拉一次版本号（无鉴权）
 *   - 模块级缓存：同会话内不重复请求
 *   - 三态：loading / resolved / error，Settings 页据此显示降级文案
 *   - 不写前端 package.json：版本号权威源自后端部署
 */

export interface VersionContextValue {
  /** 后端拉到的版本号；拉取失败或未完成时为 null */
  version: string | null
  /** 拉取状态：loading（首屏）/ ok / error */
  state: 'loading' | 'ok' | 'error'
}

const VersionContext = createContext<VersionContextValue | undefined>(undefined)

export function VersionProvider({ children }: { children: ReactNode }) {
  const [version, setVersion] = useState<string | null>(null)
  const [state, setState] = useState<'loading' | 'ok' | 'error'>('loading')

  useEffect(() => {
    let cancelled = false
    getSystemVersion()
      .then((res) => {
        if (cancelled) return
        setVersion(res.version)
        setState('ok')
      })
      .catch((err) => {
        if (cancelled) return
        // 后端未启动 / 网络断：降级到 "—" 并标 error
        console.warn('[version] fetch failed', err)
        setState('error')
      })
    return () => {
      cancelled = true
    }
  }, [])

  const value = useMemo<VersionContextValue>(() => ({ version, state }), [version, state])

  return <VersionContext.Provider value={value}>{children}</VersionContext.Provider>
}

export function useVersion(): VersionContextValue {
  const ctx = useContext(VersionContext)
  if (!ctx) throw new Error('useVersion must be used within a VersionProvider')
  return ctx
}