/**
 * MonthPickerModal:对齐 uniapp MonthPickerModal。
 * 渲染在 Index.ets 全栈(覆盖 tabbar)。
 *
 * 结构两层 Stack:
 *   - 居中层:mask + 卡片(年份选择器 + 月份网格 + footer)
 *   - 底部层:年份底部选择器(showYearPicker 时)
 * 两者都 expandSafeArea 到系统安全区外,覆盖状态栏 + 底部导航条。
 *
 * ponytail: store 不是 @ObjectLink,组件用 @State 镜像 + subscribe 同步。
 * store 所有 mutator 都 fire() 以确保 UI 响应。
 */
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { getMonthPicker } from '../stores/month-picker'

@Component
export struct MonthPickerModal {
  @State show: boolean = false
  @State showYearPicker: boolean = false
  @State draftYear: number = new Date().getFullYear()
  @State yearPickerValue: number = new Date().getFullYear()
  private initialValue: string = ''

  private store = getMonthPicker()
  private unsub: (() => void) | null = null

  aboutToAppear(): void {
    this.syncFromStore()
    this.unsub = this.store.subscribe((): void => { this.syncFromStore() })
  }

  aboutToDisappear(): void {
    if (this.unsub) { this.unsub(); this.unsub = null }
  }

  private syncFromStore(): void {
    this.show = this.store.show
    this.showYearPicker = this.store.showYearPicker
    this.draftYear = this.store.draftYear
    this.yearPickerValue = this.store.yearPickerValue
    this.initialValue = this.store.initialValue
  }

  private buildYears(): number[] {
    const out: number[] = []
    const start = new Date().getFullYear() - 5
    for (let i = 0; i < 10; i++) out.push(start + i)
    return out
  }

  private isActive(m: number): boolean {
    if (!this.initialValue) return false
    const y = Number(this.initialValue.split('-')[0])
    const mo = Number(this.initialValue.split('-')[1])
    return y === this.draftYear && mo === m
  }

  // 选中年的初始滚动偏移:让选中项位于可视区域中间(对齐 uniapp picker-view)。
  // ponytail:List 顶部塞 2 个 padding items,所以选中年的 list 索引 = idx + 2,
  // 目标 list 索引 2(y=80,接近中心 y=100)→ initialIndex = idx。
  // 顶部/底部条目都能滚到中心选中区。
  private yearScrollIndex(): number {
    const years = this.buildYears()
    const idx = years.indexOf(this.draftYear)
    if (idx <= 0) return 0
    return idx
  }

  // 年份列表:对齐 uniapp picker-view(滚轮:选中黑色加粗,其他灰色,滚动居中项自动设为选中,无 item 分隔线)
// ponytail:顶 2 个 + 底 2 个 padding items,让首尾条目都能滚到中心选中区
  @Builder YearPickerList() {
    Stack() {
      List({ initialIndex: this.yearScrollIndex() }) {
        // 顶部 padding(2 个,让首年能滚到中心)
        ListItem() {
          Row().width('100%').height(40).backgroundColor(Color.Transparent)
        }
        ListItem() {
          Row().width('100%').height(40).backgroundColor(Color.Transparent)
        }

        ForEach(this.buildYears(), (y: number): void => {
          ListItem() {
            Text(`${y}年`).fontSize(15)
              .fontWeight(y === this.yearPickerValue ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(y === this.yearPickerValue
                ? resolveTheme(themeStore.effective).colors.text
                : resolveTheme(themeStore.effective).colors.textVariant)
              .width('100%').height(40)
              .textAlign(TextAlign.Center)
              .onClick((): void => { this.store.setYearPickerValue(y) })
          }
        }, (y: number): string => `${y}`)

        // 底部 padding(2 个,让末年能滚到中心)
        ListItem() {
          Row().width('100%').height(40).backgroundColor(Color.Transparent)
        }
        ListItem() {
          Row().width('100%').height(40).backgroundColor(Color.Transparent)
        }
      }
      .width('100%').height(200)
      .listDirection(Axis.Vertical)
      .scrollBar(BarState.Off)  // 去掉右侧滚动提示器
      // 滚动时把居中项自动设为选中(对齐 uniapp picker-view 滚轮行为)
      // ponytail:减去 2 个顶部 padding 才得到年份索引
      .onScrollIndex((_start: number, _end: number, center: number): void => {
        const years = this.buildYears()
        const yearIndex = center - 2
        if (yearIndex >= 0 && yearIndex < years.length) {
          const y = years[yearIndex]
          if (y !== this.yearPickerValue) {
            this.store.setYearPickerValue(y)
          }
        }
      })

      // ponytail:顶端渐变白带(不透明 → 透明),淡化顶边条目
      Row()
        .width('100%').height(40)
        .linearGradient({
          angle: 180,
          colors: [
            [resolveTheme(themeStore.effective).colors.bgCard, 0],
            ['rgba(255, 255, 255, 0)', 1]
          ]
        })
        .hitTestBehavior(HitTestMode.Transparent)
        .position({ x: 0, y: 0 })

      // ponytail:底端渐变白带(透明 → 不透明),淡化底边条目
      Row()
        .width('100%').height(40)
        .linearGradient({
          angle: 0,
          colors: [
            ['rgba(255, 255, 255, 0)', 0],
            [resolveTheme(themeStore.effective).colors.bgCard, 1]
          ]
        })
        .hitTestBehavior(HitTestMode.Transparent)
        .position({ x: 0, y: '100%' })
        .markAnchor({ x: 0, y: '100%' })

      // 选中行的上下两道横线(List 高 200,选中行 40 高居中,y=80/120)
      Row()
        .width('100%').height(1)
        .backgroundColor(resolveTheme(themeStore.effective).colors.divider)
        .hitTestBehavior(HitTestMode.Transparent)
        .position({ x: 0, y: 80 })

      Row()
        .width('100%').height(1)
        .backgroundColor(resolveTheme(themeStore.effective).colors.divider)
        .hitTestBehavior(HitTestMode.Transparent)
        .position({ x: 0, y: 120 })
    }
    .width('100%').height(200)
  }

  // 年份底部弹层:内容自适应高度(头部 + 280 列表),白底由外层 Stack 提供
  @Builder YearPickerSheet() {
    Column() {
      // 头部
      Row() {
        Text('取消').fontSize(14)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick((): void => { this.store.closeYearPicker() })
        Blank()
        Text('完成').fontSize(14).fontWeight(FontWeight.Medium)
          .fontColor(resolveTheme(themeStore.effective).colors.primary)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .onClick((): void => { this.store.confirmYearPicker() })
      }
      .width('100%')
      .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })

      // 年份列表
      this.YearPickerList()
    }
    .width('100%')
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }

  build() {
    // ponytail: 关闭时整个 Stack 不渲染——空 Stack 也会 hit-test 吃掉下方 Home 的滚动/点击。
    if (this.show || this.showYearPicker) {
      Stack() {
        // 居中层:mask + 卡片(只在主 modal 显时渲染)
        if (this.show) {
          Stack({ alignContent: Alignment.Center }) {
            Column().width('100%').height('100%').backgroundColor('rgba(0, 0, 0, 0.4)')
              .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
              .onClick((): void => { this.store.close() })

            Column() {
              // 年份行:对齐 uniapp,点年份按钮弹底部选择器
              Row() {
                Text('年份').fontSize(14)
                  .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                Row() {
                  Text(`${this.draftYear}年`).fontSize(14).fontWeight(FontWeight.Bold)
                    .fontColor(resolveTheme(themeStore.effective).colors.text)
                    .layoutWeight(1)
                  Text('▾').fontSize(14)
                    .fontColor(resolveTheme(themeStore.effective).colors.primary)
                }
                .layoutWeight(1).margin({ left: 12 })
                .height(36)
                .padding({ left: 12, right: 12 })
                .border({ width: 1, color: resolveTheme(themeStore.effective).colors.primary })
                .borderRadius(8)
                .alignItems(VerticalAlign.Center)
                .onClick((): void => { this.store.openYearPicker() })
              }
              .width('100%').alignItems(VerticalAlign.Center)

              // 月份网格 4×3
              Grid() {
                ForEach([1,2,3,4,5,6,7,8,9,10,11,12], (m: number): void => {
                  GridItem() {
                    Text(`${m}月`).fontSize(14).fontWeight(FontWeight.Medium)
                      .fontColor(this.isActive(m) ? '#FFFFFF' : resolveTheme(themeStore.effective).colors.text)
                      .width('100%').height(40)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(this.isActive(m)
                        ? resolveTheme(themeStore.effective).colors.primary
                        : Color.Transparent)
                      .borderRadius(8)
                      .onClick((): void => {
                        this.store.emit(`${this.draftYear}-${String(m).padStart(2, '0')}`)
                      })
                  }
                }, (m: number): string => `${m}`)
              }
              .columnsTemplate('1fr 1fr 1fr 1fr')
              .rowsTemplate('1fr 1fr 1fr')
              .columnsGap(8).rowsGap(8)
              .width('100%').height(160)
              .margin({ top: 20 })

              // 底部 footer
              Row() {
                Text('清除').fontSize(14)
                  .fontColor(resolveTheme(themeStore.effective).colors.primary)
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .onClick((): void => { this.store.close() })
                Blank()
                Text('本月').fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor(resolveTheme(themeStore.effective).colors.primary)
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .onClick((): void => {
                    const d = new Date()
                    this.store.emit(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`)
                  })
              }
              .width('100%').padding({ top: 16 })
              .border({ width: { top: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
              .margin({ top: 8 })
            }
            .width('80%').padding(20)
            .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
            .borderRadius(16)
          }
          .width('100%').height('100%')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }

        // 底部层:包一层白底 Column + expandSafeArea 让白底穿透到屏幕底,YearPickerSheet 内容贴底
        if (this.showYearPicker) {
          Stack({ alignContent: Alignment.Bottom }) {
            Column() {
              this.YearPickerSheet()
            }
            .width('100%')
            .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
            .borderRadius({ topLeft: 16, topRight: 16 })
            .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          }
          .width('100%').height('100%')
        }
      }
      .width('100%').height('100%')
    }
  }
}