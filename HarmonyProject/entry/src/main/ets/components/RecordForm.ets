/**
 * RecordForm:对齐 uniapp components/RecordForm.vue 1:1。
 * ponytail: 单 .form + 每字段 .field(label + 内容一行),分类项 pill(icon + name inline)。
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
  @State private showAccountPicker: boolean = false
  onSubmit: (data: RecordFormSubmitData) => void = () => {}
  onCancel: () => void = () => {}

  aboutToAppear() {
    this.recordDate = this.defaultDate || formatLocalDate(new Date())
    this.accountId = this.defaultAccountId || (this.accounts[0]?.id ?? '')
    const cats = this.type === 'expense' ? this.expenseCats : this.incomeCats
    this.categoryId = this.defaultCategoryId || (cats[0]?.id ?? '')
  }

  private cats(): Category[] {
    return this.type === 'expense' ? this.expenseCats : this.incomeCats
  }

  private selectAccount(id: string) { this.accountId = id }
  private selectCategory(id: string) { this.categoryId = id }

  private accountName(): string {
    const a = this.accounts.find(x => x.id === this.accountId)
    return a?.name ?? '选择账户'
  }

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
      // 类型
      Row() {
        Text('类型').fontSize(13)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .width(56)
        Text(this.type === 'expense' ? '支出' : this.type === 'income' ? '收入' : '转账')
          .fontSize(14)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
          .layoutWeight(1)
      }
      .width('100%').padding(16)
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)

      // 金额
      Row() {
        Text('金额').fontSize(13)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .width(56)
        Row() {
          Text('¥').fontSize(18)
            .fontColor(resolveTheme(themeStore.effective).colors.text)
            .margin({ right: 8 })
          TextInput({ text: this.amountStr, placeholder: '0.00' })
            .type(InputType.Number)
            .layoutWeight(1)
            .fontSize(18).fontWeight(FontWeight.Bold)
            .backgroundColor(Color.Transparent)
            .maxLength(15)
            .onChange((v: string) => { this.amountStr = v })
        }
        .layoutWeight(1)
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)

      // 账户
      Row() {
        Text('账户').fontSize(13)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .width(56)
        Text(this.accountName()).fontSize(14)
          .fontColor(this.accountId
            ? resolveTheme(themeStore.effective).colors.text
            : resolveTheme(themeStore.effective).colors.textVariant)
          .layoutWeight(1)
          .onClick(() => { this.showAccountPicker = true })
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)

      // 分类
      Column() {
        Text('分类').fontSize(13)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .margin({ bottom: 8 })
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.cats(), (c: Category) => {
            Row() {
              Text(c.icon || '⋯').fontSize(16).fontColor(c.color)
              Text(c.name).fontSize(12)
                .fontColor(this.categoryId === c.id ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
                .margin({ left: 4 })
            }
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.categoryId === c.id ? resolveTheme(themeStore.effective).colors.primary : resolveTheme(themeStore.effective).colors.bgCard)
            .border({
              width: this.categoryId === c.id ? 0 : 1,
              color: resolveTheme(themeStore.effective).colors.divider,
            })
            .borderRadius(24)
            .margin({ right: 8, top: 8 })
            .onClick(() => this.selectCategory(c.id))
          }, (c: Category) => c.id)
        }
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)
      .alignItems(HorizontalAlign.Start)

      // 日期
      Row() {
        Text('日期').fontSize(13)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .width(56)
        TextInput({ text: this.recordDate, placeholder: 'YYYY-MM-DD' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => { this.recordDate = v })
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)

      // 备注
      Row() {
        Text('备注').fontSize(13)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .width(56)
        TextInput({ text: this.note, placeholder: '可选' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .onChange((v: string) => { this.note = v })
      }
      .width('100%').padding(16).margin({ top: 12 })
      .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
      .borderRadius(12)
      .alignItems(VerticalAlign.Center)

      // 保存
      Button() {
        Text('保存').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
      }
      .width('100%').padding(14)
      .backgroundColor(resolveTheme(themeStore.effective).colors.primary)
      .borderRadius(12)
      .margin({ top: 24 })
      .onClick(() => this.submit())
    }
    .width('100%')
  }
}