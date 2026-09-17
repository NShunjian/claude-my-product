/**
 * TransactionRow:对齐 uniapp components/TransactionRow.vue 1:1。
 */
import type { Record, Account, Category } from '../model/Types'
import { formatAmount } from '../utils/finance'
import { categoryPresentation, CategoryLike } from '../utils/category-presentation'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'

@Component
export struct TransactionRow {
  @Prop record: Record | null = null
  @Prop category: Category | null = null
  @Prop account: Account | null = null
  onTap: (id: string) => void = () => {}

  private categoryIcon(): string {
    if (!this.category) return '⋯'
    const catLike: CategoryLike = {
      name: this.category.name, type: this.category.type,
      icon: this.category.icon, color: this.category.color, isPreset: this.category.isPreset,
    }
    return categoryPresentation(catLike).icon
  }

  build() {
    Row() {
      Row() {
        Text(this.categoryIcon())
          .fontSize(22)
          .fontColor(this.category?.color || '#727782')
      }
      .width(44).height(44).borderRadius(22)
      .backgroundColor((this.category?.color || '#727782') + '22')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Column() {
        Text(this.category?.name ?? '—')
          .fontSize(15)
          .fontColor(resolveTheme(themeStore.effective).colors.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.account?.name ?? '')
          .fontSize(12)
          .fontColor(resolveTheme(themeStore.effective).colors.textVariant)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      Text(`${this.record?.type === 'income' ? '+' : '-'}${formatAmount(this.record?.amount ?? 0)}`)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.record?.type === 'income' ? '#10B981' : resolveTheme(themeStore.effective).colors.error)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
    .border({ width: { bottom: 1 }, color: resolveTheme(themeStore.effective).colors.divider })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.record && this.onTap(this.record.id))
  }
}
