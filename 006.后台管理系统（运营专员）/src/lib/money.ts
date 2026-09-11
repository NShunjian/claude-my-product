/**
 * V1.2 金额核算审计:运营后台的金额展示 / 解析工具。
 *
 * 后端 Jackson `ToStringSerializer(BigDecimal)` 把 BigDecimal 序列化成 JSON
 * 字符串(例如 `"35.50"`),admin 表格直接渲染就是字面量。这个模块:
 *   - numToDouble 兼容 number / string / null,失败回退 0
 *   - currencySymbol ISO 4217 → 符号
 *   - formatMoney  把金额格式化为带千分位 + 2 位小数的展示串
 *
 * 与 003 / 007 / uniapp 三个前端的同名工具语义一致。
 */

/** 任意值规整成 finite double,失败回退 [fallback]。 */
export function numToDouble(v: unknown, fallback = 0): number {
  if (v == null) return fallback
  if (typeof v === 'number') return Number.isFinite(v) ? v : fallback
  if (typeof v === 'string') {
    const d = Number.parseFloat(v)
    return Number.isFinite(d) ? d : fallback
  }
  return fallback
}

/** ISO 4217 货币码 → 显示符号。未知码回退 ¥。 */
export function currencySymbol(code: string | null | undefined): string {
  switch ((code ?? '').toUpperCase()) {
    case 'CNY':
    case 'RMB':
      return '¥'
    case 'USD':
      return '$'
    case 'EUR':
      return '€'
    case 'GBP':
      return '£'
    case 'JPY':
      return '¥'
    case 'HKD':
      return 'HK$'
    default:
      return '¥'
  }
}

/** 金额展示串 — 千分位 + 2 位小数 + 货币符号(后端给字符串 BigDecimal 时仍然稳)。 */
export function formatMoney(amount: unknown, currency?: string | null): string {
  const n = numToDouble(amount)
  if (!Number.isFinite(n)) return '--'
  const body = new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(n)
  return currencySymbol(currency) + body
}