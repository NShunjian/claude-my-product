/**
 * 认证 Store:对齐 uniapp stores/auth.ts 1:1(Pinia → ObservedV2/Trace)。
 * ponytail: AppStorageV2 持久化 token/user;单例 getAuth() 注入避免循环依赖。
 */
import { AppStorageV2, promptAction, router } from '@kit.ArkUI'
import preferences from '@ohos.data.preferences'
import { getCtx } from '../utils/context'
import type { User, AuthRegisterPayload } from '../model/Types'
import { login as apiLogin, register as apiRegister, me as apiMe, logout as apiLogout } from '../api/auth'
import { onAuthInvalid, setNavGrace } from '../api/http'
import { getToast } from './toast'

const STORE = 'qingzhang-auth'
let prefs: preferences.Preferences | null = null
async function getPrefs(): Promise<preferences.Preferences> {
  if (prefs) return prefs
  prefs = await preferences.getPreferences(getCtx(), STORE)
  return prefs
}

@ObservedV2
export class AuthStore {
  @Trace token: string = ''
  @Trace user: User | null = null
  @Trace ready: boolean = false

  async hydrate(): Promise<void> {
    try {
      const p = await getPrefs()
      const t = await p.get('token', '') as string
      const u = await p.get('user', '') as string
      if (t) this.token = t
      if (u) this.user = JSON.parse(u) as User
    } catch { /* ignore */ }
    this.ready = true
  }

  async persist(): Promise<void> {
    try {
      const p = await getPrefs()
      await p.put('token', this.token)
      await p.put('user', JSON.stringify(this.user))
      await p.flush()
    } catch { /* ignore */ }
  }

  async login(username: string, password: string): Promise<void> {
    const r = await apiLogin({ username: username, password: password })
    this.token = r.token
    this.user = r.user
    await this.persist()
  }

  async register(payload: AuthRegisterPayload): Promise<void> {
    await apiRegister(payload)
    await this.login(payload.username, payload.password)
  }

  async me(): Promise<void> { this.user = await apiMe(); await this.persist() }
  async refresh(): Promise<void> { await this.me() }

  async logout(): Promise<void> {
    try { await apiLogout() } catch { /* 容忍 */ }
    this.token = ''
    this.user = null
    await this.persist()
  }

  kickToLogin(): void {
    this.token = ''
    this.user = null
    setNavGrace(3000)
    const toast = getToast()
    if (toast) toast.show('登录已失效,请重新登录')
    try { promptAction.showToast({ message: '登录已失效', duration: 1500 }) } catch { /* noop */ }
    try { router.replaceUrl({ url: 'pages/Login' }) } catch { /* noop */ }
  }
}

export const authStore: AuthStore = AppStorageV2.connect(AuthStore, 'authStore', () => new AuthStore())!
export function getAuth(): AuthStore { return authStore }

export class AppInfo {
  version: string
  buildNumber: string
  constructor(version: string, buildNumber: string) {
    this.version = version
    this.buildNumber = buildNumber
  }
}

/**
 * 静态应用信息(版本号、构建号等);实际项目可从 ohos.bundleManager 读取。
 */
export const appInfo: AppInfo = new AppInfo('1.0.0', '1')

// 注册 1401 拦截器
onAuthInvalid(() => authStore.kickToLogin())
