/**
 * 分类展示规则:与 uniapp utils/category-presentation.ts 1:1 对齐。
 * ponytail: 14 条内置预设(8 支出 + 5 收入 + 1 fallback)+ 自定义分类走后端颜色 / emoji。
 */

export interface CategoryPresentation { icon: string; color: string; solid?: boolean }

interface PresetEntry { icon: string; color: string; keywords?: string[] }

const EXPENSE_PRESETS: PresetEntry[] = [
  { icon: '🍔', color: '#ED8936', keywords: ['餐饮', 'food', 'meal', 'eat', '饭', '餐'] },
  { icon: '🛍️', color: '#805AD5', keywords: ['购物', 'shop', 'mall'] },
  { icon: '🚗', color: '#4299E1', keywords: ['交通', 'transport', '车'] },
  { icon: '🏠', color: '#319795', keywords: ['住房', 'home', 'house', '房租'] },
  { icon: '🎮', color: '#ED64A6', keywords: ['娱乐', 'fun', 'game'] },
  { icon: '💊', color: '#E53E3E', keywords: ['医疗', 'medicine', 'health'] },
  { icon: '🎓', color: '#3b82f6', keywords: ['教育', 'education', 'study'] },
  { icon: '📱', color: '#6366f1', keywords: ['通讯', 'phone', 'mobile'] },
]

const INCOME_PRESETS: PresetEntry[] = [
  { icon: '💰', color: '#10b981', keywords: ['工资', 'salary', 'wage'] },
  { icon: '🎁', color: '#ec4899', keywords: ['红包', 'gift', 'bonus'] },
  { icon: '💼', color: '#3b82f6', keywords: ['兼职', 'parttime', 'work'] },
  { icon: '📈', color: '#6366f1', keywords: ['投资', 'invest', 'stock'] },
  { icon: '💵', color: '#84cc16', keywords: ['其他收入', 'other', 'income'] },
]

export const FALLBACK_ICON = '⋯'
export const FALLBACK_COLOR = '#727782'

function matchPreset(name: string, type: 'expense' | 'income', icon?: string): PresetEntry {
  const list = type === 'expense' ? EXPENSE_PRESETS : INCOME_PRESETS
  if (icon) {
    for (const p of list) {
      if (p.icon === icon) return p
    }
  }
  const lower = name.toLowerCase()
  for (const p of list) {
    if (p.keywords) {
      for (const k of p.keywords) {
        if (lower.includes(k.toLowerCase())) return p
      }
    }
  }
  return list[0]
}

export interface CategoryLike { name: string; type: 'expense' | 'income'; icon?: string; color?: string; isPreset?: boolean }

export function categoryPresentation(c: CategoryLike): CategoryPresentation {
  if (c.isPreset) {
    const p = matchPreset(c.name, c.type, c.icon)
    return { icon: p.icon, color: p.color }
  }
  const color = c.color ?? ''
  return { icon: c.icon ?? '', color: color || FALLBACK_COLOR, solid: !c.icon }
}

