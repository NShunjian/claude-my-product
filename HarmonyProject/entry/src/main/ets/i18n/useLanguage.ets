/**
 * 语言 Hook:对齐 uniapp i18n/useLanguage.ts 1:1。
 */
import { languageStore } from '../stores/language'
import { t as translate, I18nArgs } from './dict'
import type { Lang } from './dict'

export interface LangOption { code: Lang; label: string }

export const LANGS: LangOption[] = [
  { code: 'zh-CN', label: '简体中文' },
  { code: 'zh-TW', label: '繁體中文' },
  { code: 'en', label: 'English' },
]

export class LanguageApi {
  private _lang: () => Lang
  constructor() { this._lang = (): Lang => languageStore.lang }
  get lang(): Lang { return this._lang() }
  setLang(l: Lang): void { void languageStore.setLang(l) }
  t(key: string, args?: I18nArgs): string { return translate(languageStore.lang, key, args) }
}

export function useLanguage(): LanguageApi { return new LanguageApi() }
