/**
 * 主题 Store:对齐 uniapp stores/theme.ts 1:1。
 * ponytail: HarmonyOS 用 ConfigurationConstant 监听系统主题变化。
 */
import { AppStorageV2 } from '@kit.ArkUI'
import ConfigurationConstant from '@ohos.app.ability.ConfigurationConstant'
import preferences from '@ohos.data.preferences'
import { getCtx } from '../utils/context'

const STORE = 'qingzhang-theme'
let prefs: preferences.Preferences | null = null
async function getPrefs(): Promise<preferences.Preferences> {
  if (prefs) return prefs
  prefs = await preferences.getPreferences(getCtx(), STORE)
  return prefs
}

export type ThemeMode = 'system' | 'light' | 'dark'

@ObservedV2
export class ThemeStore {
  @Trace mode: ThemeMode = 'system'
  @Trace systemDark: boolean = false

  get effective(): boolean {
    if (this.mode === 'system') return this.systemDark
    return this.mode === 'dark'
  }

  async hydrate(): Promise<void> {
    try {
      const p = await getPrefs()
      const m = await p.get('mode', 'system') as string
      this.mode = (m === 'light' || m === 'dark') ? m : 'system'
    } catch { /* ignore */ }
  }

  async setMode(mode: ThemeMode): Promise<void> {
    this.mode = mode
    const p = await getPrefs()
    await p.put('mode', mode)
    await p.flush()
  }

  setSystemDark(dark: boolean): void { this.systemDark = dark }

  resolveConfig(): ConfigurationConstant.ColorMode {
    if (this.mode === 'dark') return ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    if (this.mode === 'light') return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
    return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  }
}

export const themeStore: ThemeStore = AppStorageV2.connect(ThemeStore, 'themeStore', () => new ThemeStore())!
export function getTheme(): ThemeStore { return themeStore }
