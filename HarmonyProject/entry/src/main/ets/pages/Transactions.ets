/**
 * 流水页:按截图 1 设计 — 周/月/年/全部 period tabs + filter row + 分类汇总柱状图列表。
 * ponytail: listRecords API 只支持 month,周/年/全部走 all=true 再客户端按 period 过滤 + 分类聚合。
 */
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { useLanguage } from '../i18n/useLanguage'
import { getAuth } from '../stores/auth'
import { getBook } from '../stores/book'
import { getToast } from '../stores/toast'
import { listRecords } from '../api/records'
import { listAccounts } from '../api/accounts'
import { listCategories } from '../api/categories'
import { formatAmount } from '../utils/finance'
import { formatLocalDate, formatLocalMonth } from '../utils/date'
import { consumePendingMonth } from '../utils/nav-intent'
import type { Record, Account, Category } from '../model/Types'

type Period = 'week' | 'month' | 'year' | 'all'

class CatBreakdownRow {
  catId: string = ''
  name: string = ''
  icon: string = ''
  color: string = ''
  amount: number = 0
  count: number = 0
  pct: number = 0
  constructor(catId: string, name: string, icon: string, color: string, amount: number, count: number, pct: number) {
    this.catId = catId; this.name = name; this.icon = icon; this.color = color
    this.amount = amount; this.count = count; this.pct = pct
  }
}

class DateRange {
  start: string = ''
  end: string = ''
  constructor(start: string, end: string) {
    this.start = start
    this.end = end
  }
}

class CatAggregate {
  amount: number = 0
  count: number = 0
  constructor(amount: number, count: number) {
    this.amount = amount
    this.count = count
  }
}

function weekRange(d: Date): DateRange {
  const day = d.getDay()
  const offset = day === 0 ? 6 : day - 1
  const s = new Date(d); s.setDate(d.getDate() - offset)
  const e = new Date(s); e.setDate(s.getDate() + 6)
  return new DateRange(formatLocalDate(s), formatLocalDate(e))
}

function yearRange(d: Date): DateRange {
  const y = d.getFullYear()
  return new DateRange(`${y}-01-01`, `${y}-12-31`)
}

function monthRange(d: Date): DateRange {
  const y = d.getFullYear(); const m = d.getMonth() + 1
  const lastDay = new Date(y, m, 0).getDate()
  return new DateRange(
    `${y}-${String(m).padStart(2, '0')}-01`,
    `${y}-${String(m).padStart(2, '0')}-${lastDay}`,
  )
}

function rangeOf(period: Period, now: Date): DateRange | null {
  if (period === 'week') return weekRange(now)
  if (period === 'month') return monthRange(now)
  if (period === 'year') return yearRange(now)
  return null
}

@Entry
@Component
export struct Transactions {
  @State period: Period = 'month'
  @State filterCategory: string = 'all'
  @State filterAccount: string = 'all'
  @State records: Record[] = []
  @State accounts: Account[] = []
  @State cats: Category[] = []
  @State loading: boolean = false
  @State showCategoryPicker: boolean = false
  @State showAccountPicker: boolean = false

  private lang = useLanguage()

  aboutToAppear() {
    consumePendingMonth()
    this.load()
  }

  private async load() {
    const auth = getAuth(); const book = getBook()
    if (!auth.token || !book.current) return
    this.loading = true
    try {
      const useMonth = this.period === 'month'
      const monthStr = useMonth ? formatLocalMonth(new Date()) : ''
      const result = await Promise.all([
        listRecords({ bookId: book.current.uuid, month: useMonth ? monthStr : undefined, all: !useMonth }),
        listAccounts({ bookId: book.current.uuid }),
        listCategories('expense'),
        listCategories('income'),
      ])
      this.records = result[0]
      this.accounts = result[1]
      this.cats = result[2].concat(result[3])
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      getToast()?.show(this.lang.t('transactions.loadErrorPrefix') + msg)
    } finally { this.loading = false }
  }

  private periodFiltered(): Record[] {
    const r = rangeOf(this.period, new Date())
    let out = this.records
    if (r) {
      out = out.filter(x => x.recordDate >= r.start && x.recordDate <= r.end)
    }
    if (this.filterCategory !== 'all') {
      out = out.filter(x => x.categoryId === this.filterCategory)
    }
    if (this.filterAccount !== 'all') {
      out = out.filter(x => x.accountId === this.filterAccount)
    }
    return out
  }

  private breakdown(): CatBreakdownRow[] {
    const filtered = this.periodFiltered().filter(r => r.type === 'expense')
    const map = new Map<string, CatAggregate>()
    for (const r of filtered) {
      if (!r.categoryId) continue
      const cur = map.get(r.categoryId) ?? new CatAggregate(0, 0)
      cur.amount += r.amount
      cur.count += 1
      map.set(r.categoryId, cur)
    }
    const rows: CatBreakdownRow[] = []
    let max = 0
    for (const entry of map.entries()) {
      const c = this.cats.find(x => x.id === entry[0])
      if (!c) continue
      const v = entry[1].amount
      if (v > max) max = v
      rows.push(new CatBreakdownRow(c.id, c.name, c.icon || '⋯', c.color, v, entry[1].count, 0))
    }
    rows.sort((a, b) => b.amount - a.amount)
    for (const row of rows) row.pct = max > 0 ? (row.amount / max) * 100 : 0
    return rows
  }

  private totalExpense(): number {
    let s = 0
    for (const r of this.periodFiltered()) if (r.type === 'expense') s += r.amount
    return s
  }
  private totalIncome(): number {
    let s = 0
    for (const r of this.periodFiltered()) if (r.type === 'income') s += r.amount
    return s
  }

  private categoryLabel(): string {
    if (this.filterCategory === 'all') return this.lang.t('transactions.allCategories')
    return this.cats.find(c => c.id === this.filterCategory)?.name ?? this.lang.t('transactions.allCategories')
  }
  private accountLabel(): string {
    if (this.filterAccount === 'all') return this.lang.t('transactions.allAccounts')
    return this.accounts.find(a => a.id === this.filterAccount)?.name ?? this.lang.t('transactions.allAccounts')
  }

  build() {
    Column() {
      AppHeader({ title: this.lang.t('pageTitle.transactions') })

      // Period tabs
      Row() {
        this.periodTab('week', this.lang.t('transactions.periodWeek'))
        this.periodTab('month', this.lang.t('transactions.periodMonth'))
        this.periodTab('year', this.lang.t('transactions.periodYear'))
        this.periodTab('all', this.lang.t('transactions.periodAll'))
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 })

      Scroll() {
        Column() {
          // Filter row
          Row() {
            Row() {
              Text(this.categoryLabel()).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.text)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(' ▼').fontSize(11)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            }
            .layoutWeight(1)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
            .borderRadius(8)
            .onClick(() => { this.showCategoryPicker = true })

            Row() {
              Text(this.accountLabel()).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.text)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(' ▼').fontSize(11)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            }
            .layoutWeight(1)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
            .borderRadius(8)
            .margin({ left: 8 })
            .onClick(() => { this.showAccountPicker = true })
          }
          .width('100%').padding({ left: 16, right: 16, top: 12 })

          // Summary
          Row() {
            Column() {
              Text(this.lang.t('transactions.expense')).fontSize(12)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
              Text(`¥ ${formatAmount(this.totalExpense())}`).fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor(resolveTheme(themeStore.effective).colors.error)
                .margin({ top: 4 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)

            Column() {
              Text(this.lang.t('transactions.income')).fontSize(12)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
              Text(`¥ ${formatAmount(this.totalIncome())}`).fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor('#006d40')
                .margin({ top: 4 })
            }.layoutWeight(1).alignItems(HorizontalAlign.End)
          }
          .width('100%').padding(16).margin({ left: 16, right: 16, top: 12 })
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(12)
          .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })

          // Category breakdown list
          Column() {
            if (this.loading) {
              Text(this.lang.t('transactions.loading')).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .padding(40).width('100%').textAlign(TextAlign.Center)
            } else if (this.breakdown().length === 0) {
              Text(this.lang.t('transactions.noDataInPeriod')).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .padding(40).width('100%').textAlign(TextAlign.Center)
            } else {
              ForEach(this.breakdown(), (row: CatBreakdownRow) => {
                this.catRow(row)
              }, (row: CatBreakdownRow) => row.catId)
            }
          }
          .width('100%').margin({ left: 16, right: 16, top: 12 })
          .padding(8)
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(12)
          .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })

          Row().height(56)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // Category picker overlay
      if (this.showCategoryPicker) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#00000066')
            .onClick(() => { this.showCategoryPicker = false })
          Column() {
            Text(this.lang.t('transactions.allCategories')).fontSize(14)
              .fontWeight(FontWeight.Medium)
              .padding(12).width('100%')
              .onClick(() => { this.filterCategory = 'all'; this.showCategoryPicker = false })
            ForEach(this.cats, (c: Category) => {
              Text(c.name).fontSize(14)
                .padding(12).width('100%')
                .onClick(() => { this.filterCategory = c.id; this.showCategoryPicker = false })
            }, (c: Category) => c.id)
          }
          .width('70%').backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(12).padding(8)
        }.width('100%').height('100%')
      }

      // Account picker overlay
      if (this.showAccountPicker) {
        Stack({ alignContent: Alignment.Center }) {
          Column().width('100%').height('100%').backgroundColor('#00000066')
            .onClick(() => { this.showAccountPicker = false })
          Column() {
            Text(this.lang.t('transactions.allAccounts')).fontSize(14)
              .fontWeight(FontWeight.Medium)
              .padding(12).width('100%')
              .onClick(() => { this.filterAccount = 'all'; this.showAccountPicker = false })
            ForEach(this.accounts, (a: Account) => {
              Text(a.name).fontSize(14)
                .padding(12).width('100%')
                .onClick(() => { this.filterAccount = a.id; this.showAccountPicker = false })
            }, (a: Account) => a.id)
          }
          .width('70%').backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(12).padding(8)
        }.width('100%').height('100%')
      }
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }

  @Builder periodTab(p: Period, label: string) {
    Text(label).fontSize(14)
      .fontWeight(this.period === p ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.period === p ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
      .backgroundColor(this.period === p ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.bgCard)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .borderRadius(20)
      .border({
        width: 1,
        color: this.period === p ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.divider,
      })
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .margin({ right: 8 })
      .onClick(() => {
        if (this.period !== p) {
          this.period = p
          this.load()
        }
      })
  }

  @Builder catRow(row: CatBreakdownRow) {
    Column() {
      Row() {
        Text(row.icon).fontSize(18).fontColor(row.color)
        Text(row.name).fontSize(14).layoutWeight(1).margin({ left: 8 })
          .fontColor(resolveTheme(themeStore.effective).colors.text)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`¥ ${formatAmount(row.amount)}`).fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
      }
      .width('100%')

      Row() {
        Row().height(4)
          .width(`${row.pct}%`)
          .backgroundColor(row.color)
          .borderRadius(2)
      }
      .width('100%').height(4)
      .backgroundColor(resolveTheme(themeStore.effective).colors.divider)
      .borderRadius(2)
      .margin({ top: 4 })

      Text(this.lang.t('transactions.recordCount').replace('{n}', String(row.count)))
        .fontSize(11)
        .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
        .margin({ top: 4 })
    }
    .width('100%').padding(8)
  }
}