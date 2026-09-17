/**
 * 路由返回工具:与 uniapp utils/back.ts 1:1 对齐。
 * ponytail: HarmonyOS 用 router.back();若 history 不够则回首页。
 */
import { router } from '@kit.ArkUI'

export function goBack(fallback: string = 'pages/Index'): void {
  try {
    router.back()
  } catch {
    try { router.replaceUrl({ url: fallback }) } catch { /* noop */ }
  }
}
