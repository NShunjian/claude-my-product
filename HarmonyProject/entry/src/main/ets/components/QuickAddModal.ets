/**
 * QuickAddModal:对齐 uniapp components/QuickAddModal.vue 1:1(核心简版)。
 * ponytail: keypad + 分类 + 账户 + 备注 + 保存;HarmonyOS 下用 bottom sheet 全屏遮罩。
 */
import { quickAddStore } from '../stores/quick-add'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import type { Account, Category } from '../model/Types'
import { listAccounts } from '../api/accounts'
import { listCategories } from '../api/categories'
import { createRecord } from '../api/records'
import { getBook } from '../stores/book'
import { getAuth } from '../stores/auth'
import { getToast } from '../stores/toast'
import { formatLocalDate } from '../utils/date'

@Component
export struct QuickAddModal {
  @State private kind: 'expense' | 'income' = 'expense'
  @State private amount: string = ''
  @State private note: string = ''
  @State private accountId: string = ''
  @State private categoryId: string = ''
  @State private accounts: Account[] = []
  @State private expenseCats: Category[] = []
  @State private incomeCats: Category[] = []
  @State private loading: boolean = false

  aboutToAppear() { this.load() }

  async load() {
    const book = getBook()
    if (!book.current) return
    try {
      const res = await Promise.all([
        listAccounts({ bookId: book.current.uuid }),
        listCategories('expense'),
        listCategories('income'),
      ])
      const accs: Account[] = res[0]
      const exp: Category[] = res[1]
      const inc: Category[] = res[2]
      this.accounts = accs.filter(a => !a.isArchived)
      this.expenseCats = exp
      this.incomeCats = inc
      this.accountId = this.accountId || this.accounts.find(a => a.isDefault)?.id || this.accounts[0]?.id || ''
      this.categoryId = this.categoryId || (this.kind === 'expense' ? this.expenseCats[0]?.id : this.incomeCats[0]?.id) || ''
    } catch { /* ignore */ }
  }

  private onKey(key: string) {
    if (key === '⌫') this.amount = this.amount.slice(0, -1)
    else if (key === '.') { if (!this.amount.includes('.')) this.amount = (this.amount || '0') + '.' }
    else { this.amount = (this.amount || '') + key }
  }

  private async save() {
    const a = Number.parseFloat(this.amount)
    if (!Number.isFinite(a) || a <= 0) { getToast()?.show('请输入金额'); return }
    if (!this.categoryId || !this.accountId) { getToast()?.show('请选择账户和分类'); return }
    const book = getBook()
    if (!book.current) return
    this.loading = true
    try {
      await createRecord({
        type: this.kind,
        amount: a,
        accountId: this.accountId,
        categoryId: this.categoryId,
        recordDate: formatLocalDate(new Date()),
        note: this.note,
      })
      quickAddStore.notifySaved()
      this.amount = ''; this.note = ''
    } catch (e) {
      const msg = e instanceof Error ? e.message : '保存失败'
      getToast()?.show(msg)
    } finally {
      this.loading = false
    }
  }

  @Builder private keypad() {
    Grid() {
      ForEach(['1','2','3','4','5','6','7','8','9','.','0','⌫'], (k: string) => {
        GridItem() {
          Text(k).fontSize(22).fontWeight(FontWeight.Medium).fontColor(resolveTheme(themeStore.effective).colors.text)
        }
        .height(56)
        .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
        .borderRadius(8)
        .onClick(() => this.onKey(k))
      }, (k: string) => k)
    }
    .columnsTemplate('1fr 1fr 1fr')
    .rowsTemplate('1fr 1fr 1fr 1fr')
    .columnsGap(6).rowsGap(6)
    .width('100%').height(248)
  }

  build() {
    if (quickAddStore.show) {
      Stack() {
        Column()
          .width('100%').height('100%')
          .backgroundColor('#00000099')
          .onClick(() => quickAddStore.close())
        Column() {
          // 顶部切换
          Row() {
            Text('支出')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.kind === 'expense' ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.textVariant)
              .backgroundColor(this.kind === 'expense' ? resolveTheme(themeStore.effective).colors.error : resolveTheme(themeStore.effective).colors.surface)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .borderRadius(16)
              .margin({ right: 8 })
              .onClick(() => { this.kind = 'expense'; this.categoryId = this.expenseCats[0]?.id ?? '' })
            Text('收入')
              .fontSize(14).fontWeight(FontWeight.Medium)
              .fontColor(this.kind === 'income' ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.textVariant)
              .backgroundColor(this.kind === 'income' ? '#10B981' : resolveTheme(themeStore.effective).colors.surface)
              .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              .borderRadius(16)
              .onClick(() => { this.kind = 'income'; this.categoryId = this.incomeCats[0]?.id ?? '' })
            Blank()
            Text('×').fontSize(22).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
              .width(32).height(32).textAlign(TextAlign.Center)
              .onClick(() => quickAddStore.close())
          }
          .width('100%').padding(16)

          // 金额
          Row() {
            Text('¥').fontSize(22).fontColor(resolveTheme(themeStore.effective).colors.text)
            Text(this.amount || '0.00').fontSize(36).fontWeight(FontWeight.Bold)
              .fontColor(resolveTheme(themeStore.effective).colors.text)
              .margin({ left: 8 })
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 16 })

          // 分类
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.kind === 'expense' ? this.expenseCats : this.incomeCats, (c: Category) => {
              Column() {
                Text(c.icon || '⋯').fontSize(20).fontColor(c.color)
                Text(c.name).fontSize(11)
                  .fontColor(this.categoryId === c.id ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.text)
              }
              .padding(8)
              .border({
                width: this.categoryId === c.id ? 2 : 1,
                color: this.categoryId === c.id ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.divider,
              })
              .borderRadius(8)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => { this.categoryId = c.id })
            }, (c: Category) => c.id)
          }
          .width('100%').padding({ left: 16, right: 16, bottom: 12 })

          // 账户 chips
          Scroll() {
            Row() {
              ForEach(this.accounts, (a: Account) => {
                Text(a.name)
                  .fontSize(13)
                  .fontColor(this.accountId === a.id ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
                  .backgroundColor(this.accountId === a.id ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.surface)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .borderRadius(16)
                  .margin({ right: 8 })
                  .onClick(() => { this.accountId = a.id })
              }, (a: Account) => a.id)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .width('100%').padding({ left: 16, right: 16, bottom: 12 })

          // 备注
          TextInput({ text: this.note, placeholder: '备注(可选)' })
            .fontSize(14).width('100%')
            .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
            .borderRadius(8)
            .padding(12)
            .margin({ left: 16, right: 16, bottom: 12 })
            .onChange((v: string) => { this.note = v })

          this.keypad()

          // 保存按钮
          Text(this.loading ? '保存中…' : '保存')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .width('100%').textAlign(TextAlign.Center)
            .padding(14)
            .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
            .borderRadius(12)
            .margin({ top: 12, left: 16, right: 16, bottom: 16 })
            .onClick(() => this.save())
        }
        .width('100%')
        .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
        .borderRadius({ topLeft: 20, topRight: 20 })
        .position({ x: 0, y: 80 })
      }
      .width('100%').height('100%')
      .position({ x: 0, y: 0 })
    }
  }
}
