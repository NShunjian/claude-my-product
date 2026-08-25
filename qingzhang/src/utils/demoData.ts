import dayjs from 'dayjs'
import { db } from '../db'
import { v4 as uuidv4 } from 'uuid'

export const seedDemoData = async () => {
  const recordCount = await db.records.count()
  if (recordCount > 0) return

  const categories = await db.categories.toArray()
  const accounts = await db.accounts.toArray()
  if (categories.length === 0 || accounts.length === 0) return

  const expenseCategories = categories.filter((c) => c.type === 'expense')
  const incomeCategories = categories.filter((c) => c.type === 'income')
  const accountIds = accounts.map((a) => a.id)

  const today = dayjs()
  const demoRecords: { type: 'expense' | 'income'; categoryId: string; amount: number; accountId: string; note: string; recordDate: string }[] = []

  // 生成近3个月的示例数据
  for (let monthOffset = 0; monthOffset < 3; monthOffset++) {
    const month = today.subtract(monthOffset, 'month')
    const daysInMonth = month.daysInMonth()

    // 工资收入
    demoRecords.push({
      type: 'income',
      categoryId: incomeCategories.find((c) => c.name === '工资')?.id || incomeCategories[0].id,
      amount: 12500,
      accountId: accountIds[0],
      note: '月薪',
      recordDate: month.date(10).format('YYYY-MM-DD'),
    })

    // 每日支出
    for (let d = 1; d <= daysInMonth; d += Math.floor(Math.random() * 3) + 1) {
      const cat = expenseCategories[Math.floor(Math.random() * expenseCategories.length)]
      const amount = Math.round((Math.random() * 100 + 10) * 100) / 100
      demoRecords.push({
        type: 'expense',
        categoryId: cat.id,
        amount,
        accountId: accountIds[Math.floor(Math.random() * accountIds.length)],
        note: ['早餐', '午餐', '晚餐', '地铁', '超市', '奶茶', '电影票', '话费'][Math.floor(Math.random() * 8)],
        recordDate: month.date(d).format('YYYY-MM-DD'),
      })
    }
  }

  const now = Date.now()
  await db.records.bulkAdd(
    demoRecords.map((r, i) => ({
      ...r,
      id: uuidv4(),
      createdAt: now + i,
      updatedAt: now + i,
    }))
  )
}
