/**
 * 分类展示规则:颜色 / 图标全部走后端,前端不再写预设表。
 * ponytail: 所有端(Harmony / uniapp / Flutter)都用同一个后端 category.color + category.icon,
 * 保证一处改色,所有端跟随;前端只兜底 fallback。
 */

export interface CategoryPresentation { icon: string; color: string; solid?: boolean }

export const FALLBACK_ICON = '⋯'
export const FALLBACK_COLOR = '#727782'

export interface CategoryLike { name: string; type: 'expense' | 'income'; icon?: string; color?: string; isPreset?: boolean }

export function categoryPresentation(c: CategoryLike): CategoryPresentation {
  // 颜色:直接走后端存的 c.color;空 / 无 → FALLBACK_COLOR
  const color = c.color && c.color.length > 0 ? c.color : FALLBACK_COLOR
  // 图标:直接走后端存的 c.icon;空 / 无 → FALLBACK_ICON
  const icon = c.icon && c.icon.length > 0 ? c.icon : FALLBACK_ICON
  return { icon: icon, color: color, solid: !c.icon }
}
