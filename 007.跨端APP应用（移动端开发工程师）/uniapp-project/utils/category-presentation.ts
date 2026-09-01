/**
 * 后端 category → 前端展示层派生。
 *
 * 后端 icon 存 emoji、color 存 '#RRGGBB'。
 * 对齐 React 前端 (lib/category-presentation.ts),把后端 ID 转成:
 *   - Material Symbols 图标名(H5 上加载 MS Outlined 字体后渲染成轮廓图标)
 *   - 语义 hex 颜色(对齐 React colorToken)
 *
 * 查找键:统一用 `${type}-${name}`(后端 ID 形如 'preset-expense-餐饮' 也兼容,
 * 通过 normalizeId 去掉 'preset-' 前缀)。
 */
import type { Category } from '@/api/categories'

export interface CategoryPresentation {
  /** Material Symbols 图标名(用作 <text>{{ icon }}</text> 文本,经字体字形渲染成图标) */
  icon: string
  /** 分类语义色 hex(对齐 React ColorToken) */
  color: string
}

const COLOR_HEX: Record<string, string> = {
  pink: '#ED64A6',
  blue: '#4299E1',
  purple: '#805AD5',
  teal: '#319795',
  brown: '#8B6E4E',
  orange: '#F59E0B',
  cyan: '#06B6D4',
  indigo: '#6366F1',
  green: '#10b981', // income 工资 — 对齐 React secondary
  outline: '#727782',
}

interface Entry { icon: string; token: string }

const TABLE: Record<string, Entry> = {
  // 支出:每类独立颜色(对齐 React)
  'expense-餐饮': { icon: 'restaurant', token: 'blue' },
  'expense-交通': { icon: 'directions_bus', token: 'cyan' },
  'expense-购物': { icon: 'shopping_bag', token: 'pink' },
  'expense-娱乐': { icon: 'sports_esports', token: 'purple' },
  'expense-居住': { icon: 'home', token: 'brown' },
  'expense-医疗': { icon: 'medical_services', token: 'teal' },
  'expense-教育': { icon: 'school', token: 'orange' },
  'expense-通讯': { icon: 'phone_iphone', token: 'indigo' },
  'expense-其他': { icon: 'more_horiz', token: 'outline' },
  // 收入:每类独立颜色
  'income-工资':  { icon: 'payments', token: 'green' },
  'income-兼职':  { icon: 'work', token: 'cyan' },
  'income-理财':  { icon: 'trending_up', token: 'indigo' },
  'income-红包':  { icon: 'card_giftcard', token: 'pink' },
  'income-其他':  { icon: 'more_horiz', token: 'outline' },
}

const FALLBACK: Entry = { icon: 'more_horiz', token: 'outline' }

function normalizeKey(c: Pick<Category, 'id' | 'type' | 'name'>): string {
  // 优先用 id 去 preset- 前缀;再退回 `${type}-${name}` 兜底(兼容自定义分类或 ID 格式差异)
  const stripped = c.id.replace(/^preset-/, '')
  if (TABLE[stripped]) return stripped
  return `${c.type}-${c.name}`
}

export function categoryPresentation(c: Pick<Category, 'id' | 'type' | 'name'>): CategoryPresentation {
  const entry = TABLE[normalizeKey(c)] ?? FALLBACK
  return { icon: entry.icon, color: COLOR_HEX[entry.token] ?? COLOR_HEX.outline }
}

/** 仅取 MS 图标名(给已经自己用 cat.color 的场景,例如 breakdown 卡) */
export function categoryMaterialIcon(c: Pick<Category, 'id' | 'type' | 'name'>): string {
  return categoryPresentation(c).icon
}
