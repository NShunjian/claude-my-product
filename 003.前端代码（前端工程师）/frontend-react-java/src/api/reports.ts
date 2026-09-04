import { request } from '../lib/api'

export interface CategoryTotal {
  categoryId: string
  name: string
  icon: string
  color: string
  total: number
}

export interface DailyPoint {
  /** 1-31 */
  day: number
  income: number
  expense: number
}

export interface MonthlyReport {
  month: string // 'YYYY-MM'
  totalIncome: number
  totalExpense: number
  netSavings: number
  lastMonth: {
    totalIncome: number
    totalExpense: number
    netSavings: number
  } | null
  incomeByCategory: CategoryTotal[]
  expenseByCategory: CategoryTotal[]
  dailyData: DailyPoint[]
}

export interface MonthlyReportResponse extends MonthlyReport {}

export interface MonthlyPoint {
  /** 1-12 */
  month: number
  income: number
  expense: number
}

export interface YearlyReport {
  year: number
  totalIncome: number
  totalExpense: number
  netSavings: number
  monthlyData: MonthlyPoint[]
  incomeByCategory: CategoryTotal[]
  expenseByCategory: CategoryTotal[]
}

export interface YearlyReportResponse extends YearlyReport {}

export async function getMonthlyReport(
  month: string,
  bookId?: string,
): Promise<MonthlyReport> {
  const sp = new URLSearchParams({ month })
  if (bookId) sp.set('bookId', bookId)
  const res = await request<MonthlyReportResponse>(`/api/reports/monthly?${sp.toString()}`)
  return res
}

export async function getYearlyReport(year: number, bookId?: string): Promise<YearlyReport> {
  const sp = new URLSearchParams({ year: String(year) })
  if (bookId) sp.set('bookId', bookId)
  const res = await request<YearlyReportResponse>(`/api/reports/yearly?${sp.toString()}`)
  return res
}
