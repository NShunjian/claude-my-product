/**
 * 为 test 用户灌入 5 年 (2021-09-01 ~ 2026-08-28) 全量测试数据
 * 用法: tsx --env-file=.env src/scripts/seed-test-user.ts
 */
import { randomUUID } from 'node:crypto'
import mysql from 'mysql2/promise'
import { env } from '../config/env.js'

// 真实的金额分布:每个分类对应的 (min, max, 每月期望条数)
const EXPENSE_RULES: Record<string, [number, number, number]> = {
  '餐饮': [25, 180, 22],         // 每天 ~1 笔小额
  '交通': [10, 120, 8],          // 地铁/打车
  '购物': [80, 1500, 4],         // 日用品/衣服
  '居住': [50, 800, 3],          // 水电/物业/日用
  '娱乐': [60, 600, 3],          // 电影/游戏
  '医疗': [50, 2000, 1],         // 偶尔看病买药
  '教育': [200, 3000, 1],        // 买书/培训
  '通讯': [39, 199, 1],          // 话费/网费
  '其他': [20, 300, 2],
}

const INCOME_RULES: Array<{ name: string; min: number; max: number; perMonth: number; days: number[] }> = [
  { name: '工资', min: 14000, max: 16500, perMonth: 1, days: [15] },                 // 每月 15 号发工资
  { name: '红包', min: 100, max: 2000, perMonth: 1.2, days: [1, 5, 10, 20, 28] },     // 节日红包/转账
  { name: '理财', min: 50, max: 1200, perMonth: 2, days: [1, 15, 28] },               // 余额宝/基金
  { name: '兼职', min: 500, max: 4000, perMonth: 0.5, days: [10, 20] },               // 接外包
  { name: '其他', min: 100, max: 1000, perMonth: 0.3, days: [5, 25] },
]

const NOTE_TEMPLATES: Record<string, string[]> = {
  '餐饮': ['早餐', '午餐', '晚餐', '咖啡', '外卖', '聚餐', '奶茶'],
  '交通': ['地铁', '打车', '公交', '加油', '高铁', '共享单车'],
  '购物': ['日用品', '衣服', '化妆品', '超市', '网购'],
  '居住': ['水电费', '物业费', '房租', '日用百货', '维修'],
  '娱乐': ['电影', '游戏充值', '演唱会', 'KTV', '书籍'],
  '医疗': ['看病', '买药', '体检', '拔牙'],
  '教育': ['买书', '培训', '课程', '文具'],
  '通讯': ['话费', '网费', '流量包'],
  '其他': ['杂项', '零钱', '其他'],
  '工资': ['月薪'],
  '红包': ['过年红包', '生日红包', '微信红包', '节日红包'],
  '理财': ['余额宝', '基金收益', '银行理财'],
  '兼职': ['外包', '设计稿', '翻译'],
  '其他': ['退款', '捡到钱', '其他'],
}

const rand = (min: number, max: number): number => Math.random() * (max - min) + min
const randInt = (min: number, max: number): number => Math.floor(rand(min, max + 1))
const pick = <T,>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)]!

const fmt = (n: number): string => n.toFixed(2)

async function main(): Promise<void> {
  const conn = await mysql.createConnection({
    host: env.DB_HOST,
    port: env.DB_PORT,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    database: env.DB_NAME,
    multipleStatements: false,
  })
  console.log(`[seed-test] connected to ${env.DB_HOST}:${env.DB_PORT}/${env.DB_NAME}`)

  // 1) 找 test 用户
  const [userRows] = await conn.query<mysql.RowDataPacket[]>(
    'SELECT id, uuid FROM users WHERE username = ? LIMIT 1',
    ['test'],
  )
  if (userRows.length === 0) {
    console.error('[seed-test] ❌ test 用户不存在,请先注册')
    process.exit(1)
  }
  const userId = Number(userRows[0].id)
  const userUuid = userRows[0].uuid
  console.log(`[seed-test] user_id=${userId} uuid=${userUuid}`)

  // 2) 补全 profile (displayName/avatar/gender/age),让设置页有内容展示
  await conn.query(
    `UPDATE users SET display_name = ?, gender = ?, age = ? WHERE id = ?`,
    ['小账本同学', 'male', 28, userId],
  )
  console.log('[seed-test] ✅ profile updated (displayName=小账本同学, gender=male, age=28)')

  // 3) 找账本 + 账户
  const [bookRows] = await conn.query<mysql.RowDataPacket[]>(
    'SELECT id FROM books WHERE owner_id = ? ORDER BY id ASC LIMIT 1',
    [userId],
  )
  const bookId = Number(bookRows[0].id)
  const [accountRows] = await conn.query<mysql.RowDataPacket[]>(
    'SELECT id, name, type, is_default FROM accounts WHERE user_id = ? AND deleted_at IS NULL ORDER BY sort_order ASC',
    [userId],
  )
  if (accountRows.length === 0) {
    console.error('[seed-test] ❌ 找不到账户,register 时未创建?')
    process.exit(1)
  }
  const accounts = accountRows.map((r) => ({ id: Number(r.id), name: r.name, type: r.type, isDefault: r.is_default }))
  console.log(`[seed-test] book_id=${bookId} accounts=${accounts.map((a) => a.name).join(', ')}`)

  // 4) 找分类
  const [catRows] = await conn.query<mysql.RowDataPacket[]>(
    'SELECT id, name, type FROM categories ORDER BY type, sort_order',
  )
  const expenseCats = catRows.filter((c) => c.type === 'expense')
  const incomeCats = catRows.filter((c) => c.type === 'income')
  const catByName = (name: string): number => {
    const row = catRows.find((c) => c.name === name)
    if (!row) throw new Error(`missing category: ${name}`)
    return Number(row.id)
  }
  console.log(`[seed-test] categories: ${expenseCats.length} expense + ${incomeCats.length} income`)

  // 5) 删旧 records (幂等)
  const [delResult] = await conn.query<mysql.ResultSetHeader>(
    'DELETE FROM records WHERE user_id = ?',
    [userId],
  )
  console.log(`[seed-test] cleared ${delResult.affectedRows} old records`)

  // 6) 生成 60 个月数据 (2021-09-01 ~ 2026-08-28)
  const startDate = new Date('2021-09-01T00:00:00Z')
  const endDate = new Date('2026-08-28T00:00:00Z')
  const months: Array<{ year: number; month: number; days: number }> = []
  for (let d = new Date(startDate); d <= endDate; d.setUTCMonth(d.getUTCMonth() + 1)) {
    const year = d.getUTCFullYear()
    const month = d.getUTCMonth() + 1
    const days = new Date(year, month, 0).getDate() // 当月天数
    months.push({ year, month, days })
  }
  console.log(`[seed-test] generating records across ${months.length} months (${months[0].year}-${months[0].month} ~ ${months.at(-1)!.year}-${months.at(-1)!.month})`)

  type RowInsert = {
    uuid: string
    user_id: number
    book_id: number
    type: 'expense' | 'income' | 'transfer'
    category_id: number | null
    account_id: number
    to_account_id: number | null
    amount: string
    currency: string
    note: string | null
    record_date: string
    source: 'manual' | 'import' | 'ocr' | 'auto' | 'sync'
    client_id: string
  }
  const rows: RowInsert[] = []

  const pickAccountByName = (kw: string) => {
    const m = accounts.find((a) => a.name.includes(kw))
    return m ? m.id : accounts[0].id
  }
  const defaultAccountId = accounts.find((a) => a.isDefault)?.id ?? accounts[0].id
  const wechatId = pickAccountByName('微信')
  const alipayId = pickAccountByName('支付宝')
  const cashId = pickAccountByName('现金')
  const bankId = pickAccountByName('银行卡')
  const creditId = pickAccountByName('信用卡')

  let seq = 0
  const mkClientId = (): string => `seed-${seq++}-${Date.now().toString(36)}`

  for (const { year, month, days } of months) {
    // ====== 收入 ======
    for (const rule of INCOME_RULES) {
      const count = rule.perMonth >= 1
        ? rule.perMonth
        : Math.random() < rule.perMonth ? 1 : 0
      for (let i = 0; i < count; i++) {
        const day = pick(rule.days) > days ? days : pick(rule.days)
        const recordDate = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
        // 大额收入(工资/奖金)进银行卡,小额(理财/兼职)进支付宝/微信
        const accId = rule.min >= 5000 ? bankId : (Math.random() < 0.5 ? wechatId : alipayId)
        const amount = rand(rule.min, rule.max)
        rows.push({
          uuid: randomUUID(),
          user_id: userId,
          book_id: bookId,
          type: 'income',
          category_id: catByName(rule.name),
          account_id: accId,
          to_account_id: null,
          amount: fmt(amount),
          currency: 'CNY',
          note: pick(NOTE_TEMPLATES[rule.name] ?? ['收入']),
          record_date: recordDate,
          source: 'manual',
          client_id: mkClientId(),
        })
      }
    }

    // ====== 支出 ======
    for (const [catName, [min, max, perMonth]] of Object.entries(EXPENSE_RULES)) {
      for (let i = 0; i < perMonth; i++) {
        const day = randInt(1, days)
        const recordDate = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
        // 金额路由:小额餐饮随机账户,大额居家/旅行走银行卡,信用卡大额消费
        let accId = defaultAccountId
        const amount = rand(min, max)
        if (catName === '教育') accId = bankId
        else if (catName === '居住' && amount > 500) accId = bankId
        else if (catName === '购物' && amount > 800) accId = creditId
        else if (catName === '餐饮') accId = Math.random() < 0.45 ? wechatId : (Math.random() < 0.7 ? alipayId : cashId)
        else if (catName === '交通' && amount > 50) accId = Math.random() < 0.5 ? alipayId : wechatId
        else accId = Math.random() < 0.5 ? wechatId : alipayId

        rows.push({
          uuid: randomUUID(),
          user_id: userId,
          book_id: bookId,
          type: 'expense',
          category_id: catByName(catName),
          account_id: accId,
          to_account_id: null,
          amount: fmt(amount),
          currency: 'CNY',
          note: pick(NOTE_TEMPLATES[catName] ?? ['支出']),
          record_date: recordDate,
          source: 'manual',
          client_id: mkClientId(),
        })
      }
    }

    // ====== 偶尔的信用卡还款 (transfer from 银行卡 -> 信用卡) ======
    if (Math.random() < 0.7) {
      const day = randInt(1, days)
      const recordDate = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
      const amount = rand(800, 4500)
      rows.push({
        uuid: randomUUID(),
        user_id: userId,
        book_id: bookId,
        type: 'transfer',
        category_id: null,
        account_id: bankId,
        to_account_id: creditId,
        amount: fmt(amount),
        currency: 'CNY',
        note: '信用卡还款',
        record_date: recordDate,
        source: 'manual',
        client_id: mkClientId(),
      })
    }
  }

  console.log(`[seed-test] prepared ${rows.length} rows, inserting in batches of 200...`)

  // 7) 批量插入 (每批 200 行)
  const BATCH = 200
  let inserted = 0
  for (let i = 0; i < rows.length; i += BATCH) {
    const batch = rows.slice(i, i + BATCH)
    const values = batch.map(() => '(?,?,?,?,?,?,?,?,?,?,?,?,?,?)').join(',')
    const params: unknown[] = []
    for (const r of batch) {
      params.push(
        r.uuid, r.user_id, r.book_id, r.type, r.category_id, r.account_id, r.to_account_id,
        r.amount, r.currency, r.note, r.record_date, r.source, r.client_id, null, // location=null
      )
    }
    await conn.query(
      `INSERT INTO records
       (uuid, user_id, book_id, type, category_id, account_id, to_account_id, amount,
        currency, note, record_date, source, client_id, location)
       VALUES ${values}`,
      params,
    )
    inserted += batch.length
  }
  console.log(`[seed-test] ✅ inserted ${inserted} records`)

  // 8) 简单统计
  const [stats] = await conn.query<mysql.RowDataPacket[]>(
    `SELECT
       COUNT(*) AS total,
       SUM(CASE WHEN type='expense' THEN 1 ELSE 0 END) AS expense_count,
       SUM(CASE WHEN type='income' THEN 1 ELSE 0 END) AS income_count,
       SUM(CASE WHEN type='transfer' THEN 1 ELSE 0 END) AS transfer_count,
       SUM(CASE WHEN type='expense' THEN amount ELSE 0 END) AS expense_total,
       SUM(CASE WHEN type='income' THEN amount ELSE 0 END) AS income_total,
       MIN(record_date) AS first_date,
       MAX(record_date) AS last_date
     FROM records WHERE user_id = ?`,
    [userId],
  )
  const s = stats[0]
  console.log(`[seed-test] 📊 stats:`)
  console.log(`  total:    ${s.total} 条`)
  console.log(`  expense:  ${s.expense_count} 条 / ¥${Number(s.expense_total).toFixed(2)}`)
  console.log(`  income:   ${s.income_count} 条 / ¥${Number(s.income_total).toFixed(2)}`)
  console.log(`  transfer: ${s.transfer_count} 条`)
  console.log(`  range:    ${typeof s.first_date === 'string' ? s.first_date : s.first_date?.toISOString().slice(0, 10)} ~ ${typeof s.last_date === 'string' ? s.last_date : s.last_date?.toISOString().slice(0, 10)}`)

  await conn.end()
}

main().catch((err: unknown) => {
  console.error('[seed-test] ❌ failed:', err)
  process.exit(1)
})
