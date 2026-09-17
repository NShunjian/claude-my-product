/**
 * 流水页:对齐 uniapp pages/transactions/index.vue 1:1。
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
import { listRecords, deleteRecord } from '../api/records'
import { listAccounts } from '../api/accounts'
import { listCategories } from '../api/categories'
import { formatAmount } from '../utils/finance'
import { formatLocalMonth, compareRecordDesc, formatDayHeaderCN } from '../utils/date'
import { consumePendingMonth } from '../utils/nav-intent'
import { promptAction } from '@kit.ArkUI'
import type { Record, Account, Category } from '../model/Types'

interface TxnDayGroup { date: string; recs: Record[]; net: number; label: string }

@Entry
@Component
export struct Transactions {
  @State @Watch('onMonthChange') month: string = ''
  @State filterCategory: string = 'all'
  @State filterAccount: string = 'all'
  @State records: Record[] = []
  @State accounts: Account[] = []
  @State cats: Category[] = []
  @State loading: boolean = false

  private lang = useLanguage()
  private initialLoadDone: boolean = false

  aboutToAppear() {
    this.month = formatLocalMonth(new Date())
    const m = consumePendingMonth()
    if (m && /^\d{4}-\d{2}$/.test(m)) this.month = m
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
      this.cats = res[2].concat(res[3])
    } catch (e) {
      const msg = e instanceof Error ? e.message : ''
      getToast()?.show(this.lang.t('transactions.loadErrorPrefix') + msg)
    } finally { this.loading = false }
  }

  private filtered(): Record[] {
    const out: Record[] = []
    for (const r of this.records) {
      if (this.filterCategory !== 'all' && r.categoryId !== this.filterCategory) continue
      if (this.filterAccount !== 'all' && r.accountId !== this.filterAccount) continue
      out.push(r)
    }
    out.sort(compareRecordDesc)
    return out
  }

  private findAccount(id: string): Account | undefined { return this.accounts.find(a => a.id === id) }
  private findCat(id: string | null): Category | undefined { return id ? this.cats.find(c => c.id === id) : undefined }

  private rowTap(id: string): void {
    void this.remove(id)
  }

  private async remove(id: string) {
    try {
      const confirmed = await new Promise<boolean>((r: (v: boolean) => void) => {
        promptAction.showDialog({
          title: this.lang.t('common.confirm'),
          message: this.lang.t('transactions.deleteConfirm'),
          buttons: [
            { text: this.lang.t('common.cancel'), color: '#666' },
            { text: this.lang.t('common.confirm'), color: '#005394' },
          ],
        }).then((res: promptAction.ShowDialogSuccessResponse) => r(res.index === 1))
      })
      if (!confirmed) return
      await deleteRecord(id)
      this.records = this.records.filter(r => r.id !== id)
      getToast()?.show(this.lang.t('common.delete') + ' OK')
    } catch (e) {
      const msg = e instanceof Error ? e.message : this.lang.t('common.error')
      getToast()?.show(msg)
    }
  }

  private monthIncome(): number {
    let s = 0
    for (const r of this.filtered()) if (r.type === 'income') s += r.amount
    return s
  }
  private monthExpense(): number {
    let s = 0
    for (const r of this.filtered()) if (r.type === 'expense') s += r.amount
    return s
  }

  private grouped(): TxnDayGroup[] {
    const map = new Map<string, Record[]>()
    for (const r of this.filtered()) {
      if (!r || !r.id) continue
      const key = r.recordDate
      const arr = map.get(key)
      if (arr) arr.push(r)
      else map.set(key, [r])
    }
    const out: TxnDayGroup[] = []
    for (const entry of map.entries()) {
      const date = entry[0]
      const recs = entry[1]
      let net = 0
      for (const r of recs) net += (r.type === 'income' ? r.amount : -r.amount)
      const g: TxnDayGroup = { date: date, recs: recs, net: net, label: formatDayHeaderCN(date) }
      out.push(g)
    }
    return out
  }

  build() {
    Column() {
      AppHeader({ title: this.lang.t('pageTitle.transactions') })
      Scroll() {
        Column() {
          Row() {
            MonthPicker({ value: $month, compact: true }).layoutWeight(1)
          }.width('100%').padding({ left: 16, right: 16 }).margin({ top: 12 })

          Scroll() {
            Row() {
              this.chip('all', this.lang.t('transactions.allCategories'), 'category')
              ForEach(this.cats, (c: Category) => {
                this.chip(c.id, c.name, 'category')
              }, (c: Category) => c.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .width('100%').padding({ left: 16, right: 16 }).margin({ top: 8 })

          Scroll() {
            Row() {
              this.chip('all', this.lang.t('transactions.allAccounts'), 'account')
              ForEach(this.accounts, (a: Account) => {
                this.chip(a.id, a.name, 'account')
              }, (a: Account) => a.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .width('100%').padding({ left: 16, right: 16 }).margin({ top: 8 })

          Column() {
            Text(this.lang.t('transactions.monthBalance')).fontSize(13).opacity(0.9)
              .fontColor('#FFFFFF')
            Text(`¥ ${formatAmount(Math.abs(this.monthIncome() - this.monthExpense()))}`)
              .fontSize(36).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ top: 4 })
            Row() {
              Column() {
                Text(this.lang.t('transactions.income')).fontSize(12).opacity(0.9).fontColor('#FFFFFF')
                Text(`+¥ ${formatAmount(this.monthIncome())}`).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Column() {
                Text(this.lang.t('transactions.expense')).fontSize(12).opacity(0.9).fontColor('#FFFFFF')
                Text(`-¥ ${formatAmount(this.monthExpense())}`).fontSize(14).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
              }.layoutWeight(1).alignItems(HorizontalAlign.End)
            }.width('100%').margin({ top: 12 })
          }
          .width('100%').padding(20).margin({ left: 16, right: 16, top: 12 })
          .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
          .borderRadius(16)

          Column() {
            if (this.loading) {
              Text(this.lang.t('transactions.loading')).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .padding(24).width('100%').textAlign(TextAlign.Center)
            } else if (this.filtered().length === 0) {
              Text(this.lang.t('transactions.empty')).fontSize(13)
                .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .padding(24).width('100%').textAlign(TextAlign.Center)
            } else {
              ForEach(this.grouped(), (g: TxnDayGroup) => {
                Column() {
                  Row() {
                    Text(g.label).fontSize(12).fontWeight(FontWeight.Medium)
                      .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                      .layoutWeight(1)
                    Text(`${g.net >= 0 ? '+' : '-'}¥ ${formatAmount(Math.abs(g.net))}`)
                      .fontSize(12).fontWeight(FontWeight.Medium)
                      .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                  }
                  .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
                  .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
                  ForEach(g.recs, (r: Record) => {
                    TransactionRow({ record: r, category: this.findCat(r.categoryId) ?? null, account: this.findAccount(r.accountId) ?? null, onTap: this.rowTap.bind(this) })
                  }, (r: Record) => r.id)
                }
              }, (g: TxnDayGroup) => g.date)
            }
          }
          .width('100%').margin({ top: 12 })
          .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
          .borderRadius(16)

          Row().height(56)
        }
      }
      .layoutWeight(1).scrollBar(BarState.Off)
    }
    .width('100%').height('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }

  @Builder chip(id: string, label: string, kind: 'category' | 'account') {
    Text(label).fontSize(13)
      .fontColor((kind === 'category' ? this.filterCategory : this.filterAccount) === id
        ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
      .backgroundColor((kind === 'category' ? this.filterCategory : this.filterAccount) === id
        ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.surface)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin({ right: 8 })
      .onClick(() => {
        if (kind === 'category') this.filterCategory = id
        else this.filterAccount = id
      })
  }
}