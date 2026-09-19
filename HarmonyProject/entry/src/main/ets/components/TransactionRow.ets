/**
 * TransactionRow:对齐 uniapp components/TransactionRow.vue 1:1。
 * ponytail: 主文 = note || category.name;副文 = "category · account";右侧 ¥ + 时间戳。
 */
import type { Record, Account, Category } from '../model/Types'
import { formatAmount, formatDateTime } from '../utils/finance'
import { categoryPresentation, CategoryLike } from '../utils/category-presentation'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import { useLanguage } from '../i18n/useLanguage'

@Component
export struct TransactionRow {
  @Prop record: Record | null = null
  @Prop category: Category | null = null
  @Prop account: Account | null = null
  onTap: (id: string) => void = () => {}

  private lang = useLanguage()

  private categoryIcon(): string {
    if (!this.category) return '⋯'
    const catLike: CategoryLike = {
      name: this.category.name, type: this.category.type,
      icon: this.category.icon, color: this.category.color, isPreset: this.category.isPreset,
    }
    return categoryPresentation(catLike).icon
  }

  // 副文 = "category · account",缺哪个就只显示有的那个
  private subText(): string {
    const parts: string[] = []
    if (this.category) parts.push(this.category.name)
    if (this.account) parts.push(this.account.name)
    return parts.join(' · ')
  }

  // ponytail: 调淡图标背景。后端 color 是饱和 hex,直接当背景太亮;
  // ArkUI 不支持 8 位 hex('#RRGGBBAA')的 alpha 解析,改用 rgba() 字符串拼 14% alpha,
  // 等价于 uniapp catTint(rgba(.., 0.14))。
  private catTintBg(): string {
    const hex = this.category?.color || '#727782'
    const h = hex.replace('#', '')
    if (h.length !== 6) return hex
    const r = parseInt(h.slice(0, 2), 16)
    const g = parseInt(h.slice(2, 4), 16)
    const b = parseInt(h.slice(4, 6), 16)
    return `rgba(${r}, ${g}, ${b}, 0.14)`
  }

  build() {
    Row() {
      Row() {
        Text(this.categoryIcon())
          .fontSize(22)
          .fontColor(this.category?.color || '#727782')
      }
      .width(44).height(44).borderRadius(22)
      // 图标背景:后端 color + 14% alpha(对齐 uniapp catTint,调淡避免抢眼)
      .backgroundColor(this.catTintBg())
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Column() {
        // 主文:note 优先,没 note 就用 category.name
        Text((this.record?.note && this.record.note.length > 0) ? this.record.note : (this.category?.name ?? '—'))
          .fontSize(15)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.subText().length > 0) {
          Text(this.subText())
            .fontSize(12)
            .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      // 右侧:金额 + 记账时间
      Column() {
        Text(`${this.record?.type === 'income' ? '+' : '-'}¥${formatAmount(this.record?.amount ?? 0)}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.record?.type === 'income' ? '#10B981' : resolveTheme(themeStore.effective).colors.error)
        if (this.record?.createdAt) {
          Text(`${this.lang.t('record.recordTime')}: ${formatDateTime(this.record.createdAt)}`)
            .fontSize(11)
            .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    // 卡片外层距屏 10,这里再加 10 让 icon 距屏 20(uniapp 标题 Row padding 16,
    // 这里 icon 也从卡片左 10 起 → 屏 20,视觉上跟标题"最近交易"对齐卡片内边距)。
    .padding({ left: 10, right: 16, top: 12, bottom: 12 })
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.record && this.onTap(this.record.id))
  }
}