/**
 * MonthPicker:对齐 uniapp components/MonthPicker.vue 1:1。
 * ponytail: 箭头改 Image chevron PNG — 14×14 px Image fillColor,跟 15vp Text 同 box center。
 * 视觉中心对齐靠 Row.alignItems(VerticalAlign.Center),glyph 形状差异消除。
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
        Image($r('app.media.arrow_left'))
          .width(14).height(14)
          .fillColor(resolveTheme(themeStore.effective).colors.text)
        Text(formatMonthCN(this.value))
          .fontSize(this.compact ? 13 : 15)
          .fontWeight(FontWeight.Medium)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Image($r('app.media.arrow_right'))
          .width(14).height(14)
          .fillColor(resolveTheme(themeStore.effective).colors.text)
      }
      .width('100%').height(40)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 12, right: 12 })
      .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
      .borderRadius(16)
      .hitTestBehavior(HitTestMode.Transparent)

      // 点击分区 overlay:箭头列 / 中间列
      Row() {
        Column().width(44).height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.value = addMonths(this.value, -1) })
        Column().layoutWeight(1).height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.showModal = true })
        Column().width(44).height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.value = addMonths(this.value, 1) })
      }
      .width('100%').height(40)

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