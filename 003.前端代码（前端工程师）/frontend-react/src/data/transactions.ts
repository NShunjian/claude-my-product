export interface Transaction {
  id: string
  date: string // ISO date 'YYYY-MM-DD'
  type: 'expense' | 'income'
  categoryId: string // references Category.id
  amount: number
  note: string
  accountId: string // references Account.id
}

// ~24 entries spanning Aug 2026 (today is 2026-08-26)
export const TRANSACTIONS: Transaction[] = [
  // August 2026
  { id: 't01', date: '2026-08-25', type: 'expense', categoryId: 'food', amount: 45.5, note: '午餐', accountId: 'wxpay' },
  { id: 't02', date: '2026-08-25', type: 'expense', categoryId: 'transport', amount: 8.0, note: '地铁', accountId: 'alipay' },
  { id: 't03', date: '2026-08-24', type: 'expense', categoryId: 'shopping', amount: 299.0, note: 'T恤', accountId: 'cmb' },
  { id: 't04', date: '2026-08-24', type: 'expense', categoryId: 'food', amount: 128.0, note: '朋友聚餐', accountId: 'wxpay' },
  { id: 't05', date: '2026-08-23', type: 'income', categoryId: 'salary', amount: 15000.0, note: '8月工资', accountId: 'cmb' },
  { id: 't06', date: '2026-08-22', type: 'expense', categoryId: 'housing', amount: 3500.0, note: '房租', accountId: 'cmb' },
  { id: 't07', date: '2026-08-22', type: 'expense', categoryId: 'comm', amount: 99.0, note: '手机套餐', accountId: 'alipay' },
  { id: 't08', date: '2026-08-21', type: 'expense', categoryId: 'food', amount: 32.0, note: '早餐', accountId: 'wxpay' },
  { id: 't09', date: '2026-08-20', type: 'expense', categoryId: 'entertainment', amount: 88.0, note: '电影', accountId: 'wxpay' },
  { id: 't10', date: '2026-08-20', type: 'expense', categoryId: 'shopping', amount: 156.0, note: '日用品', accountId: 'alipay' },
  { id: 't11', date: '2026-08-19', type: 'expense', categoryId: 'transport', amount: 12.0, note: '打车', accountId: 'wxpay' },
  { id: 't12', date: '2026-08-18', type: 'income', categoryId: 'investment', amount: 850.0, note: '基金收益', accountId: 'cmb' },
  { id: 't13', date: '2026-08-17', type: 'expense', categoryId: 'medical', amount: 220.0, note: '体检', accountId: 'cmb' },
  { id: 't14', date: '2026-08-16', type: 'expense', categoryId: 'food', amount: 58.0, note: '晚餐', accountId: 'alipay' },
  { id: 't15', date: '2026-08-15', type: 'expense', categoryId: 'shopping', amount: 420.0, note: '运动鞋', accountId: 'ccb' },
  { id: 't16', date: '2026-08-14', type: 'income', categoryId: 'bonus', amount: 3000.0, note: '项目奖金', accountId: 'cmb' },
  { id: 't17', date: '2026-08-13', type: 'expense', categoryId: 'education', amount: 680.0, note: '在线课程', accountId: 'alipay' },
  { id: 't18', date: '2026-08-12', type: 'expense', categoryId: 'housing', amount: 186.5, note: '水电煤', accountId: 'wxpay' },
  { id: 't19', date: '2026-08-11', type: 'expense', categoryId: 'food', amount: 25.0, note: '咖啡', accountId: 'wxpay' },
  { id: 't20', date: '2026-08-10', type: 'expense', categoryId: 'transport', amount: 5.0, note: '公交', accountId: 'alipay' },
  { id: 't21', date: '2026-08-09', type: 'income', categoryId: 'transfer', amount: 2000.0, note: '转账收款', accountId: 'alipay' },
  { id: 't22', date: '2026-08-08', type: 'expense', categoryId: 'entertainment', amount: 200.0, note: '游戏', accountId: 'wxpay' },
  { id: 't23', date: '2026-08-06', type: 'expense', categoryId: 'food', amount: 560.0, note: '周末大餐', accountId: 'cmb' },
  { id: 't24', date: '2026-08-05', type: 'income', categoryId: 'other', amount: 500.0, note: '退款', accountId: 'wxpay' },
  { id: 't25', date: '2026-08-04', type: 'expense', categoryId: 'comm', amount: 58.0, note: '宽带费', accountId: 'alipay' },
  { id: 't26', date: '2026-08-03', type: 'expense', categoryId: 'shopping', amount: 89.0, note: '书籍', accountId: 'cash' },
  { id: 't27', date: '2026-08-01', type: 'expense', categoryId: 'food', amount: 38.0, note: '早餐', accountId: 'cash' },
]
