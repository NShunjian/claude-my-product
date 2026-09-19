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
import { logger, TAGS } from '../utils/logger'
import { listRecords } from '../api/records'
import { listAccounts } from '../api/accounts'
import { listCategories } from '../api/categories'
import { formatAmount } from '../utils/finance'
import { formatMonthCN, formatRelativeDayLabel, compareRecordDesc, DayLabels } from '../utils/date'
import { categoryPresentation, CategoryLike } from '../utils/category-presentation'
import { quickAddStore } from '../stores/quick-add'
import { getMonthPicker } from '../stores/month-picker'
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
  // KPI 值用 number @State 兜底:对象数组的 @State 在某些 ArkUI 版本下重 build 不及时,
  // number 字段是稳的;在 load() 里直接算出,build 里读字段。
  @State monthExpenseVal: number = 0
  @State monthIncomeVal: number = 0
  // catBreakdown 也走 @State:@Builder 的数组参数会被首帧冻结,直接预计算成 @State
  // 数组给 ForEach 用,避开 builder 缓存。
  @State expenseByCat: CatRow[] = []
  @State incomeByCat: CatRow[] = []

  private initialLoadDone: boolean = false
  private bookUnsub: (() => void) | null = null
  private monthPickerUnsub: (() => void) | null = null
  private auth = getAuth()
  private book = getBook()
  private monthPicker = getMonthPicker()
  private lang = useLanguage()

  aboutToAppear() {
    const d = new Date()
    this.month = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
    this.initialLoadDone = true
    // 订阅 bookStore:currentId / books 任一变化都重拉,模拟 uniapp
    // watch([auth.token, book.current], load, { immediate: true })。
    this.bookUnsub = this.book.subscribe(() => {
      if (this.initialLoadDone) this.load()
    })
    // 订阅 monthPickerStore:用户在 Index 全栈 modal 里点月份 → pendingValue/tick 变化
    // → 写回 this.month,触发 onMonthChange 重拉。
    this.monthPickerUnsub = this.monthPicker.subscribe(() => {
      const v = this.monthPicker.pendingValue
      if (v && v !== this.month) {
        this.month = v
        this.monthPicker.pendingValue = ''
      }
    })
    this.load()
  }

  aboutToDisappear() {
    if (this.bookUnsub) { this.bookUnsub(); this.bookUnsub = null }
    if (this.monthPickerUnsub) { this.monthPickerUnsub(); this.monthPickerUnsub = null }
  }

  private onMonthChange() { if (this.initialLoadDone) this.load() }

  async load() {
    if (!this.auth.token || !this.book.current) return
    this.loading = true
    try {
      const res = await Promise.all([
        listRecords({ month: this.month, bookId: this.book.current.uuid }),
        listAccounts({ bookId: this.book.current.uuid }),
        listCategories('expense'),
        listCategories('income'),
      ])
      this.records = res[0]
      this.accounts = res[1]
      const exp = res[2]; const inc = res[3]
      this.cats = exp.concat(inc)
      // 把 KPI 数值也算好塞进 @State,build 直接读 number 字段
      let e = 0; let i = 0
      for (const r of this.records) {
        if (r.type === 'expense') e += r.amount
        else if (r.type === 'income') i += r.amount
      }
      this.monthExpenseVal = e
      this.monthIncomeVal = i
      // 预算分类 rows 也算好塞进 @State,绕开 catBreakdown @Builder 的 rows 参数缓存
      this.expenseByCat = this.byCat('expense')
      this.incomeByCat = this.byCat('income')
      // 调试:打 records/accounts/cats 实际长度 + 月度累计
      logger.info(TAGS.UI, `load done records=${this.records.length} accounts=${this.accounts.length} cats=${this.cats.length} monthExpense=${this.monthExpenseVal} monthIncome=${this.monthIncomeVal} totalAssets=${this.totalAssets()}`)
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      getToast()?.show(this.lang.t('home.loadErrorPrefix') + msg)
      logger.error(TAGS.UI, 'load fail', msg)
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
              Text(this.lang.t('home.overview')).fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor(resolveTheme(themeStore.effective).colors.text)
              Text(formatMonthCN(this.month)).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .margin({ top: 2 })
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              .height(40)
              .justifyContent(FlexAlign.Center)
            MonthPicker({ value: $month }).width(180)
          }
          .width('100%').padding({ left: 10, right: 10 }).margin({ top: 8 })

          Column() {
            Stack({ alignContent: Alignment.TopStart }) {
              Text('💰').fontSize(48).opacity(0.12).position({ x: '70%', y: 0 })
              Column() {
                Text(this.lang.t('home.totalAssets')).fontSize(13)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                Row() {
                  Text('¥').fontSize(16).fontColor(resolveTheme(themeStore.effective).colors.primary)
                  Text(formatAmount(this.totalAssets())).fontSize(28).fontWeight(FontWeight.Bold)
                    .fontColor(resolveTheme(themeStore.effective).colors.primary)
                }
                .margin({ top: 8 }).alignItems(VerticalAlign.Bottom)

                Text(this.lang.t('home.accountsCount').replace('{n}', String(this.accounts.length)))
                  .fontSize(12).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                  .margin({ top: 8 })

                Button() {
                  Row() {
                    Text('+')
                      .fontSize(14).fontWeight(FontWeight.Normal).fontColor('#FFFFFF')
                      .margin({ right: 3 })
                    Text(this.lang.t('home.quickAdd'))
                      .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .alignItems(VerticalAlign.Center)
                }
                .width('100%')
                .height(44)
                .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
                .borderRadius(8)
                .margin({ top: 12 })
                .onClick(() => quickAddStore.open('expense'))
              }
              .width('100%').alignItems(HorizontalAlign.Start)
            }
            .width('100%').padding(12)
            .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
            .borderRadius(8)
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
          }
          .width('100%').padding({ left: 10, right: 10, top: 12 })

          // 三个 KPI 全部内联 Row,绕开 @Builder 的 value 参数缓存 bug
          // (this.kpi(label, formatAmount(this.monthExpenseVal), color) 时,
          //  formatAmount(...) 作为 @Builder 实参被冻结成首帧值)
          Column() {
            Row() {
              Column() {
                Text(this.lang.t('home.monthExpense')).fontSize(13)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                Row() {
                  Text('¥').fontSize(16).fontColor(resolveTheme(themeStore.effective).colors.error)
                  Text(formatAmount(this.monthExpenseVal)).fontSize(28).fontWeight(FontWeight.Bold)
                    .fontColor(resolveTheme(themeStore.effective).colors.error)
                }
                .margin({ top: 4 }).alignItems(VerticalAlign.Bottom)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }
            .width('100%').padding(12).margin({ top: 6 })
            .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
            .borderRadius(8)
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })

            Row() {
              Column() {
                Text(this.lang.t('home.monthIncome')).fontSize(13)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                Row() {
                  Text('¥').fontSize(16).fontColor('#006d40')
                  Text(formatAmount(this.monthIncomeVal)).fontSize(28).fontWeight(FontWeight.Bold)
                    .fontColor('#006d40')
                }
                .margin({ top: 4 }).alignItems(VerticalAlign.Bottom)
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }
            .width('100%').padding(12).margin({ top: 6 })
            .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
            .borderRadius(8)
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })

            this.balanceKpiRow()
          }
          .width('100%').padding({ left: 10, right: 10 }).margin({ top: 12 })

          // 外层 Row 只负责距屏 10;内层 Column 才是卡片(bgCard + border + radius)。
          // 之前直接给 Column 加 padding+bgCard,ArkUI 里 Column 的 border 画在 padding
          // 外边缘(贴屏),视觉上卡片没缩进;拆成 Row+Column 后 padding 是 Row 的,
          // border 在 Column 的 padding 内边缘(即内容边缘),卡片整体缩进 10。
          Row() {
            Column() {
              Row() {
                Text(this.lang.t('home.recentTransactions')).fontSize(16).fontWeight(FontWeight.Bold)
                  .layoutWeight(1)
                Text(`${this.lang.t('home.viewAll')} →`).fontSize(13)
                  .fontColor(resolveTheme(themeStore.effective).colors.primary)
                  .onClick(() => { setPendingMonth(this.month); getToast()?.show('切换到流水页') })
              }
              .width('100%').padding({ left: 10, right: 16, top: 16, bottom: 8 })
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
                    .width('100%').padding({ left: 10, right: 16, top: 8, bottom: 8 })
                    .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
                    ForEach(g.recs, (r: Record) => {
                      TransactionRow({ record: r, category: this.findCat(r.categoryId) ?? null, account: this.findAccount(r.accountId) ?? null })
                    }, (r: Record) => r.id)
                  }
                }, (g: DayGroup) => g.date)
              }
            }
            .layoutWeight(1)
            .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
            .borderRadius(8)
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
          }
          .width('100%').padding({ left: 10, right: 10 }).margin({ top: 12 })

          Row() {
            // 支出分类 - 直接读 @State expenseByCat
            Column() {
              Text(this.lang.t('home.expenseByCategory'))
                .fontSize(15).fontWeight(FontWeight.Bold)
                .width('100%').padding({ left: 4, right: 4, top: 12, bottom: 8 })
              if (this.expenseByCat.length === 0) {
                Text(this.lang.t('home.empty')).fontSize(11)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                  .padding(8).width('100%').textAlign(TextAlign.Center)
              } else {
                ForEach(this.expenseByCat, (r: CatRow) => {
                  Column() {
                    Row() {
                      Text(r.icon).fontSize(18).fontColor(r.color)
                      Text(r.cat.name).fontSize(12).layoutWeight(1).margin({ left: 4 })
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`¥${formatAmount(r.total)}`).fontSize(11)
                        .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                    }.width('100%')
                    Row() {
                      Row().height(4).width(`${this.monthExpenseVal > 0 ? (r.total / this.monthExpenseVal) * 100 : 0}%`)
                        .backgroundColor(r.color).borderRadius(2)
                    }.width('100%').height(4).backgroundColor('#E8EEF7').borderRadius(2).margin({ top: 4 })
                  }.width('100%').margin({ top: 6 })
                }, (r: CatRow) => r.cat.id)
              }
            }
            .layoutWeight(1).padding({ left: 8, right: 8, bottom: 8 })
            .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
            .borderRadius(8)
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })

            // 支出/收入两卡片之间的间距(ArkUI Row 没有 gap,占位 10vp)
            Row().width(10)

            // 收入分类 - 同上
            Column() {
              Text(this.lang.t('home.incomeByCategory'))
                .fontSize(15).fontWeight(FontWeight.Bold)
                .width('100%').padding({ left: 4, right: 4, top: 12, bottom: 8 })
              if (this.incomeByCat.length === 0) {
                Text(this.lang.t('home.empty')).fontSize(11)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                  .padding(8).width('100%').textAlign(TextAlign.Center)
              } else {
                ForEach(this.incomeByCat, (r: CatRow) => {
                  Column() {
                    Row() {
                      Text(r.icon).fontSize(18).fontColor(r.color)
                      Text(r.cat.name).fontSize(12).layoutWeight(1).margin({ left: 4 })
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(`¥${formatAmount(r.total)}`).fontSize(11)
                        .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                    }.width('100%')
                    Row() {
                      Row().height(4).width(`${this.monthIncomeVal > 0 ? (r.total / this.monthIncomeVal) * 100 : 0}%`)
                        .backgroundColor(r.color).borderRadius(2)
                    }.width('100%').height(4).backgroundColor('#E8EEF7').borderRadius(2).margin({ top: 4 })
                  }.width('100%').margin({ top: 6 })
                }, (r: CatRow) => r.cat.id)
              }
            }
            .layoutWeight(1).padding({ left: 8, right: 8, bottom: 8 })
            .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
            .borderRadius(8)
            .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
          }
          .width('100%').padding({ left: 10, right: 10 }).margin({ top: 12 })
          .alignItems(VerticalAlign.Top)

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
          Text('¥').fontSize(16).fontColor(color)
          Text(value).fontSize(28).fontWeight(FontWeight.Bold).fontColor(color)
        }
        .margin({ top: 4 }).alignItems(VerticalAlign.Bottom)
        if (sub) {
          Text(sub).fontSize(12).fontColor(color).margin({ top: 4 })
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(12).margin({ top: 6 })
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .borderRadius(8)
    .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
  }

  @Builder balanceKpiRow() {
    Row() {
      Column() {
        Text(this.lang.t('home.monthBalance')).fontSize(13)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
        Row() {
          Text('¥').fontSize(16).fontColor(this.monthIncomeVal - this.monthExpenseVal >= 0 ? '#006d40' : resolveTheme(themeStore.effective).colors.error)
          Text(formatAmount(Math.abs(this.monthIncomeVal - this.monthExpenseVal))).fontSize(28).fontWeight(FontWeight.Bold)
            .fontColor(this.monthIncomeVal - this.monthExpenseVal >= 0 ? '#006d40' : resolveTheme(themeStore.effective).colors.error)
        }
        .margin({ top: 4 }).alignItems(VerticalAlign.Bottom)
        Text(this.monthIncomeVal - this.monthExpenseVal >= 0 ? this.lang.t('home.surplus') : this.lang.t('home.overBudget'))
          .fontSize(12)
          .fontColor(this.monthIncomeVal - this.monthExpenseVal >= 0 ? '#006d40' : resolveTheme(themeStore.effective).colors.error)
          .margin({ top: 4 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(12).margin({ top: 6 })
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .borderRadius(8)
    .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
  }

  }