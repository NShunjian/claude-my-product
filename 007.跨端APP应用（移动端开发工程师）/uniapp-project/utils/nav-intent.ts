/**
 * 跨 tabBar 跳转时携带一次性意图(uni.switchTab 不支持 url query)。
 * 跳转前调用 setPendingMonth(),目标页 onLoad 里 consumePendingMonth() 读取后清空。
 */
let pendingMonth: string | null = null

export function setPendingMonth(m: string): void {
  pendingMonth = m
}

export function consumePendingMonth(): string | null {
  const m = pendingMonth
  pendingMonth = null
  return m
}