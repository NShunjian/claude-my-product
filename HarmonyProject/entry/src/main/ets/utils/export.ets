/**
 * 数据导出:对齐 uniapp utils/export.ts (xlsx 版)。
 * ponytail: HarmonyOS 没原生 xlsx,用 CSV(Excel 可直接打开)替代 + 系统分享。
 */
import { fileIo } from '@kit.CoreFileKit'
import { systemShare } from '@kit.ShareKit'
import { listRecords } from '../api/records'
import { listAccounts } from '../api/accounts'
import { listCategories } from '../api/categories'
import { getSystemVersion } from '../api/version'
import { formatAmount } from './finance'
import { todayLocal, formatLocalMonth } from './date'
import { getBook } from '../stores/book'
import { getCtx } from './context'
import type { Record, SystemVersion } from '../model/Types'

function csvEscape(v: string): string {
  if (v.includes(',') || v.includes('"') || v.includes('\n')) {
    return `"${v.replace(/"/g, '""')}"`
  }
  return v
}

function rowsToCsv(headers: string[], rows: string[][]): string {
  const lines = [headers.map(csvEscape).join(',')]
  for (const r of rows) lines.push(r.map(csvEscape).join(','))
  return lines.join('\n')
}

class ShareSelectionOption {
  selectionMode: systemShare.SelectionMode
  constructor(m: systemShare.SelectionMode) { this.selectionMode = m }
}

class UnknownVersion {
  version: string
  constructor() { this.version = 'unknown' }
}

async function saveAndShare(filename: string, content: string): Promise<void> {
  const ctx = getCtx()
  const cacheDir = ctx.cacheDir
  const filePath = `${cacheDir}/${filename}`
  const file = fileIo.openSync(filePath,
    fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
  fileIo.writeSync(file.fd, content)
  fileIo.closeSync(file.fd)
  const record: systemShare.SharedRecord = {
    utd: 'text/plain',
    title: filename,
    uri: `file://${filePath}`,
  }
  const shareData: systemShare.SharedData = new systemShare.SharedData(record)
  const controller: systemShare.ShareController = new systemShare.ShareController(shareData)
  const opt: ShareSelectionOption = new ShareSelectionOption(systemShare.SelectionMode.SINGLE)
  await controller.show(ctx, opt)
}

function typeOf(t: string): string { return t === 'income' ? '收入' : '支出' }

interface RecForTotal { type: string; categoryId: string; amount: number }

function buildTotalsMap(recs: RecForTotal[], type: string): Map<string, number> {
  const m = new Map<string, number>()
  for (const r of recs) {
    if (r.type !== type) continue
    m.set(r.categoryId, (m.get(r.categoryId) ?? 0) + r.amount)
  }
  return m
}

export async function exportMonthly(): Promise<void> {
  const book = getBook()
  if (!book.current) throw new Error('no book selected')
  const month = formatLocalMonth(new Date())
  const recsRes = await Promise.all([
    listRecords({ month, bookId: book.current.uuid }),
    listAccounts({ bookId: book.current.uuid }),
    listCategories('expense'),
    listCategories('income'),
  ])
  const recs: Record[] = recsRes[0]
  const accounts = recsRes[1]
  const catsE = recsRes[2]
  const catsI = recsRes[3]
  const accMap = new Map(accounts.map(a => [a.id, a.name]))
  const catMap = new Map<string, string>()
  for (const c of catsE) catMap.set(c.id, c.name)
  for (const c of catsI) catMap.set(c.id, c.name)
  const rows: string[][] = []
  for (const r of recs) {
    rows.push([
      r.recordDate, typeOf(r.type),
      accMap.get(r.accountId) ?? '',
      catMap.get(r.categoryId) ?? '',
      formatAmount(r.amount), r.note ?? '',
    ])
  }
  await saveAndShare(`流水_${month}.csv`,
    rowsToCsv(['日期', '类型', '账户', '分类', '金额', '备注'], rows))
}

export async function exportByCategory(): Promise<void> {
  const book = getBook()
  if (!book.current) throw new Error('no book selected')
  const month = formatLocalMonth(new Date())
  const res = await Promise.all([
    listRecords({ month, bookId: book.current.uuid }),
    listCategories('expense'),
    listCategories('income'),
  ])
  const recs: Record[] = res[0]
  const catsE = res[1]
  const catsI = res[2]
  const expenseTotals = buildTotalsMap(recs, 'expense')
  const incomeTotals = buildTotalsMap(recs, 'income')
  const rows: string[][] = []
  for (const c of catsE) {
    const t = expenseTotals.get(c.id) ?? 0
    rows.push([c.name, '支出', formatAmount(t), String(t)])
  }
  for (const c of catsI) {
    const t = incomeTotals.get(c.id) ?? 0
    rows.push([c.name, '收入', formatAmount(t), String(t)])
  }
  await saveAndShare(`分类汇总_${month}.csv`,
    rowsToCsv(['分类', '类型', '金额', '原始金额'], rows))
}

export async function exportAll(): Promise<void> {
  const book = getBook()
  if (!book.current) throw new Error('no book selected')
  const res = await Promise.all([
    listRecords({ month: 'all', bookId: book.current.uuid, all: true }),
    listAccounts({ bookId: book.current.uuid }),
    listCategories('expense'),
    listCategories('income'),
    getSystemVersion().catch((): SystemVersion => new UnknownVersion() as SystemVersion),
  ])
  const recs: Record[] = res[0]
  const accounts = res[1]
  const catsE = res[2]
  const catsI = res[3]
  const ver: SystemVersion = res[4]
  const accMap = new Map<string, string>()
  for (const a of accounts) accMap.set(a.id, `${a.name}(${a.type})`)
  const catMap = new Map<string, string>()
  for (const c of catsE) catMap.set(c.id, c.name)
  for (const c of catsI) catMap.set(c.id, c.name)
  const rows: string[][] = []
  for (const r of recs) {
    rows.push([
      r.recordDate, typeOf(r.type),
      accMap.get(r.accountId) ?? '',
      catMap.get(r.categoryId) ?? '',
      formatAmount(r.amount), r.note ?? '',
    ])
  }
  const header = `# QingZhang v${ver.version}\n# 导出时间 ${todayLocal()}\n`
  await saveAndShare(`全量流水_${todayLocal()}.csv`,
    header + rowsToCsv(['日期', '类型', '账户', '分类', '金额', '备注'], rows))
}

export type ExportMode = 'monthly' | 'category' | 'all'
export interface ExportParams { mode: ExportMode; bookId: string }

export async function exportToCsv(params: ExportParams): Promise<void> {
  if (params.mode === 'monthly') return exportMonthly()
  if (params.mode === 'category') return exportByCategory()
  return exportAll()
}
