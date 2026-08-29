/**
 * 后端 category → 前端展示用 category 的派生表。
 *
 * 后端 category.icon 是 emoji，category.color 是 '#RRGGBB'。
 * 前端 UI（RecordModal / CategoryBreakdown / Report）使用 Material Symbols 图标 + colorToken（语义颜色 token）。
 *
 * 此处按后端 UUID（如 'expense-餐饮'）写死映射，避免每次渲染都做 emoji 推断。
 *
 * Report 场景下只有 CategoryTotal（id + 名称 + emoji），没有 ApiCategory 对象，所以提供基于 id 字符串的查询函数。
 */
import type { Category as ApiCategory } from '../api/categories'
import type { ColorToken } from './finance-types'

export type { ColorToken }

export interface CategoryPresentation {
  /** Material Symbols icon name */
  icon: string
  colorToken: ColorToken
  /** hex 颜色，用于图表（DonutChart 等） */
  colorHex: string
}

const COLOR_HEX: Record<ColorToken, string> = {
  'cat-pink': '#ED64A6',
  'cat-blue': '#4299E1',
  'cat-purple': '#805AD5',
  'cat-teal': '#319795',
  'cat-brown': '#8B6E4E',
  'cat-orange': '#F59E0B',
  'cat-cyan': '#06B6D4',
  'cat-indigo': '#6366F1',
  secondary: '#10b981',
  outline: '#727782',
}

const TABLE: Record<string, Omit<CategoryPresentation, 'colorHex'>> = {
  // 支出：每类独立颜色（医疗青绿、教育琥珀，避免混淆）
  'expense-餐饮': { icon: 'restaurant', colorToken: 'cat-blue' },
  'expense-交通': { icon: 'directions_bus', colorToken: 'cat-cyan' },
  'expense-购物': { icon: 'shopping_bag', colorToken: 'cat-pink' },
  'expense-娱乐': { icon: 'sports_esports', colorToken: 'cat-purple' },
  'expense-居住': { icon: 'home', colorToken: 'cat-brown' },
  'expense-医疗': { icon: 'medical_services', colorToken: 'cat-teal' },
  'expense-教育': { icon: 'school', colorToken: 'cat-orange' },
  'expense-通讯': { icon: 'phone_iphone', colorToken: 'cat-indigo' },
  'expense-其他': { icon: 'more_horiz', colorToken: 'outline' },
  // 收入：每类独立颜色
  'income-工资':  { icon: 'payments', colorToken: 'secondary' },
  'income-兼职':  { icon: 'work', colorToken: 'cat-cyan' },
  'income-理财':  { icon: 'trending_up', colorToken: 'cat-indigo' },
  'income-红包':  { icon: 'card_giftcard', colorToken: 'cat-pink' },
  'income-其他':  { icon: 'more_horiz', colorToken: 'outline' },
}

function fromKey(key: string): CategoryPresentation {
  const base = TABLE[key] ?? { icon: 'more_horiz', colorToken: 'outline' }
  return { ...base, colorHex: COLOR_HEX[base.colorToken] }
}

export function getCategoryPresentation(c: ApiCategory): CategoryPresentation {
  return fromKey(c.id)
}

/** Report 场景：只有 CategoryTotal 的 id 字符串可用，按 id 查表 */
export function getCategoryPresentationById(categoryId: string): CategoryPresentation {
  return fromKey(categoryId)
}