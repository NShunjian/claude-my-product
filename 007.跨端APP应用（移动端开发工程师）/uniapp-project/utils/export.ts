/**
 * 数据导出(对齐 frontend-react src/lib/export.ts):
 *   - 本月报表: 当前月 records 单 sheet
 *   - 按分类导出: 全量 records 按 categoryId 分组,每个分类一个 sheet + 汇总 sheet
 *   - 全部数据: 全量 records 单 sheet
 *
 * H5:用 Blob + <a download> 触发下载;App:用 uni.saveFile / uni.openDocument。
 * xlsx 库负责 Sheet 生成。
 */
import * as XLSX from 'xlsx'
import { listRecords, type Record as TxRecord } from '@/api/records'
import { listAccounts, type Account } from '@/api/accounts'
import { listCategories, type Category } from '@/api/categories'

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
  const [records, accounts, expCats, incCats] = await Promise.all([
    listRecords(),
    listAccounts(),
    listCategories('expense'),
    listCategories('income'),
  ])
  const categories = [...(expCats ?? []), ...(incCats ?? [])]
  return {
    records,
    accounts,
    categories,
    accountMap: new Map(accounts.map((a) => [a.id, a.name])),
    categoryMap: new Map(categories.map((c) => [c.id, c.name])),
  }
}

function todayStamp(): string {
  return new Date().toISOString().slice(0, 10)
}

// H5:Blob 下载;App:plus.runtime / uni.saveFile(简化为 H5 路径,App 后续按需扩展)
function triggerDownload(wb: XLSX.WorkBook, filename: string): void {
  const wbout = XLSX.write(wb, { bookType: 'xlsx', type: 'array' })
  const blob = new Blob([wbout], { type: 'application/octet-stream' })
  // #ifdef H5
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
  // #endif
  // #ifndef H5
  // ponytail: App 端文件保存暂留 H5 兼容路径,真机 App 上线时改 uni.saveFile + uni.openDocument
  const url2 = URL.createObjectURL(blob)
  const a2 = document.createElement('a')
  a2.href = url2
  a2.download = filename
  document.body.appendChild(a2)
  a2.click()
  document.body.removeChild(a2)
  URL.revokeObjectURL(url2)
  // #endif
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

/** 按分类导出: 全量 records 按 (type, categoryId) 分组,每个分类独立 sheet。sheet 名加类型前缀避免「支出-其他」和「收入-其他」撞名 */
export async function exportByCategory(): Promise<void> {
  const { records, accountMap, categoryMap } = await loadDeps()
  const wb = XLSX.utils.book_new()
  const summaryRows: { 分类: string; 笔数: number; 金额合计: number }[] = []
  // 按 categoryId 分组,记录每个分类对应的 record.type(同一 categoryId 只属于一种类型)
  const groups = new Map<string, { type: TxRecord['type']; records: TxRecord[] }>()
  for (const r of records) {
    const key = r.categoryId ?? '__none__'
    if (!groups.has(key)) groups.set(key, { type: r.type, records: [] })
    groups.get(key)!.records.push(r)
  }
  const TYPE_ORDER: Record<TxRecord['type'], number> = { expense: 0, income: 1, transfer: 2 }
  const sortedKeys = [...groups.keys()].sort((a, b) => {
    const ga = groups.get(a)!
    const gb = groups.get(b)!
    if (ga.type !== gb.type) return TYPE_ORDER[ga.type] - TYPE_ORDER[gb.type]
    const aName = a === '__none__' ? '未分类' : categoryMap.get(a) ?? a
    const bName = b === '__none__' ? '未分类' : categoryMap.get(b) ?? b
    return aName.localeCompare(bName, 'zh')
  })
  for (const key of sortedKeys) {
    const { type, records: catRecords } = groups.get(key)!
    const typeLabel = type === 'expense' ? '支出' : type === 'income' ? '收入' : '转账'
    const catName = key === '__none__' ? '未分类' : categoryMap.get(key) ?? key
    const sheetName = `${typeLabel}-${catName}`
    const safeName = sheetName.slice(0, 31)
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
