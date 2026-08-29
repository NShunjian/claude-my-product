import { createContext, useCallback, useContext, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { DICTS, LANGS, type Lang as LangType } from './dict'

/**
 * 最小可工作版 i18n:
 *   - 三档语言(简体/English/繁體)
 *   - localStorage 持久化
 *   - t(key) 当前语言优先 → 回落到 zh-CN → 再缺回落 key
 *   - 本期只翻译 Settings.tsx 自身 + 顶部标题;其它页面留作后续工程
 */

export type { LangType as Lang }
export { LANGS }

const STORAGE_KEY = 'qz_lang'

export interface LanguageContextValue {
  lang: LangType
  setLang: (lang: LangType) => void
  /** 翻译;缺翻译时回落到 zh-CN,再缺回落 key */
  t: (key: string) => string
}

const LanguageContext = createContext<LanguageContextValue | undefined>(undefined)

function readStoredLang(): LangType {
  if (typeof window === 'undefined') return 'zh-CN'
  const v = window.localStorage.getItem(STORAGE_KEY)
  if (v === 'zh-CN' || v === 'en' || v === 'zh-TW') return v
  return 'zh-CN'
}

export function LanguageProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<LangType>(() => readStoredLang())

  const setLang = useCallback((next: LangType) => {
    setLangState(next)
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(STORAGE_KEY, next)
    }
  }, [])

  const t = useCallback(
    (key: string): string => {
      const cur = DICTS[lang]
      if (cur[key]) return cur[key]
      const fallback = DICTS['zh-CN']
      if (fallback[key]) return fallback[key]
      return key
    },
    [lang],
  )

  const value = useMemo<LanguageContextValue>(
    () => ({ lang, setLang, t }),
    [lang, setLang, t],
  )

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>
}

export function useLanguage(): LanguageContextValue {
  const ctx = useContext(LanguageContext)
  if (!ctx) throw new Error('useLanguage must be used within a LanguageProvider')
  return ctx
}