/**
 * 报表 API:对齐 uniapp api/reports.ts 1:1。
 */
import { request } from './http'
import type { MonthlyReport, YearlyReport } from '../model/Types'

export interface MonthlyReportParams { month: string; bookId: string }
export interface YearlyReportParams { year: number; bookId: string }

export function getMonthlyReport(params: MonthlyReportParams): Promise<MonthlyReport> {
  return request<MonthlyReport>(`/reports/monthly?month=${encodeURIComponent(params.month)}&bookId=${encodeURIComponent(params.bookId)}`)
}

export function getYearlyReport(params: YearlyReportParams): Promise<YearlyReport> {
  return request<YearlyReport>(`/reports/yearly?year=${params.year}&bookId=${encodeURIComponent(params.bookId)}`)
}