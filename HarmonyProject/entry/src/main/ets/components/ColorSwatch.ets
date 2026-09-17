/**
 * ColorSwatch:对齐 uniapp components/ColorSwatch.vue 1:1。
 */
@Component
export struct ColorSwatch {
  @Prop color: string = '#FFFFFF'
  @Prop selected: boolean = false
  @Prop diameter: number = 32
  @Prop white: boolean = false
  onTap: (color: string) => void = () => {}

  build() {
    Column() {
      if (this.selected) {
        Text('✓')
          .fontSize(20)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .lineHeight(22)
      }
    }
    .width(this.diameter)
    .height(this.diameter)
    .borderRadius(this.diameter / 2)
    .backgroundColor(this.color)
    .border({
      width: this.selected || this.white ? 2 : 0,
      color: this.selected ? '#0F172A' : '#0F172A',
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => this.onTap(this.color))
  }
}
