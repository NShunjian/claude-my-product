/**
 * 语言 Store:对齐 uniapp stores/language.ts 1:1。
 */
import { AppStorageV2 } from '@kit.ArkUI'
import preferences from '@ohos.data.preferences'
import { getCtx } from '../utils/context'

const STORE = 'qingzhang-lang'
let prefs: preferences.Preferences | null = null
async function getPrefs(): Promise<preferences.Preferences> {
  if (prefs) return prefs
  prefs = await preferences.getPreferences(getCtx(), STORE)
  return prefs
}

export type LangCode = 'zh-CN' | 'en' | 'zh-TW'

@ObservedV2
export class LanguageStore {
  @Trace lang: LangCode = 'zh-CN'

  async hydrate(): Promise<void> {
    try {
      const p = await getPrefs()
      const l = await p.get('lang', 'zh-CN') as string
      this.lang = (l === 'en' || l === 'zh-TW') ? l : 'zh-CN'
    } catch { /* ignore */ }
  }

  async setLang(lang: LangCode): Promise<void> {
    this.lang = lang
    const p = await getPrefs()
    await p.put('lang', lang)
    await p.flush()
  }
}

export const languageStore: LanguageStore = AppStorageV2.connect(LanguageStore, 'languageStore', () => new LanguageStore())!
export function getLanguage(): LanguageStore { return languageStore }
