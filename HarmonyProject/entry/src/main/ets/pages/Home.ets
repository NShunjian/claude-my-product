/**
 * 首页:对齐 uniapp pages/index/index.vue 1:1。
 */
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { MonthPicker } from '../components/MonthPicker'
import { TransactionRow } from '../components/TransactionRow'
import { useLanguage } from '../i18n/useLanguage'
import { getAuth } from '../stores/auth'
import { getBook } from '../stores/book'
import { getToast } from '../stores/toast'
import { listRecords } from '../api/records'
import { listAccounts } from '../api/accounts'
import { listCategories } from '../api/categories'
import { formatAmount } from '../utils/finance'
import { formatMonthCN, formatRelativeDayLabel, compareRecordDesc, DayLabels } from '../utils/date'
import { categoryPresentation, CategoryLike } from '../utils/category-presentation'
import { quickAddStore } from '../stores/quick-add'
import { setPendingMonth } from '../utils/nav-intent'
import type { Record, Account, Category } from '../model/Types'

interface CatRow { cat: Category; icon: string; color: string; total: number }

class DayGroup {
  date: string
  recs: Record[]
  net: number
  label: string
  constructor(date: string, recs: Record[], net: number, label: string) {
    this.date = date; this.recs = recs; this.net = net; this.label = label
  }
}

@Entry
@Component
export struct Home {
  @State @Watch('onMonthChange') month: string = ''
  @State records: Record[] = []
  @State accounts: Account[] = []
  @State cats: Category[] = []
  @State loading: boolean = false

  private lang = useLanguage()
  private initialLoadDone: boolean = false

  aboutToAppear() {
    const d = new Date()
    this.month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    this.initialLoadDone = true
    this.load()
  }

  private onMonthChange() { if (this.initialLoadDone) this.load() }

  async load() {
    const auth = getAuth(); const book = getBook()
    if (!auth.token || !book.current) return
    this.loading = true
    try {
      const res = await Promise.all([
        listRecords({ month: this.month, bookId: book.current.uuid }),
        listAccounts({ bookId: book.current.uuid }),
        listCategories('expense'),
        listCategories('income'),
      ])
      this.records = res[0]
      this.accounts = res[1]
      const exp = res[2]; const inc = res[3]
      this.cats = exp.concat(inc)
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      getToast()?.show(this.lang.t('home.loadErrorPrefix') + msg)
    } finally { this.loading = false }
  }

  private monthIncome(): number {
    let s = 0
    for (const r of this.records) if (r.type === 'income') s += r.amount
    return s
  }
  private monthExpense(): number {
    let s = 0
    for (const r of this.records) if (r.type === 'expense') s += r.amount
    return s
  }
  private totalAssets(): number {
    let s = 0
    for (const a of this.accounts) s += a.balance
    return s
  }

  private recent(): Record[] {
    const sorted = this.records.slice().sort(compareRecordDesc)
    return sorted.slice(0, 5)
  }

  private grouped(): DayGroup[] {
    const map = new Map<string, Record[]>()
    for (const r of this.recent()) {
      if (!r || !r.id) continue
      const key = r.recordDate
      const arr = map.get(key)
      if (arr) arr.push(r)
      else map.set(key, [r])
    }
    const today = new Date()
    const labels: DayLabels = new DayLabels(this.lang.t('home.today'), this.lang.t('home.yesterday'))
    const out: DayGroup[] = []
    for (const entry of map.entries()) {
      const date = entry[0]
      const recs = entry[1]
      let net = 0
      for (const r of recs) net += (r.type === 'income' ? r.amount : -r.amount)
      const g: DayGroup = new DayGroup(
        date, recs, net,
        formatRelativeDayLabel(date, today, labels),
      )
      out.push(g)
    }
    return out
  }

  private byCat(type: 'expense' | 'income'): CatRow[] {
    const filtered = this.cats.filter(c => c.type === type)
    const rows: CatRow[] = []
    for (const c of filtered) {
      const catLike: CategoryLike = { name: c.name, type: c.type, icon: c.icon, color: c.color, isPreset: c.isPreset }
      const pres = categoryPresentation(catLike)
      let total = 0
      for (const r of this.records) {
        if (r.type === type && r.categoryId === c.id) total += r.amount
      }
      const row: CatRow = { cat: c, icon: pres.icon, color: pres.color, total: total }
      rows.push(row)
    }
    rows.sort((a: CatRow, b: CatRow) => b.total - a.total)
    return rows
  }

  private findAccount(id: string): Account | undefined { return this.accounts.find(a => a.id === id) }
  private findCat(id: string | null): Category | undefined { return id ? this.cats.find(c => c.id === id) : undefined }

  build() {
    Column() {
      AppHeader({ title: this.lang.t('pageTitle.home') })

      Scroll() {
        Column() {
          Row() {
            Column() {
              Text(this.lang.t('home.overview')).fontSize(22).fontWeight(FontWeight.Bold)
                .fontColor(resolveTheme(themeStore.effective).colors.text)
              Text(formatMonthCN(this.month)).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .margin({ top: 2 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            MonthPicker({ value: $month }).width(160)
          }
          .width('100%').padding({ left: 16, right: 16 }).margin({ top: 12 })

          Column() {
            Text('💰').fontSize(64).opacity(0.12).position({ x: '70%', y: 8 })
            Text(this.lang.t('home.totalAssets')).fontSize(13)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            Row() {
              Text('¥').fontSize(20).fontColor(resolveTheme(themeStore.effective).colors.primary)
                .margin({ right: 4 })
              Text(formatAmount(this.totalAssets())).fontSize(36).fontWeight(FontWeight.Bold)
                .fontColor(resolveTheme(themeStore.effective).colors.primary)
            }
            .margin({ top: 8 }).alignItems(VerticalAlign.Bottom)

            Text(this.lang.t('home.accountsCount').replace('{n}', String(this.accounts.length)))
              .fontSize(12).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
              .margin({ top: 8 })

            Text(this.lang.t('home.quickAdd'))
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
              .width('100%').textAlign(TextAlign.Center)
              .padding(12)
              .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
              .borderRadius(8)
              .margin({ top: 12 })
              .onClick(() => quickAddStore.open('expense'))
          }
          .width('100%').padding(16).margin({ left: 16, right: 16, top: 12 })
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(16)

          Column() {
            this.kpi(this.lang.t('home.monthExpense'), formatAmount(this.monthExpense()), resolveTheme(themeStore.effective).colors.error)
            this.kpi(this.lang.t('home.monthIncome'), formatAmount(this.monthIncome()), '#10B981')
            this.balanceKpiRow()
          }
          .width('100%').padding({ left: 16, right: 16 }).margin({ top: 12 })

          Column() {
            Row() {
              Text(this.lang.t('home.recentTransactions')).fontSize(16).fontWeight(FontWeight.Bold)
                .layoutWeight(1)
              Text(`${this.lang.t('home.viewAll')} →`).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.primary)
                .onClick(() => { setPendingMonth(this.month); getToast()?.show('切换到流水页') })
            }
            .width('100%').padding(16)
            if (this.loading) {
              Text(this.lang.t('home.loading')).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .padding(16).width('100%').textAlign(TextAlign.Center)
            } else if (this.records.length === 0) {
              Text(this.lang.t('home.empty')).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .padding(24).width('100%').textAlign(TextAlign.Center)
            } else {
              ForEach(this.grouped(), (g: DayGroup) => {
                Column() {
                  Row() {
                    Text(g.label).fontSize(12).fontWeight(FontWeight.Medium)
                      .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                      .layoutWeight(1)
                    Text(`¥ ${formatAmount(Math.abs(g.net))}`).fontSize(12).fontWeight(FontWeight.Medium)
                      .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                  }
                  .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
                  ForEach(g.recs, (r: Record) => {
                    TransactionRow({ record: r, category: this.findCat(r.categoryId) ?? null, account: this.findAccount(r.accountId) ?? null })
                  }, (r: Record) => r.id)
                }
              }, (g: DayGroup) => g.date)
            }
          }
          .width('100%').margin({ top: 12 })
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(16)

          Row() {
            this.catBreakdown(this.lang.t('home.expenseByCategory'), this.byCat('expense'), this.monthExpense())
            this.catBreakdown(this.lang.t('home.incomeByCategory'), this.byCat('income'), this.monthIncome())
          }
          .width('100%').padding({ left: 16, right: 16 }).margin({ top: 12 })

          Row().height(56)
        }
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }

  @Builder kpi(label: string, value: string, color: string, sub: string = '') {
    Row() {
      Column() {
        Text(label).fontSize(13).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
        Row() {
          Text('¥').fontSize(16).fontColor(color).margin({ right: 4 })
          Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor(color)
        }
        .margin({ top: 4 }).alignItems(VerticalAlign.Bottom)
        if (sub) {
          Text(sub).fontSize(12).fontColor(color).margin({ top: 4 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(16).margin({ top: 8 })
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .borderRadius(12)
  }

  @Builder balanceKpiRow() {
    this.kpi(this.lang.t('home.monthBalance'), formatAmount(Math.abs(this.monthBalance())),
      this.balanceColor(), this.balanceSubLabel())
  }

  private monthBalance(): number { return this.monthIncome() - this.monthExpense() }
  private balanceColor(): string {
    return this.monthBalance() >= 0 ? '#10B981' : resolveTheme(themeStore.effective).colors.error
  }
  private balanceSubLabel(): string {
    return this.monthBalance() >= 0 ? this.lang.t('home.surplus') : this.lang.t('home.overBudget')
  }

  @Builder catBreakdown(title: string, rows: CatRow[], total: number) {
    Column() {
      Text(title).fontSize(15).fontWeight(FontWeight.Bold).margin({ bottom: 8 })
      if (rows.length === 0) {
        Text(this.lang.t('home.empty')).fontSize(11)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .padding(8).width('100%').textAlign(TextAlign.Center)
      } else {
        ForEach(rows, (r: CatRow) => {
          Column() {
            Row() {
              Text(r.icon).fontSize(18).fontColor(r.color)
              Text(r.cat.name).fontSize(12).layoutWeight(1).margin({ left: 4 })
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(`¥${formatAmount(r.total)}`).fontSize(11)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            }.width('100%')
            Row() {
              Row().height(4).width(`${total > 0 ? (r.total / total) * 100 : 0}%`)
                .backgroundColor(r.color).borderRadius(2)
            }.width('100%').height(4).backgroundColor('#E8EEF7').borderRadius(2).margin({ top: 4 })
          }.width('100%').margin({ top: 6 })
        }, (r: CatRow) => r.cat.id)
      }
    }
    .layoutWeight(1).padding(12).margin({ left: 4, right: 4 })
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .borderRadius(12)
  }
}