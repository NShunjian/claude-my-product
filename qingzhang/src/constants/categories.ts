import { Category } from '../types'

export const EXPENSE_CATEGORIES = [
  { name: '餐饮', icon: '🍜', color: '#ED8936' },
  { name: '交通', icon: '🚗', color: '#4299E1' },
  { name: '购物', icon: '🛒', color: '#ED64A6' },
  { name: '娱乐', icon: '🎮', color: '#805AD5' },
  { name: '居住', icon: '', color: '#8B6E4E' },
  { name: '医疗', icon: '💊', color: '#E53E3E' },
  { name: '教育', icon: '📚', color: '#319795' },
  { name: '通讯', icon: '', color: '#718096' },
  { name: '其他', icon: '📌', color: '#A0AEC0' },
]

export const INCOME_CATEGORIES = [
  { name: '工资', icon: '💰', color: '#38A169' },
  { name: '兼职', icon: '💼', color: '#4299E1' },
  { name: '理财', icon: '📈', color: '#ED8936' },
  { name: '红包', icon: '🧧', color: '#E53E3E' },
  { name: '其他', icon: '', color: '#A0AEC0' },
]

export const createPresetCategories = (): Category[] => {
  const categories: Category[] = []
  let order = 0

  EXPENSE_CATEGORIES.forEach((cat) => {
    categories.push({
      id: `expense-${cat.name}`,
      type: 'expense',
      name: cat.name,
      icon: cat.icon,
      color: cat.color,
      isPreset: true,
      sortOrder: order++,
    })
  })

  INCOME_CATEGORIES.forEach((cat) => {
    categories.push({
      id: `income-${cat.name}`,
      type: 'income',
      name: cat.name,
      icon: cat.icon,
      color: cat.color,
      isPreset: true,
      sortOrder: order++,
    })
  })

  return categories
}
