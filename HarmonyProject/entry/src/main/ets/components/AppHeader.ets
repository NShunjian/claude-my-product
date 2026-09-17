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
        if (this.back) {
          Text('‹')
            .fontSize(28)
            .fontWeight(FontWeight.Medium)
            .fontColor(resolveTheme(themeStore.effective).colors.text)
            .width(48).height(48)
            .textAlign(TextAlign.Center)
            .onClick(() => this.onBack())
        }
        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
          .layoutWeight(1)
          .margin({ left: this.back ? 0 : 16 })
          .textAlign(this.back ? TextAlign.Start : TextAlign.Start)
        Row() { this.right() }
      }
      .height(56)
      .width('100%')
      .padding({ left: 8, right: 16 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bg)
  }
}
