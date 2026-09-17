/**
 * RecordForm:对齐 uniapp components/RecordForm.vue 1:1。
 * ponytail: type/amount/account/category/date/note 6 字段表单。
 */
import type { Account, Category, RecordType } from '../model/Types'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { formatLocalDate } from '../utils/date'

export interface RecordFormSubmitData {
  type: RecordType
  amount: number
  accountId: string
  categoryId: string
  recordDate: string
  note: string
}

@Component
export struct RecordForm {
  @Prop type: RecordType = 'expense'
  @Prop accounts: Account[] = []
  @Prop expenseCats: Category[] = []
  @Prop incomeCats: Category[] = []
  @Prop defaultDate: string = ''
  @Prop defaultAccountId: string = ''
  @Prop defaultCategoryId: string = ''
  @State private amountStr: string = ''
  @State private accountId: string = ''
  @State private categoryId: string = ''
  @State private recordDate: string = ''
  @State private note: string = ''
  onSubmit: (data: RecordFormSubmitData) => void = () => {}
  onCancel: () => void = () => {}

  aboutToAppear() {
    this.recordDate = this.defaultDate || formatLocalDate(new Date())
    this.accountId = this.defaultAccountId || (this.accounts[0]?.id ?? '')
    const cats = this.type === 'expense' ? this.expenseCats : this.incomeCats
    this.categoryId = this.defaultCategoryId || (cats[0]?.id ?? '')
  }

  private selectAccount(id: string) { this.accountId = id }
  private selectCategory(id: string) { this.categoryId = id }

  private submit() {
    const a = Number.parseFloat(this.amountStr)
    if (!Number.isFinite(a) || a <= 0 || !this.categoryId || !this.accountId) return
    this.onSubmit({
      type: this.type, amount: a,
      accountId: this.accountId, categoryId: this.categoryId,
      recordDate: this.recordDate, note: this.note,
    })
  }

  build() {
    Column() {
      Row() {
        Text(this.type === 'expense' ? '支出' : '收入')
          .fontSize(13).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
        Text('¥ ')
          .fontSize(20).fontColor(resolveTheme(themeStore.effective).colors.text).margin({ left: 8 })
        TextInput({ text: this.amountStr, placeholder: '0.00' })
          .type(InputType.Number)
          .layoutWeight(1)
          .fontSize(28).fontWeight(FontWeight.Bold)
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => { this.amountStr = v })
      }
      .width('100%').padding(16)
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)

      Column() {
        Text('账户').fontSize(13).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
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
                .onClick(() => this.selectAccount(a.id))
            }, (a: Account) => a.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%').margin({ top: 8 })
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)

      Column() {
        Text('分类').fontSize(13).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.type === 'expense' ? this.expenseCats : this.incomeCats, (c: Category) => {
            Column() {
              Text(c.icon || '⋯').fontSize(20).fontColor(c.color)
              Text(c.name).fontSize(11).fontColor(this.categoryId === c.id ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.text)
            }
            .padding(8)
            .border({
              width: this.categoryId === c.id ? 2 : 1,
              color: this.categoryId === c.id ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.divider,
            })
            .borderRadius(8)
            .margin({ right: 8, top: 8 })
            .onClick(() => this.selectCategory(c.id))
          }, (c: Category) => c.id)
        }.margin({ top: 8 })
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text('日期').fontSize(13).fontColor(resolveTheme(themeStore.effective).colors.textVariant).width(48)
        TextInput({ text: this.recordDate, placeholder: 'YYYY-MM-DD' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => { this.recordDate = v })
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)

      Row() {
        Text('备注').fontSize(13).fontColor(resolveTheme(themeStore.effective).colors.textVariant).width(48)
        TextInput({ text: this.note, placeholder: '可选' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => { this.note = v })
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)

      Row() {
        Text('取消').fontSize(16).fontColor(resolveTheme(themeStore.effective).colors.text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding(14)
          .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
          .borderRadius(12)
          .margin({ right: 8 })
          .onClick(() => this.onCancel())
        Text('保存').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding(14)
          .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
          .borderRadius(12)
          .onClick(() => this.submit())
      }
      .width('100%').margin({ top: 16 })
    }
    .width('100%')
  }
}
