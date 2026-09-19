/**
 * 后端 category → 前端展示层派生。
 *
 * 所有分类的颜色 + 图标全部走后端存的 `c.color` / `c.icon`,前端不再维护预设表。
 * 这样所有端(uniapp / Harmony / Flutter)都用同一份后端数据,保证一处改色,各端跟随。
 *
 * 兜底:后端字段为空 / 无 category → FALLBACK_COLOR + FALLBACK_ICON。
 */
import type { Category } from '@/api/categories'

export interface CategoryPresentation {
  /** emoji 图标(后端存) */
  icon: string
  /** 分类 hex 颜色(后端存) */
  color: string
}

// 跨端安全占位
export const FALLBACK_ICON = '⋯'
export const FALLBACK_COLOR = '#727782'

// 检测 Material Symbols 风格的 ligature 名(如 'restaurant' / 'fastfood' / 'more_horiz')。
// 微信小程序/H5 默认不加载 MS Outlined 字体,直接渲染会显示字面文字,当作无效输入处理。
function isProbablyMsLigatureName(s: string): boolean {
  return /^[a-zA-Z0-9_]+$/.test(s)
}

export function categoryPresentation(c: Pick<Category, 'id' | 'type' | 'name'>): CategoryPresentation {
  const icon = (c as Partial<Category>).icon
  const color = (c as Partial<Category>).color
  const safeIcon = icon && !isProbablyMsLigatureName(icon) ? icon : FALLBACK_ICON
  const safeColor = color && color.length > 0 ? color : FALLBACK_COLOR
  return { icon: safeIcon, color: safeColor }
}

/** 仅取图标名(给已经自己用 cat.color 的场景,例如 breakdown 卡) */
export function categoryMaterialIcon(c: Pick<Category, 'id' | 'type' | 'name'>): string {
  return categoryPresentation(c).icon
}
