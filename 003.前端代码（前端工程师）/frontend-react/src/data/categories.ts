export type CategoryKind = 'expense' | 'income'

export interface Category {
  id: string
  name: string
  icon: string // Material Symbols name
  colorToken: 'cat-pink' | 'cat-blue' | 'cat-purple' | 'cat-teal' | 'cat-brown' | 'secondary' | 'outline'
  kind: CategoryKind
}

export const EXPENSE_CATEGORIES: Category[] = [
  { id: 'food', name: '餐饮', icon: 'restaurant', colorToken: 'cat-pink', kind: 'expense' },
  { id: 'transport', name: '交通', icon: 'directions_bus', colorToken: 'cat-blue', kind: 'expense' },
  { id: 'shopping', name: '购物', icon: 'shopping_bag', colorToken: 'cat-pink', kind: 'expense' },
  { id: 'entertainment', name: '娱乐', icon: 'sports_esports', colorToken: 'cat-purple', kind: 'expense' },
  { id: 'housing', name: '居住', icon: 'home', colorToken: 'cat-brown', kind: 'expense' },
  { id: 'medical', name: '医疗', icon: 'local_hospital', colorToken: 'cat-teal', kind: 'expense' },
  { id: 'education', name: '教育', icon: 'school', colorToken: 'secondary', kind: 'expense' },
  { id: 'comm', name: '通讯', icon: 'smartphone', colorToken: 'outline', kind: 'expense' },
]

export const INCOME_CATEGORIES: Category[] = [
  { id: 'salary', name: '工资', icon: 'payments', colorToken: 'secondary', kind: 'income' },
  { id: 'bonus', name: '奖金', icon: 'redeem', colorToken: 'cat-purple', kind: 'income' },
  { id: 'investment', name: '投资', icon: 'trending_up', colorToken: 'cat-teal', kind: 'income' },
  { id: 'transfer', name: '转账', icon: 'swap_horiz', colorToken: 'cat-blue', kind: 'income' },
  { id: 'other', name: '其他', icon: 'more_horiz', colorToken: 'outline', kind: 'income' },
]
