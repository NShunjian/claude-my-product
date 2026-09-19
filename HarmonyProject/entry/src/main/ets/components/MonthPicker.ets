/**
 * MonthPicker:对齐 uniapp components/MonthPicker.vue 1:1。
 * 只负责触发器(左右箭头 + 中间月份文字);点击中间打开全局 modal
 * 由 Index.ets 渲染(覆盖 tabbar)。Home 监听 monthPickerStore.pendingValue
 * 写回 month。
 *
 * ponytail: 三段 Row 平铺,不靠 Stack + Transparent hit-test 技巧
 * (那个方案在 column 透明背景上 hit 不可靠)。
 */
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { addMonths, formatMonthCN } from '../utils/date'
import { getMonthPicker } from '../stores/month-picker'

@Component
export struct MonthPicker {
  @Link value: string
  @Prop compact: boolean = false
  onChange: () => void = () => {}

  private store = getMonthPicker()

  build() {
    Row() {
      // 左箭头
      Row() {
        Image($r('app.media.arrow_left'))
          .width(14).height(14)
          .fillColor(resolveTheme(themeStore.effective).colors.text)
      }
      .width(44).height(40)
      .justifyContent(FlexAlign.Center)
      .onClick((): void => { this.value = addMonths(this.value, -1) })

      // 中间月份:点开 modal
      Row() {
        Text(formatMonthCN(this.value))
          .fontSize(this.compact ? 13 : 15)
          .fontWeight(FontWeight.Medium)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
      }
      .layoutWeight(1).height(40)
      .justifyContent(FlexAlign.Center)
      .onClick((): void => { this.store.open(this.value) })

      // 右箭头
      Row() {
        Image($r('app.media.arrow_right'))
          .width(14).height(14)
          .fillColor(resolveTheme(themeStore.effective).colors.text)
      }
      .width(44).height(40)
      .justifyContent(FlexAlign.Center)
      .onClick((): void => { this.value = addMonths(this.value, 1) })
    }
    .width('100%').height(40)
    .border({ width: 1, color: resolveTheme(themeStore.effective).colors.divider })
    .borderRadius(16)
  }
}