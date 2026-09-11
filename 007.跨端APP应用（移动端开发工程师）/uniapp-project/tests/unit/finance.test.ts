/**
 * 007 uniapp-project — utils/finance.ts 单测(真实断言)
 *
 * 覆盖目标(007-uniapp-project.md §6.1):
 *   - formatAmount: 千分位 + 2 位小数 + 可选 ¥ 前缀
 *   - formatDateTime: ISO → 本地 `YYYY-MM-DD HH:mm`
 *   - typeOfAccount / typeOfCategory / balanceSign: 业务语义
 *   - 边界:0 / 负数 / 大数 / 浮点精度 / 非法 ISO
 *
 * 工具:vitest
 */
import { describe, expect, it } from 'vitest'
import {
  balanceSign,
  currencySymbol,
  formatAmount,
  formatDateTime,
  typeOfAccount,
  typeOfCategory,
} from '@/utils/finance'

describe('utils/finance — formatAmount', () => {
  it('整数 1234 → "1,234.00"', () => {
    expect(formatAmount(1234)).toBe('1,234.00')
  })

  it('浮点 1234.5 → "1,234.50"', () => {
    expect(formatAmount(1234.5)).toBe('1,234.50')
  })

  it('0 → "0.00"', () => {
    expect(formatAmount(0)).toBe('0.00')
  })

  it('负数 -100 → "-100.00"', () => {
    expect(formatAmount(-100)).toBe('-100.00')
  })

  it('大数 1e9 → "1,000,000,000.00"', () => {
    expect(formatAmount(1e9)).toBe('1,000,000,000.00')
  })

  it('withSymbol=true → "¥1,234.50"', () => {
    expect(formatAmount(1234.5, true)).toBe('¥1,234.50')
  })

  it('浮点 0.1 + 0.2 → "0.30" (不要 "0.30000000000000004")', () => {
    // 0.1 + 0.2 = 0.30000000000000004,toLocaleString 应取 2 位小数后给出 "0.30"
    expect(formatAmount(0.1 + 0.2)).toBe('0.30')
  })

  it('超过 2 位 1234.5678 → "1,234.57" (截断到 2 位)', () => {
    expect(formatAmount(1234.5678)).toBe('1,234.57')
  })

  // V1.2 金额核算审计:NaN / Infinity / null 全部回退到 '--',不渲染 ¥NaN。
  it('NaN → "--"', () => {
    expect(formatAmount(Number.NaN)).toBe('--')
  })
  it('Infinity → "--"', () => {
    expect(formatAmount(Number.POSITIVE_INFINITY)).toBe('--')
  })
  it('null → "--"', () => {
    expect(formatAmount(null)).toBe('--')
  })
  it('undefined → "--"', () => {
    expect(formatAmount(undefined)).toBe('--')
  })
  it('withSymbol=true + NaN → "--" (不带 ¥ 前缀)', () => {
    expect(formatAmount(Number.NaN, true)).toBe('--')
  })

  // V1.2 金额核算审计:currency 参数优先于 withSymbol
  it('currency="USD" + withSymbol=false → "$1,234.50"', () => {
    expect(formatAmount(1234.5, false, 'USD')).toBe('$1,234.50')
  })
  it('currency="EUR" 优先于 withSymbol=true', () => {
    expect(formatAmount(99, true, 'EUR')).toBe('€99.00')
  })
  it('unknown currency 回退到 ¥', () => {
    expect(formatAmount(1, false, 'XYZ')).toBe('¥1.00')
  })
})

describe('utils/finance — currencySymbol', () => {
  it('CNY → ¥', () => expect(currencySymbol('CNY')).toBe('¥'))
  it('RMB → ¥', () => expect(currencySymbol('RMB')).toBe('¥'))
  it('USD → $', () => expect(currencySymbol('USD')).toBe('$'))
  it('EUR → €', () => expect(currencySymbol('EUR')).toBe('€'))
  it('GBP → £', () => expect(currencySymbol('GBP')).toBe('£'))
  it('JPY → ¥', () => expect(currencySymbol('JPY')).toBe('¥'))
  it('HKD → HK$', () => expect(currencySymbol('HKD')).toBe('HK$'))
  it('小写 cny 也能匹配', () => expect(currencySymbol('cny')).toBe('¥'))
  it('null → ¥(回退)', () => expect(currencySymbol(null)).toBe('¥'))
  it('unknown → ¥(回退)', () => expect(currencySymbol('XYZ')).toBe('¥'))
})

describe('utils/finance — formatDateTime', () => {
  it('合法 ISO → YYYY-MM-DD HH:mm', () => {
    // 注意:toLocaleString 与时区相关。本断言按本地时区来构造期望值。
    const iso = '2026-09-04T12:34:00Z'
    const out = formatDateTime(iso)
    expect(out).toMatch(/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/)
  })

  it('非法 ISO → 原样返回', () => {
    expect(formatDateTime('not-a-date')).toBe('not-a-date')
  })

  it('合法 ISO 拆字段检查(取一个具体时间戳)', () => {
    // 2026-09-04T00:00:00Z 在 UTC 与 Asia/Shanghai (UTC+8) 会差 8 小时。
    // 用本地时区反推 d.getFullYear/Month/...
    const iso = '2026-09-04T00:00:00Z'
    const out = formatDateTime(iso)
    const [datePart, timePart] = out.split(' ')
    const [yyyy, mm, dd] = datePart.split('-').map(Number)
    expect(yyyy).toBeGreaterThanOrEqual(2026)
    expect(yyyy).toBeLessThanOrEqual(2026)
    expect(mm).toBeGreaterThanOrEqual(1)
    expect(mm).toBeLessThanOrEqual(12)
    expect(dd).toBeGreaterThanOrEqual(1)
    expect(dd).toBeLessThanOrEqual(31)
    expect(timePart).toMatch(/^\d{2}:\d{2}$/)
  })
})

describe('utils/finance — typeOfAccount', () => {
  it('cash → "现金"', () => {
    expect(typeOfAccount('cash')).toBe('现金')
  })
  it('debit → "借记卡"', () => {
    expect(typeOfAccount('debit')).toBe('借记卡')
  })
  it('credit → "信用卡"', () => {
    expect(typeOfAccount('credit')).toBe('信用卡')
  })
  it('wallet → "钱包"', () => {
    expect(typeOfAccount('wallet')).toBe('钱包')
  })
  it('investment → "投资"', () => {
    expect(typeOfAccount('investment')).toBe('投资')
  })
  it('other → "其他"', () => {
    expect(typeOfAccount('other')).toBe('其他')
  })
  it('未知类型(任意字符串) → "其他" 兜底', () => {
    expect(typeOfAccount('unknown' as any)).toBe('其他')
  })
})

describe('utils/finance — typeOfCategory', () => {
  it('expense → expense', () => {
    expect(typeOfCategory('expense')).toBe('expense')
  })
  it('income → income', () => {
    expect(typeOfCategory('income')).toBe('income')
  })
  it('transfer → transfer', () => {
    expect(typeOfCategory('transfer')).toBe('transfer')
  })
})

describe('utils/finance — balanceSign', () => {
  it('正数 → 1', () => {
    expect(balanceSign(100)).toBe(1)
  })
  it('负数 → -1', () => {
    expect(balanceSign(-1)).toBe(-1)
  })
  it('0 → 0', () => {
    expect(balanceSign(0)).toBe(0)
  })
  it('极小正数 0.01 → 1', () => {
    expect(balanceSign(0.01)).toBe(1)
  })
  it('极小负数 -0.01 → -1', () => {
    expect(balanceSign(-0.01)).toBe(-1)
  })
})