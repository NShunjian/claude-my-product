// 006 vitest 卡在 jsdom 缺失(基建老问题);用 Node 24 内置 strip-types 跑一次。
// 不进 vitest 体系 — 一次性验证 money.ts 语义,跑完即弃。
import {
  numToDouble,
  currencySymbol,
  formatMoney,
} from '../../src/lib/money.ts'

let failed = 0
function eq<T>(label: string, actual: T, expected: T): void {
  const pass = Object.is(actual, expected) ||
    (Number.isNaN(actual) && Number.isNaN(expected))
  if (pass) {
    console.log(`  ✓ ${label}`)
  } else {
    console.error(`  ✗ ${label} — got ${JSON.stringify(actual)}, want ${JSON.stringify(expected)}`)
    failed++
  }
}

console.log('numToDouble')
eq('number 12.34', numToDouble(12.34), 12.34)
eq('number 0', numToDouble(0), 0)
eq('number -100', numToDouble(-100), -100)
eq('string "12.34"', numToDouble('12.34'), 12.34)
eq('string "0.00"', numToDouble('0.00'), 0)
eq('string "-100"', numToDouble('-100'), -100)
eq('null', numToDouble(null), 0)
eq('undefined', numToDouble(undefined), 0)
eq('"abc"', numToDouble('abc'), 0)
eq('""', numToDouble(''), 0)
eq('NaN', numToDouble(Number.NaN), 0)
eq('Infinity', numToDouble(Number.POSITIVE_INFINITY), 0)
eq('null fallback -1', numToDouble(null, -1), -1)
eq('"abc" fallback 99', numToDouble('abc', 99), 99)

console.log('\ncurrencySymbol')
eq('CNY', currencySymbol('CNY'), '¥')
eq('USD', currencySymbol('USD'), '$')
eq('EUR', currencySymbol('EUR'), '€')
eq('GBP', currencySymbol('GBP'), '£')
eq('HKD', currencySymbol('HKD'), 'HK$')
eq('cny', currencySymbol('cny'), '¥')
eq('null', currencySymbol(null), '¥')
eq('XYZ', currencySymbol('XYZ'), '¥')

console.log('\nformatMoney')
eq('1234.5 + CNY', formatMoney(1234.5, 'CNY'), '¥1,234.50')
eq('"35.50" + CNY(防字符串拼接)', formatMoney('35.50', 'CNY'), '¥35.50')
eq('1234.5 + USD', formatMoney(1234.5, 'USD'), '$1,234.50')
eq('null amount + CNY', formatMoney(null, 'CNY'), '¥0.00')
eq('NaN + CNY', formatMoney(Number.NaN, 'CNY'), '¥0.00')
eq('1234.5 无 currency', formatMoney(1234.5), '¥1,234.50')
eq('1234.5 + null currency', formatMoney(1234.5, null), '¥1,234.50')
eq('0 + CNY', formatMoney(0, 'CNY'), '¥0.00')
eq('-100 + CNY', formatMoney(-100, 'CNY'), '¥-100.00')

console.log('\nreduce 求和仍为数字相加(防字符串拼接腐坏)')
const txns = ['12.30', '5.50', '0.20'].map((a, i) => ({ amount: a }))
const sum = txns.reduce<number>((s, t) => s + numToDouble(t.amount), 0)
eq('12.30 + 5.50 + 0.20', sum, 18)

console.log(`\n${failed === 0 ? '✅ 全通过' : `❌ ${failed} 个失败`}`)
process.exit(failed === 0 ? 0 : 1)
