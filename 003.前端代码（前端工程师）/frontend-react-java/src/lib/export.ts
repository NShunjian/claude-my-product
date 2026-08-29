/**
 * 数据导出工具(最小可工作版 — 客户端生成 xlsx):
 *   - 本月报表: 当前月 records 单 sheet
 *   - 按分类导出: 全量 records 按 categoryId 分组,每个分类一个 sheet,无分类的归入"(未分类)"
 *   - 全部数据: 全量 records 单 sheet
 *
 * 不写后端;前端从已有 records/accounts/categories API 拉数据拼装,
 * xlsx 库负责 Sheet 生成,writeFile() 触发浏览器下载。
 */
import * as XLSX from 'xlsx'
import { listRecords, type Record as TxRecord } from '../api/records'
import { listAccounts, type Account } from '../api/accounts'
import { listCategories, type Category } from '../api/categories'

interface RecordRow {
  日期: string
  类型: '支出' | '收入' | '转账'
  分类: string
  账户: string
  转入账户: string
  金额: number
  币种: string
  备注: string
}

const TYPE_LABEL: Record<TxRecord['type'], '支出' | '收入' | '转账'> = {
  expense: '支出',
  income: '收入',
  transfer: '转账',
}

function recordsToRows(
  records: TxRecord[],
  accountMap: Map<string, string>,
  categoryMap: Map<string, string>,
): RecordRow[] {
  return records.map((r) => ({
    日期: r.recordDate,
    类型: TYPE_LABEL[r.type],
    分类: r.categoryId ? (categoryMap.get(r.categoryId) ?? r.categoryId) : '',
    账户: accountMap.get(r.accountId) ?? r.accountId,
    转入账户: r.toAccountId ? (accountMap.get(r.toAccountId) ?? r.toAccountId) : '',
    金额: r.amount,
    币种: r.currency,
    备注: r.note ?? '',
  }))
}

async function loadDeps(): Promise<{
  records: TxRecord[]
  accounts: Account[]
  categories: Category[]
  accountMap: Map<string, string>
  categoryMap: Map<string, string>
}> {
  const [records, accounts, categories] = await Promise.all([
    listRecords(),
    listAccounts(),
    listCategories(),
  ])
  return {
    records,
    accounts,
    categories,
    accountMap: new Map(accounts.map((a) => [a.id, a.name])),
    categoryMap: new Map(categories.map((c) => [c.id, c.name])),
  }
}

function triggerDownload(wb: XLSX.WorkBook, filename: string): void {
  XLSX.writeFile(wb, filename)
}

function todayStamp(): string {
  return new Date().toISOString().slice(0, 10)
}

/** 导出本月报表: 当前月 records 单 sheet */
export async function exportMonthly(): Promise<void> {
  const month = todayStamp().slice(0, 7)
  const { records, accountMap, categoryMap } = await loadDeps()
  const monthRecords = records.filter((r) => r.recordDate.startsWith(month))
  const rows = recordsToRows(monthRecords, accountMap, categoryMap)
  const ws = XLSX.utils.json_to_sheet(rows)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, `${month} 月度流水`)
  triggerDownload(wb, `轻账-${month}月报表-${todayStamp()}.xlsx`)
}

/** 按分类导出: 全量 records 按 categoryId 分组,每个分类独立 sheet */
export async function exportByCategory(): Promise<void> {
  const { records, accountMap, categoryMap } = await loadDeps()
  const wb = XLSX.utils.book_new()
  // 分类聚合表(总计 sheet)
  const summaryRows: { 分类: string; 笔数: number; 金额合计: number }[] = []
  const groups = new Map<string, TxRecord[]>()
  for (const r of records) {
    const key = r.categoryId ?? '__none__'
    if (!groups.has(key)) groups.set(key, [])
    groups.get(key)!.push(r)
  }
  // 稳定排序:已识别的分类按 name 升序,未分类垫底
  const sortedKeys = [...groups.keys()].sort((a, b) => {
    if (a === '__none__') return 1
    if (b === '__none__') return -1
    return (categoryMap.get(a) ?? a).localeCompare(categoryMap.get(b) ?? b, 'zh')
  })
  for (const key of sortedKeys) {
    const catRecords = groups.get(key)!
    const sheetName = key === '__none__' ? '未分类' : categoryMap.get(key) ?? key
    const safeName = sheetName.slice(0, 31) // Excel sheet 名 ≤31 字符
    const rows = recordsToRows(catRecords, accountMap, categoryMap)
    const ws = XLSX.utils.json_to_sheet(rows)
    XLSX.utils.book_append_sheet(wb, ws, safeName)
    const total = catRecords.reduce((s, r) => s + r.amount, 0)
    summaryRows.push({ 分类: sheetName, 笔数: catRecords.length, 金额合计: total })
  }
  if (summaryRows.length > 0) {
    const summaryWs = XLSX.utils.json_to_sheet(summaryRows)
    XLSX.utils.book_append_sheet(wb, summaryWs, '汇总')
  }
  triggerDownload(wb, `轻账-按分类导出-${todayStamp()}.xlsx`)
}

/** 导出全部数据: 全量 records 单 sheet */
export async function exportAll(): Promise<void> {
  const { records, accountMap, categoryMap } = await loadDeps()
  const rows = recordsToRows(records, accountMap, categoryMap)
  const ws = XLSX.utils.json_to_sheet(rows)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, '全部交易')
  triggerDownload(wb, `轻账-全部数据-${todayStamp()}.xlsx`)
}