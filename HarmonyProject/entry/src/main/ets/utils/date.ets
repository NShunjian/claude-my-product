/**
 * 日期工具:与 uniapp utils/date.ts 1:1 对齐。
 * ponytail: 不引第三方,纯函数。
 */

function pad(n: number, w: number = 2): string { return n.toString().padStart(w, '0') }

export function formatLocalDate(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export function formatLocalMonth(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}`
}

export function formatLocalHHMM(d: Date): string { return `${pad(d.getHours())}:${pad(d.getMinutes())}` }

export function formatLocalYMD(d: Date): string {
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`
}

export function todayLocal(): string { return formatLocalDate(new Date()) }

function splitYearMonth(month: string): number[] {
  const parts = month.split('-')
  const y = Number(parts[0])
  const m = Number(parts[1])
  return [y, m]
}

export function formatMonthCN(month: string): string {
  const parts = splitYearMonth(month)
  const y = parts[0]
  const m = parts[1]
  return `${y}年${m}月`
}

export class DayLabels {
  today: string
  yesterday: string
  constructor(today: string, yesterday: string) {
    this.today = today
    this.yesterday = yesterday
  }
}

export function formatRelativeDayLabel(date: string, today: Date, labels: DayLabels): string {
  const todayStr = formatLocalDate(today)
  const y = new Date(today)
  y.setDate(y.getDate() - 1)
  const yStr = formatLocalDate(y)
  if (date === todayStr) return labels.today
  if (date === yStr) return labels.yesterday
  const d = new Date(date)
  if (Number.isNaN(d.getTime())) return date
  return `${d.getMonth() + 1}月${d.getDate()}日`
}

export interface RecordLike { recordDate: string; createdAt?: string; id: string }

export function compareRecordDesc(a: RecordLike, b: RecordLike): number {
  if (a.recordDate !== b.recordDate) return a.recordDate < b.recordDate ? 1 : -1
  const ac = a.createdAt ?? ''
  const bc = b.createdAt ?? ''
  if (ac !== bc) return ac < bc ? 1 : -1
  return a.id < b.id ? 1 : -1
}

export function daysInMonth(month: string): number {
  const parts = splitYearMonth(month)
  const y = parts[0]
  const m = parts[1]
  return new Date(y, m, 0).getDate()
}

export function addMonths(month: string, delta: number): string {
  const parts = splitYearMonth(month)
  const y = parts[0]
  const m = parts[1]
  const d = new Date(y, m - 1 + delta, 1)
  return formatLocalMonth(d)
}

export function weekdayCN(date: string): string {
  const d = new Date(date)
  if (Number.isNaN(d.getTime())) return ''
  return ['日', '一', '二', '三', '四', '五', '六'][d.getDay()]
}

export function formatDayHeaderCN(ymd: string): string {
  const d = new Date(ymd)
  if (Number.isNaN(d.getTime())) return ymd
  return `${d.getMonth() + 1}月${d.getDate()}日,星期${weekdayCN(ymd)}`
}