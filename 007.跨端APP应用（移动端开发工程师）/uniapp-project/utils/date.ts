/**
 * 本地时区日期工具 —— 别用 toISOString(),那个转 UTC,早上 8 点(UTC+8)之前会少一天。
 */

export function formatLocalDate(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
}

export function formatLocalMonth(d: Date): string {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}`
}

/** 从 ISO 字符串取本地 HH:MM(本地时区)。无效返回空串。 */
export function formatLocalHHMM(iso: string | undefined | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`
}

/** 从 ISO 字符串取本地 YYYY-MM-DD(实际创建日期)。无效返回空串。 */
export function formatLocalYMD(iso: string | undefined | null): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  return formatLocalDate(d)
}

export function todayLocal(): string {
  return formatLocalDate(new Date())
}

/** 'YYYY-MM' → 'YYYY 年 M 月'。月份去前导零;年保留。 */
export function formatMonthCN(month: string): string {
  const [y, m] = month.split('-')
  return `${y} 年 ${parseInt(m, 10)} 月`
}

/**
 * 日组标签:今天/昨天 用本地化前缀,其他直接「M 月 D 日」。
 * 用本地时区比较,跟 recordDate(YYYY-MM-DD,本地)对齐。
 */
export function formatRelativeDayLabel(
  iso: string,
  today: Date,
  t: { today: string; yesterday: string },
): string {
  const d = new Date(iso)
  const monthDay = `${d.getMonth() + 1}月${d.getDate()}日`
  const sameDay = (a: Date, b: Date): boolean =>
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  if (sameDay(d, today)) return `${t.today}, ${monthDay}`
  const y = new Date(today)
  y.setDate(today.getDate() - 1)
  if (sameDay(d, y)) return `${t.yesterday}, ${monthDay}`
  return monthDay
}

/** 记录排序:按 recordDate 倒序,同日内按 createdAt 倒序(最新在前)。给首页 / 流水共用。 */
export function compareRecordDesc(
  a: { recordDate: string; createdAt: string },
  b: { recordDate: string; createdAt: string },
): number {
  if (a.recordDate !== b.recordDate) return a.recordDate < b.recordDate ? 1 : -1
  return a.createdAt < b.createdAt ? 1 : -1
}

function pad2(n: number): string {
  return String(n).padStart(2, '0')
}
