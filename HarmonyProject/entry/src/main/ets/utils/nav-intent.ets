/**
 * 一次性跨页面意图:对齐 uniapp utils/nav-intent.ts。
 * ponytail: tab 页切换不支持 query,这里用 AppStorageV2 传 month。
 */
import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class NavIntent {
  @Trace pendingMonth: string = ''
  @Trace pendingBookUuid: string = ''
}

export const navIntent: NavIntent = AppStorageV2.connect(NavIntent, 'navIntent', () => new NavIntent())!

export function setPendingMonth(month: string): void { navIntent.pendingMonth = month }
export function consumePendingMonth(): string {
  const m = navIntent.pendingMonth
  navIntent.pendingMonth = ''
  return m
}

export function setPendingBookUuid(uuid: string): void { navIntent.pendingBookUuid = uuid }
export function consumePendingBookUuid(): string {
  const u = navIntent.pendingBookUuid
  navIntent.pendingBookUuid = ''
  return u
}
