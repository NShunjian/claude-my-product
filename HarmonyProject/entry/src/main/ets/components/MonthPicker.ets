/**
 * MonthPicker:对齐 uniapp components/MonthPicker.vue 1:1。
 * ponytail: 用 ‹ › 按钮 + 弹窗 grid。
 */
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { addMonths, formatMonthCN } from '../utils/date'

@Component
export struct MonthPicker {
  @Link value: string
  @Prop compact: boolean = false
  @State showModal: boolean = false
  onChange: () => void = () => {}

  private currentMonth(): string {
    const parts = this.value.split('-')
    return parts.length >= 2 ? parts[1] : '01'
  }

  @Builder gridItem(year: number) {
    Column() {
      Text(`${year}`)
        .fontSize(14)
        .fontColor(resolveTheme(themeStore.effective).colors.text)
    }
    .width(80).height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
    .borderRadius(8)
    .margin(4)
    .onClick(() => {
      this.showModal = false
      this.value = `${year}-${this.currentMonth()}`
    })
  }

  private buildYears(): number[] {
    const out: number[] = []
    const start = new Date().getFullYear() - 5
    for (let i = 0; i < 10; i++) out.push(start + i)
    return out
  }

  build() {
    Stack() {
      Row() {
        Text('‹').fontSize(22).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .width(32).height(32)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.value = addMonths(this.value, -1) })
        Text(formatMonthCN(this.value))
          .fontSize(this.compact ? 14 : 16)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding(8)
          .backgroundColor(resolveTheme(themeStore.effective).colors.surface)
          .borderRadius(8)
          .margin({ left: 4, right: 4 })
          .onClick(() => { this.showModal = true })
        Text('›').fontSize(22).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .width(32).height(32)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.value = addMonths(this.value, 1) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.showModal) {
        Column().width('100%').height('100%').backgroundColor('#00000066')
          .onClick(() => { this.showModal = false })
        Column() {
          Text('选择月份')
            .fontSize(18).fontWeight(FontWeight.Bold)
            .fontColor(resolveTheme(themeStore.effective).colors.text)
            .margin({ top: 16, bottom: 12 })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.buildYears(), (y: number) => {
              this.gridItem(y)
            }, (y: number) => `${y}`)
          }
          Text('关闭').fontSize(14).fontColor(resolveTheme(themeStore.effective).colors.primary)
            .margin({ top: 16, bottom: 16 })
            .onClick(() => { this.showModal = false })
        }
        .width('80%')
        .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
        .borderRadius(16)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
  }
}
