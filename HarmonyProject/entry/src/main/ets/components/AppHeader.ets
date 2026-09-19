/**
 * AppHeader:对齐 uniapp components/AppHeader.vue 1:1。
 * ponytail: 顶部状态栏占位 + 标题 + 返回箭头。
 */
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'

@Component
export struct AppHeader {
  @Prop title: string = ''
  @Prop back: boolean = false
  @BuilderParam right: () => void = this.defaultRight
  onBack: () => void = () => {}

  @Builder defaultRight() {}

  build() {
    Column() {
      Row().height(28).width('100%')
      Row() {
        Row() {
          if (this.back) {
            Text('‹')
              .fontSize(28)
              .fontWeight(FontWeight.Medium)
              .fontColor(resolveTheme(themeStore.effective).colors.text)
              .width(48).height(48)
              .textAlign(TextAlign.Center)
              .onClick(() => this.onBack())
          }
        }.width(48)
        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Row() { this.right() }.width(48)
      }
      .height(48)
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
    .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
  }
}
