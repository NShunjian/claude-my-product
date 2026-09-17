/**
 * 报表页:对齐 uniapp pages/reports/monthly.vue 1:1(月度 + 年度切换)。
 */
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { AppHeader } from '../components/AppHeader'
import { MonthPicker } from '../components/MonthPicker'
import { DonutChart, DonutSegment } from '../components/DonutChart'
import { LineChart } from '../components/charts/LineChart'
import { useLanguage } from '../i18n/useLanguage'
import { getAuth } from '../stores/auth'
import { getBook } from '../stores/book'
import { getToast } from '../stores/toast'
import { getMonthlyReport, getYearlyReport } from '../api/reports'
import { formatAmount } from '../utils/finance'
import { formatLocalMonth } from '../utils/date'
import type { DailyPoint, MonthlyPoint, CategoryTotal, MonthlyReport, YearlyReport } from '../model/Types'

type Tab = 'monthly' | 'yearly'

const CATEGORY_PALETTE: string[] = ['#005394', '#FF8A65', '#FFB74D', '#9CCC65', '#26A69A', '#7E57C2',
  '#EC407A', '#5C6BC0', '#26C6DA', '#FFCA28', '#66BB6A', '#8D6E63']

const EN_MONTHS: string[] = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']

@Entry
@Component
export struct Reports {
  @State tab: Tab = 'monthly'
  @State @Watch('onMonthChange') month: string = formatLocalMonth(new Date())
  @State @Watch('onYearChange') year: number = new Date().getFullYear()
  @State loading: boolean = false
  @State monthlyReport: MonthlyReport | null = null
  @State yearlyReport: YearlyReport | null = null
  @State hoveredDay: number | null = null
  @State hoveredMonth: number | null = null
  private lang = useLanguage()
  private initialLoadDone: boolean = false

  aboutToAppear() {
    this.initialLoadDone = true
    this.load()
  }

  private onMonthChange() { if (this.initialLoadDone && this.tab === 'monthly') this.load() }
  private onYearChange() { if (this.initialLoadDone && this.tab === 'yearly') this.load() }

  async load() {
    const auth = getAuth(); const book = getBook()
    if (!auth.token || !book.current) return
    this.loading = true
    try {
      if (this.tab === 'monthly') {
        this.monthlyReport = await getMonthlyReport({ month: this.month, bookId: book.current.uuid })
      } else {
        this.yearlyReport = await getYearlyReport({ year: this.year, bookId: book.current.uuid })
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      const prefix = this.tab === 'monthly'
        ? this.lang.t('reportMonthly.loadErrorPrefix')
        : this.lang.t('reportYearly.loadErrorPrefix')
      getToast()?.show(prefix + msg)
    } finally { this.loading = false }
  }

  private paletteFor(totals: CategoryTotal[]): string[] {
    const out: string[] = []
    for (let i = 0; i < totals.length; i++) {
      out.push(CATEGORY_PALETTE[i % CATEGORY_PALETTE.length])
    }
    return out
  }

  private segsOf(totals: CategoryTotal[], palette: string[]): DonutSegment[] {
    const out: DonutSegment[] = []
    for (let i = 0; i < totals.length; i++) {
      const t = totals[i]
      const seg: DonutSegment = { label: t.categoryName ?? '', value: t.amount ?? 0, color: palette[i] }
      out.push(seg)
    }
    return out
  }

  build() {
    Column() {
      AppHeader({ title: this.lang.t('pageTitle.reportMonthly') })
      Row() {
        Text(this.lang.t('reportMonthly.tabMonthly'))
          .fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(this.tab === 'monthly' ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
          .backgroundColor(this.tab === 'monthly' ? resolveTheme(themeStore.effective).colors.primary : Color.Transparent)
          .padding({ left: 20, right: 20, top: 8, bottom: 8 })
          .borderRadius(20)
          .onClick(() => { if (this.tab !== 'monthly') { this.tab = 'monthly'; this.load() } })
        Text(this.lang.t('reportMonthly.tabYearly'))
          .fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(this.tab === 'yearly' ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
          .backgroundColor(this.tab === 'yearly' ? resolveTheme(themeStore.effective).colors.primary : Color.Transparent)
          .padding({ left: 20, right: 20, top: 8, bottom: 8 })
          .borderRadius(20)
          .margin({ left: 8 })
          .onClick(() => { if (this.tab !== 'yearly') { this.tab = 'yearly'; this.load() } })
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 })

      if (this.tab === 'monthly') {
        this.monthlyView()
      } else {
        this.yearlyView()
      }
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }

  @Builder monthlyView() {
    Scroll() {
      Column() {
        MonthPicker({ value: $month, compact: false })
          .width('100%').padding({ left: 16, right: 16, top: 8 })

        if (this.loading) {
          Text(this.lang.t('common.loading')).fontSize(13)
            .padding(40).width('100%').textAlign(TextAlign.Center)
            .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
        } else if (this.monthlyReport) {
          this.monthlyContent(this.monthlyReport)
        }
        Row().height(56)
      }
    }
    .layoutWeight(1).scrollBar(BarState.Off)
    .onAppear(() => this.load())
  }

  @Builder monthlyContent(r: MonthlyReport) {
    Column() {
      Column() {
        Text(this.lang.t('reportMonthly.netSavings')).fontSize(12).opacity(0.9)
          .fontColor('#FFFFFF')
        Text(`¥ ${formatAmount(r.netSavings)}`)
          .fontSize(32).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ top: 4 })
        Row() {
          Column() {
            Text(this.lang.t('reportMonthly.totalIncomeLabel')).fontSize(11).opacity(0.9).fontColor('#FFFFFF')
            Text(`+¥ ${formatAmount(r.totalIncome)}`).fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Column() {
            Text(this.lang.t('reportMonthly.totalExpenseLabel')).fontSize(11).opacity(0.9).fontColor('#FFFFFF')
            Text(`-¥ ${formatAmount(r.totalExpense)}`).fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }.layoutWeight(1).alignItems(HorizontalAlign.End)
        }.width('100%').margin({ top: 12 })
        Text(this.lang.t('reportMonthly.lastMonth') + ` ${r.lastMonthDiff !== undefined && r.lastMonthDiff >= 0 ? '+' : ''}${formatAmount(r.lastMonthDiff ?? 0)}`)
          .fontSize(11).opacity(0.9).fontColor('#FFFFFF').margin({ top: 6 })
      }
      .width('100%').padding(20).margin({ left: 16, right: 16, top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.primary).borderRadius(16)

      Column() {
        Row() {
          Text(this.lang.t('reportMonthly.dailyTrend')).fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(resolveTheme(themeStore.effective).colors.text)
          Row() {
            Column().width(10).height(10).borderRadius(5).backgroundColor('#005394')
            Text(this.lang.t('chart.line.income')).fontSize(11)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ left: 4 })
            Column().width(10).height(10).borderRadius(5).backgroundColor('#BA1A1A').margin({ left: 8 })
            Text(this.lang.t('chart.line.expense')).fontSize(11)
              .fontColor(resolveTheme(themeStore.effective).colors.textVariant).margin({ left: 4 })
          }
        }.width('100%').justifyContent(FlexAlign.SpaceBetween)

        LineChart({ data: r.dailyPoints })
          .width('100%').margin({ top: 12 })

        if (this.hoveredDay !== null && r.dailyPoints.length > 0) {
          this.hoveredDayRow(r.dailyPoints, this.hoveredDay)
        }
      }
      .width('100%').padding(16).margin({ left: 16, right: 16, top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(16)

      this.donutSection(this.lang.t('reportMonthly.incomeShare'),
        this.lang.t('reportMonthly.noIncomeRecords'), r.incomeBreakdown, true)

      this.donutSection(this.lang.t('reportMonthly.expenseShare'),
        this.lang.t('reportMonthly.noExpenseRecords'), r.expenseBreakdown, false)
    }
  }

  @Builder donutSection(title: string, emptyText: string, totals: CategoryTotal[], isIncome: boolean) {
    Column() {
      Text(title).fontSize(15).fontWeight(FontWeight.Medium)
        .fontColor(resolveTheme(themeStore.effective).colors.text).margin({ bottom: 12 })
      if (!totals || totals.length === 0) {
        Text(emptyText).fontSize(12).padding(20).width('100%').textAlign(TextAlign.Center)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
      } else {
        Row() {
          DonutChart({
            segments: this.segsOf(totals, this.paletteFor(totals)),
            totalValue: `¥${formatAmount(totals.reduce((s, t) => s + (t.amount ?? 0), 0))}`,
            diameter: 160,
          })
          Column() {
            ForEach(totals.slice(0, 6), (t: CategoryTotal, i: number) => {
              Row() {
                Column().width(8).height(8).borderRadius(4)
                  .backgroundColor(this.paletteFor(totals)[i])
                Text(t.categoryName).fontSize(12).layoutWeight(1).margin({ left: 8 })
                  .fontColor(resolveTheme(themeStore.effective).colors.text)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`¥${formatAmount(t.amount ?? 0)}`).fontSize(12)
                  .fontColor(isIncome ? '#005394' : '#BA1A1A')
              }.width('100%').padding({ top: 4, bottom: 4 })
            }, (t: CategoryTotal) => t.categoryId)
          }.layoutWeight(1).margin({ left: 12 })
        }.width('100%').alignItems(VerticalAlign.Top)
      }
    }
    .width('100%').padding(16).margin({ left: 16, right: 16, top: 12 })
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(16)
  }

  @Builder yearlyView() {
    Column() {
      Row() {
        Text('◀').fontSize(18).padding(8)
          .onClick(() => { this.year -= 1; this.load() })
        Text(`${this.year}`).fontSize(20).fontWeight(FontWeight.Bold).layoutWeight(1).textAlign(TextAlign.Center)
        Text('▶').fontSize(18).padding(8)
          .onClick(() => { this.year += 1; this.load() })
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 })

      if (this.loading) {
        Text(this.lang.t('common.loading')).fontSize(13).padding(40).width('100%').textAlign(TextAlign.Center)
      } else if (this.yearlyReport) {
        Scroll() {
          Column() {
            this.yearlyContent(this.yearlyReport)
            Row().height(56)
          }
        }
        .layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .layoutWeight(1)
    .onAppear(() => this.load())
  }

  @Builder yearlyContent(r: YearlyReport) {
    Column() {
      Column() {
        Text(this.lang.t('reportYearly.netSavingsLabel')).fontSize(12).opacity(0.9).fontColor('#FFFFFF')
        Text(`¥ ${formatAmount(r.netSavings)}`)
          .fontSize(32).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ top: 4 })
        Row() {
          Column() {
            Text(this.lang.t('reportYearly.totalIncomeLabel')).fontSize(11).opacity(0.9).fontColor('#FFFFFF')
            Text(`+¥ ${formatAmount(r.totalIncome)}`).fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Column() {
            Text(this.lang.t('reportYearly.totalExpenseLabel')).fontSize(11).opacity(0.9).fontColor('#FFFFFF')
            Text(`-¥ ${formatAmount(r.totalExpense)}`).fontSize(14).fontColor('#FFFFFF').fontWeight(FontWeight.Medium)
          }.layoutWeight(1).alignItems(HorizontalAlign.End)
        }.width('100%').margin({ top: 12 })
      }
      .width('100%').padding(20).margin({ left: 16, right: 16, top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.primary).borderRadius(16)

      Column() {
        Text(this.lang.t('reportYearly.monthlyTrend')).fontSize(15).fontWeight(FontWeight.Medium)
          .fontColor(resolveTheme(themeStore.effective).colors.text).margin({ bottom: 12 })
        this.barChart(r.monthlyPoints)
      }
      .width('100%').padding(16).margin({ left: 16, right: 16, top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard).borderRadius(16)

      this.donutSection(this.lang.t('reportYearly.expenseBreakdown'),
        this.lang.t('reportYearly.noExpenseRecords'), r.expenseBreakdown, false)
    }
  }

  @Builder barChart(points: MonthlyPoint[]) {
    Row() {
      ForEach(points, (p: MonthlyPoint, i: number) => {
        Column() {
          Column() {
            Blank().layoutWeight(1)
            Column().width(8)
              .height(this.barHeight(p.income, points))
              .backgroundColor('#005394').borderRadius(2)
            Column().width(8)
              .height(this.barHeight(p.expense, points))
              .backgroundColor('#BA1A1A').borderRadius(2).margin({ top: 2 })
          }.width(20).height(100).justifyContent(FlexAlign.End)
          Text(this.monthLabel(i + 1)).fontSize(9)
            .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            .margin({ top: 4 })
          if (this.hoveredMonth === i + 1) {
            Column() {
              Text(`+¥${formatAmount(p.income)}`).fontSize(9).fontColor('#005394')
              Text(`-¥${formatAmount(p.expense)}`).fontSize(9).fontColor('#BA1A1A')
            }
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          .onClick(() => { this.hoveredMonth = (this.hoveredMonth === i + 1) ? null : i + 1 })
      }, (p: MonthlyPoint) => `${p.month}`)
    }.width('100%').height(150).alignItems(VerticalAlign.Bottom)
  }

  private barHeight(v: number, points: MonthlyPoint[]): number {
    const m: number = this.maxIncomeOrExpense(points)
    const barMax: number = m === 0 ? 1 : m
    return Math.max(2, 100 * (v / barMax))
  }

  private monthLabel(m: number): string {
    const cur = this.lang.lang
    if (cur === 'en') return EN_MONTHS[m - 1]
    return `${m}月`
  }

  private maxIncomeOrExpense(points: MonthlyPoint[]): number {
    let maxVal = 0
    for (let i = 0; i < points.length; i++) {
      const m = Math.max(points[i].income, points[i].expense)
      if (m > maxVal) maxVal = m
    }
    return maxVal
  }

  @Builder hoveredDayRow(points: DailyPoint[], idx: number) {
    if (idx >= 0 && idx < points.length) {
      Row() {
        Text(`${points[idx].date}`).fontSize(11).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
        Text(` 收入 ¥${formatAmount(points[idx].income)}`).fontSize(11).fontColor('#005394')
        Text(` 支出 ¥${formatAmount(points[idx].expense)}`).fontSize(11).fontColor('#BA1A1A').margin({ left: 8 })
      }.width('100%').margin({ top: 8 })
    }
  }
}