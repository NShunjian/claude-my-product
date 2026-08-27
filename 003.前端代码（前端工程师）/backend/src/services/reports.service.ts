import type { RowDataPacket } from 'mysql2'
import { getPool } from '../db/pool.js'
import type { CategoryType } from '../types/index.js'

interface CategoryAggRow extends RowDataPacket {
  category_id: number | null
  uuid: string | null
  name: string | null
  icon: string | null
  color: string | null
  total: number
}

interface DailyRow extends RowDataPacket {
  d: number
  income: number
  expense: number
}

interface MonthlySummaryRow extends RowDataPacket {
  month: string
  total_income: number
  total_expense: number
}

interface YearlyMonthlyRow extends RowDataPacket {
  m: number
  income: number
  expense: number
}

const lastMonth = (ym: string): string => {
  const [y, m] = ym.split('-').map(Number)
  if (m === 1) return `${y - 1}-12`
  return `${y}-${String(m - 1).padStart(2, '0')}`
}

const aggregateByCategory = async (
  userId: number,
  fromDate: string,
  toDate: string,
  type: CategoryType,
): Promise<{ categoryId: string; name: string; icon: string; color: string; total: number }[]> => {
  const pool = getPool()
  const [rows] = await pool.query<CategoryAggRow[]>(
    `SELECT c.id AS category_id, c.uuid, c.name, c.icon, c.color,
            COALESCE(SUM(r.amount), 0) AS total
       FROM categories c
       LEFT JOIN records r ON r.category_id = c.id
                          AND r.deleted_at IS NULL
                          AND r.user_id = ?
                          AND r.type = ?
                          AND r.record_date BETWEEN ? AND ?
      WHERE c.type = ? AND c.is_active = 1
      GROUP BY c.id
     HAVING total > 0
      ORDER BY total DESC`,
    [userId, type, fromDate, toDate, type],
  )
  return rows.map((r) => ({
    categoryId: r.uuid ?? '',
    name: r.name ?? '',
    icon: r.icon ?? '',
    color: r.color ?? '',
    total: Number(r.total),
  }))
}

const monthBounds = (ym: string): { from: string; to: string } => {
  const [y, m] = ym.split('-').map(Number)
  const lastDay = new Date(y, m, 0).getDate()
  return { from: `${ym}-01`, to: `${ym}-${String(lastDay).padStart(2, '0')}` }
}

export const getMonthlyReport = async (
  userId: number,
  month: string,
): Promise<{
  month: string
  totalIncome: number
  totalExpense: number
  netSavings: number
  lastMonth: { totalIncome: number; totalExpense: number; netSavings: number } | null
  incomeByCategory: Awaited<ReturnType<typeof aggregateByCategory>>
  expenseByCategory: Awaited<ReturnType<typeof aggregateByCategory>>
  dailyData: { day: number; income: number; expense: number }[]
}> => {
  const pool = getPool()
  const { from, to } = monthBounds(month)
  const [y, m] = month.split('-').map(Number)
  const daysInMonth = new Date(y, m, 0).getDate()

  // 当月汇总
  const [summary] = await pool.query<MonthlySummaryRow[]>(
    `SELECT DATE_FORMAT(record_date, '%Y-%m') AS month,
            COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) AS total_income,
            COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) AS total_expense
       FROM records
      WHERE user_id = ? AND deleted_at IS NULL
        AND record_date BETWEEN ? AND ?
      GROUP BY DATE_FORMAT(record_date, '%Y-%m')`,
    [userId, from, to],
  )
  const totalIncome = Number(summary[0]?.total_income ?? 0)
  const totalExpense = Number(summary[0]?.total_expense ?? 0)

  // 上月汇总
  const prevMonth = lastMonth(month)
  const { from: prevFrom, to: prevTo } = monthBounds(prevMonth)
  const [prevSummary] = await pool.query<RowDataPacket[]>(
    `SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) AS total_income,
            COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) AS total_expense
       FROM records
      WHERE user_id = ? AND deleted_at IS NULL
        AND record_date BETWEEN ? AND ?`,
    [userId, prevFrom, prevTo],
  )
  const lastMonthData = prevSummary[0]
    ? {
        totalIncome: Number(prevSummary[0].total_income),
        totalExpense: Number(prevSummary[0].total_expense),
        netSavings: Number(prevSummary[0].total_income) - Number(prevSummary[0].total_expense),
      }
    : null

  // 每日收支
  const [dailyRows] = await pool.query<DailyRow[]>(
    `SELECT DAY(record_date) AS d,
            COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) AS income,
            COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) AS expense
       FROM records
      WHERE user_id = ? AND deleted_at IS NULL
        AND record_date BETWEEN ? AND ?
      GROUP BY DAY(record_date)`,
    [userId, from, to],
  )
  const dailyMap = new Map<number, { income: number; expense: number }>()
  for (const r of dailyRows) {
    dailyMap.set(r.d, { income: Number(r.income), expense: Number(r.expense) })
  }
  const dailyData = Array.from({ length: daysInMonth }, (_, i) => {
    const day = i + 1
    const d = dailyMap.get(day) ?? { income: 0, expense: 0 }
    return { day, income: d.income, expense: d.expense }
  })

  const incomeByCategory = await aggregateByCategory(userId, from, to, 'income')
  const expenseByCategory = await aggregateByCategory(userId, from, to, 'expense')

  return {
    month,
    totalIncome,
    totalExpense,
    netSavings: totalIncome - totalExpense,
    lastMonth: lastMonthData,
    incomeByCategory,
    expenseByCategory,
    dailyData,
  }
}

export const getYearlyReport = async (
  userId: number,
  year: number,
): Promise<{
  year: number
  totalIncome: number
  totalExpense: number
  netSavings: number
  monthlyData: { month: number; income: number; expense: number }[]
  expenseByCategory: { categoryId: string; name: string; icon: string; color: string; total: number }[]
}> => {
  const pool = getPool()
  const from = `${year}-01-01`
  const to = `${year}-12-31`

  const [summary] = await pool.query<MonthlySummaryRow[]>(
    `SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) AS total_income,
            COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) AS total_expense
       FROM records
      WHERE user_id = ? AND deleted_at IS NULL
        AND record_date BETWEEN ? AND ?`,
    [userId, from, to],
  )
  const totalIncome = Number(summary[0]?.total_income ?? 0)
  const totalExpense = Number(summary[0]?.total_expense ?? 0)

  const [monthRows] = await pool.query<YearlyMonthlyRow[]>(
    `SELECT MONTH(record_date) AS m,
            COALESCE(SUM(CASE WHEN type='income' THEN amount ELSE 0 END), 0) AS income,
            COALESCE(SUM(CASE WHEN type='expense' THEN amount ELSE 0 END), 0) AS expense
       FROM records
      WHERE user_id = ? AND deleted_at IS NULL
        AND record_date BETWEEN ? AND ?
      GROUP BY MONTH(record_date)`,
    [userId, from, to],
  )
  const monthMap = new Map<number, { income: number; expense: number }>()
  for (const r of monthRows) {
    monthMap.set(r.m, { income: Number(r.income), expense: Number(r.expense) })
  }
  const monthlyData = Array.from({ length: 12 }, (_, i) => {
    const month = i + 1
    const d = monthMap.get(month) ?? { income: 0, expense: 0 }
    return { month, income: d.income, expense: d.expense }
  })

  const expenseByCategory = await aggregateByCategory(userId, from, to, 'expense')

  return {
    year,
    totalIncome,
    totalExpense,
    netSavings: totalIncome - totalExpense,
    monthlyData,
    expenseByCategory,
  }
}