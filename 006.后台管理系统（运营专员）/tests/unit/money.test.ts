// V1.2 金额核算审计 — 纯函数测试,用 happy-dom(006 已装)跳过 jsdom 依赖。
// 不加 `@vitest-environment jsdom` — 006 缺 jsdom 包,加了就 ERR_MODULE_NOT_FOUND。
// @vitest-environment happy-dom
import { describe, it, expect } from 'vitest'
import { numToDouble, currencySymbol, formatMoney } from '../../src/lib/money'

describe('lib/money — V1.2 金额核算审计', () => {
  describe('numToDouble', () => {
    it('number → 自身', () => {
      expect(numToDouble(12.34)).toBe(12.34)
      expect(numToDouble(0)).toBe(0)
      expect(numToDouble(-100)).toBe(-100)
    })
    it('string → 解析成 number(防 BigDecimal 字符串)', () => {
      expect(numToDouble('12.34')).toBe(12.34)
      expect(numToDouble('0.00')).toBe(0)
      expect(numToDouble('-100')).toBe(-100)
    })
    it('null / undefined → 0', () => {
      expect(numToDouble(null)).toBe(0)
      expect(numToDouble(undefined)).toBe(0)
    })
    it('非法 string → 0', () => {
      expect(numToDouble('abc')).toBe(0)
      expect(numToDouble('')).toBe(0)
    })
    it('NaN / Infinity → 0', () => {
      expect(numToDouble(Number.NaN)).toBe(0)
      expect(numToDouble(Number.POSITIVE_INFINITY)).toBe(0)
    })
    it('支持自定义 fallback', () => {
      expect(numToDouble(null, -1)).toBe(-1)
      expect(numToDouble('abc', 99)).toBe(99)
    })
  })

  describe('currencySymbol', () => {
    it('CNY → ¥', () => expect(currencySymbol('CNY')).toBe('¥'))
    it('USD → $', () => expect(currencySymbol('USD')).toBe('$'))
    it('EUR → €', () => expect(currencySymbol('EUR')).toBe('€'))
    it('GBP → £', () => expect(currencySymbol('GBP')).toBe('£'))
    it('HKD → HK$', () => expect(currencySymbol('HKD')).toBe('HK$'))
    it('小写兼容', () => expect(currencySymbol('cny')).toBe('¥'))
    it('null → ¥', () => expect(currencySymbol(null)).toBe('¥'))
    it('unknown → ¥ 兜底', () => expect(currencySymbol('XYZ')).toBe('¥'))
  })

  describe('formatMoney', () => {
    it('number + CNY → "¥1,234.50"', () => {
      expect(formatMoney(1234.5, 'CNY')).toBe('¥1,234.50')
    })
    it('string BigDecimal + CNY → "¥35.50"(自动规整)', () => {
      // 后端 Jackson ToStringSerializer(BigDecimal) 实际产生的形态
      expect(formatMoney('35.50', 'CNY')).toBe('¥35.50')
    })
    it('USD → "$1,234.50"', () => {
      expect(formatMoney(1234.5, 'USD')).toBe('$1,234.50')
    })
    it('null amount → "¥0.00"(numToDouble 已经兜底成 0)', () => {
      expect(formatMoney(null, 'CNY')).toBe('¥0.00')
    })
    it('NaN → "¥0.00"(numToDouble 兜底,不渲染 ¥NaN)', () => {
      // numToDouble(NaN) === 0,formatMoney 走正常路径。无需 '--' 兜底。
      expect(formatMoney(Number.NaN, 'CNY')).toBe('¥0.00')
    })
    it('无 currency 参数时回退 ¥', () => {
      // currencySymbol(undefined) 返回 ¥,格式仍带符号;006 表格每行都有 currency,
      // 此兜底主要给"无元数据"场景用(表格兜底会从 record 拿,这里只保证不崩)。
      expect(formatMoney(1234.5)).toBe('¥1,234.50')
    })
    it('null currency 时回退 ¥', () => {
      expect(formatMoney(1234.5, null)).toBe('¥1,234.50')
    })
    it('0 → "¥0.00"', () => {
      expect(formatMoney(0, 'CNY')).toBe('¥0.00')
    })
    it('负数 → "¥-100.00"(Intl zh-CN 把符号放最前)', () => {
      // zh-CN locale 下 Intl 输出 "-100.00",我们前缀 ¥ → "¥-100.00"。
      expect(formatMoney(-100, 'CNY')).toBe('¥-100.00')
    })
  })
})
