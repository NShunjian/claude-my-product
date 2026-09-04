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
 *
 * 自定义分类:TABLE 查不到时,直接用后端存的 `c.icon`/`c.color`(用户在 Settings 选的 emoji 和颜色),
 * 不再走 FALLBACK('⋯' + 灰色),否则用户在自定义分类里选的图标在快速记账弹窗里看不到。
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

// icon 字段:微信小程序不支持 Material Symbols Outlined 字体的 ligature,
// 直接渲染会显示 'restaurant' / 'work' 这种字面文字。这里统一用 emoji 跨平台渲染。
// H5 也会跟着用 emoji(注:不影响视觉一致性,emoji 在所有平台一致)。
const TABLE: Record<string, Entry> = {
  // 支出
  'expense-餐饮': { icon: '🍽️', token: 'blue' },
  'expense-交通': { icon: '🚌', token: 'cyan' },
  'expense-购物': { icon: '🛍️', token: 'pink' },
  'expense-娱乐': { icon: '🎮', token: 'purple' },
  'expense-居住': { icon: '🏠', token: 'brown' },
  'expense-医疗': { icon: '🏥', token: 'teal' },
  'expense-教育': { icon: '🎓', token: 'orange' },
  'expense-通讯': { icon: '📱', token: 'indigo' },
  'expense-其他': { icon: '🗂️', token: 'outline' },
  // 收入
  'income-工资':  { icon: '💵', token: 'green' },
  'income-兼职':  { icon: '💼', token: 'cyan' },
  'income-理财':  { icon: '📈', token: 'indigo' },
  'income-红包':  { icon: '🧧', token: 'pink' },
  'income-其他':  { icon: '🗂️', token: 'outline' },
}

// 导出供 TransactionRow 等组件复用:null/无 category 时的安全占位(unicode 字符,跨平台稳)。
export const FALLBACK_ICON = '⋯'
export const FALLBACK_COLOR = '#727782'

function lookupKey(c: Pick<Category, 'id' | 'type' | 'name'>): string {
  // 优先用 id 去 preset- 前缀;再退回 `${type}-${name}` 兜底(兼容自定义分类或 ID 格式差异)
  const stripped = c.id.replace(/^preset-/, '')
  if (TABLE[stripped]) return stripped
  return `${c.type}-${c.name}`
}

// 检测 Material Symbols 风格的 ligature 名(如 'restaurant' / 'fastfood' / 'more_horiz')。
// 微信小程序/H5 默认不加载 MS Outlined 字体,直接渲染会显示字面文字,因此当作无效输入处理。
function isProbablyMsLigatureName(s: string): boolean {
  return /^[a-zA-Z0-9_]+$/.test(s)
}

/**
 * 自定义分类兜底:用后端存的 c.icon/c.color(用户在 Settings 自定义分类页选的)。
 * 传 undefined/空的对象时(如 report 场景只有 id+name),返回 FALLBACK。
 *
 * 若 c.icon 看起来是 MS ligature 名(纯 ASCII 字母/数字/下划线)而非 emoji,
 * 一律退回 FALLBACK_ICON —— 跨端展示页直接渲染会显示 'restaurant' / 'fastfood' 字面文字。
 */
function customPresentation(c: Pick<Category, 'id' | 'type' | 'name'>): CategoryPresentation {
  const icon = (c as Partial<Category>).icon
  const color = (c as Partial<Category>).color
  if (icon && color && !isProbablyMsLigatureName(icon)) return { icon, color }
  return { icon: FALLBACK_ICON, color: color || FALLBACK_COLOR }
}

export function categoryPresentation(c: Pick<Category, 'id' | 'type' | 'name'>): CategoryPresentation {
  const entry = TABLE[lookupKey(c)]
  if (entry) return { icon: entry.icon, color: COLOR_HEX[entry.token] ?? COLOR_HEX.outline }
  return customPresentation(c)
}

/** 仅取 MS 图标名(给已经自己用 cat.color 的场景,例如 breakdown 卡) */
export function categoryMaterialIcon(c: Pick<Category, 'id' | 'type' | 'name'>): string {
  return categoryPresentation(c).icon
}
