import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import * as accountsApi from '../api/accounts'
import type { AccountType } from '../api/accounts'
import { RECORDS_CHANGED_EVENT } from '../lib/hooks'

// UI 标签 + 后端 type 映射（前端主题键叫 wechat/alipay，后端叫 wallet）
const ACCOUNT_TYPES: { value: AccountType; label: string }[] = [
  { value: 'wallet', label: '微信支付' },
  { value: 'wallet', label: '支付宝' },
  { value: 'cash', label: '现金' },
  { value: 'debit', label: '银行卡' },
  { value: 'credit', label: '信用卡' },
  { value: 'investment', label: '投资账户' },
  { value: 'other', label: '其他' },
]

// 原型账户图标（5 个圆形按钮）
const ICONS = ['account_balance_wallet', 'credit_card', 'account_balance', 'payments', 'phone_iphone']

export function AccountAdd() {
  usePageTitle('添加账户')
  usePageBack('/accounts', '账户管理')
  const navigate = useNavigate()

  const [name, setName] = useState('')
  const [type, setType] = useState<AccountType | ''>('')
  const [balance, setBalance] = useState('0.00')
  const [icon, setIcon] = useState(ICONS[0])
  const [isDefault, setIsDefault] = useState(false)

  const [submitting, setSubmitting] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>): Promise<void> {
    e.preventDefault()
    if (!name.trim() || !type) return
    setSubmitting(true)
    setErrorMsg(null)
    try {
      const initialBalance = Number.parseFloat(balance)
      await accountsApi.createAccount({
        name: name.trim(),
        type: type,
        icon,
        initialBalance: Number.isFinite(initialBalance) ? initialBalance : 0,
        currency: 'CNY',
        isDefault,
      })
      window.dispatchEvent(new CustomEvent(RECORDS_CHANGED_EVENT))
      navigate('/accounts')
    } catch (err) {
      const msg = err instanceof Error ? err.message : '保存失败，请重试'
      setErrorMsg(msg)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="space-y-6">

      {/* Form */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 md:p-8 shadow-sm">
        <form onSubmit={handleSubmit} className="space-y-8">
          {/* 账户名称 */}
          <div className="space-y-2">
            <label
              htmlFor="account_name"
              className="block font-headline-md text-headline-md text-on-surface"
            >
              账户名称
            </label>
            <input
              id="account_name"
              name="account_name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="例如 招商银行卡"
              className="w-full bg-transparent border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-0 py-2 font-body-md text-body-md text-on-surface placeholder:text-outline transition-colors"
            />
          </div>

          {/* 账户类型（下拉） */}
          <div className="space-y-2">
            <label
              htmlFor="account_type"
              className="block font-headline-md text-headline-md text-on-surface"
            >
              账户类型
            </label>
            <div className="relative">
              <select
                id="account_type"
                name="account_type"
                value={type}
                onChange={(e) => setType(e.target.value as AccountType | '')}
                className="w-full bg-transparent border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-0 py-2 font-body-md text-body-md text-on-surface appearance-none transition-colors pr-8"
              >
                <option value="" disabled>选择类型</option>
                {ACCOUNT_TYPES.map((t, i) => (
                  <option key={`${t.value}-${i}`} value={t.value}>{t.label}</option>
                ))}
              </select>
              <span className="material-symbols-outlined absolute right-0 top-1/2 -translate-y-1/2 pointer-events-none text-outline-variant">
                expand_more
              </span>
            </div>
          </div>

          {/* 初始余额 */}
          <div className="space-y-2">
            <label
              htmlFor="initial_balance"
              className="block font-headline-md text-headline-md text-on-surface"
            >
              初始余额
            </label>
            <div className="relative flex items-center">
              <span className="absolute left-0 text-on-surface-variant font-label-mono text-label-mono">
                ¥
              </span>
              <input
                id="initial_balance"
                name="initial_balance"
                type="number"
                inputMode="decimal"
                step="0.01"
                value={balance}
                onChange={(e) => setBalance(e.target.value)}
                placeholder="0.00"
                className="w-full bg-transparent border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 pl-6 py-2 font-label-mono text-label-mono text-on-surface placeholder:text-outline transition-colors"
              />
            </div>
          </div>

          {/* 账户图标 */}
          <div className="space-y-3">
            <label className="block font-headline-md text-headline-md text-on-surface">
              账户图标
            </label>
            <div className="flex flex-wrap gap-4">
              {ICONS.map((ic) => {
                const selected = icon === ic
                return (
                  <button
                    key={ic}
                    type="button"
                    onClick={() => setIcon(ic)}
                    aria-pressed={selected}
                    className={`w-12 h-12 rounded-full flex items-center justify-center transition-all ${
                      selected
                        ? 'border-2 border-primary bg-primary-light text-primary'
                        : 'border border-divider text-on-surface-variant hover:border-primary'
                    }`}
                  >
                    <span
                      className="material-symbols-outlined"
                      style={{ fontVariationSettings: selected ? "'FILL' 1" : "'FILL' 0" }}
                    >
                      {ic}
                    </span>
                  </button>
                )
              })}
            </div>
          </div>

          {/* 设为默认账户 */}
          <div className="pt-4 flex items-center justify-between border-t border-divider">
            <div>
              <span className="block font-headline-md text-headline-md text-on-surface">
                设为默认账户
              </span>
              <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                记账时默认选择此账户
              </span>
            </div>
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                className="sr-only peer"
                checked={isDefault}
                onChange={(e) => setIsDefault(e.target.checked)}
              />
              <div className="w-11 h-6 bg-outline-variant peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary" />
            </label>
          </div>

          {/* 错误提示 */}
          {errorMsg && (
            <div className="bg-error-container text-on-error-container rounded-lg px-4 py-3 font-body-md text-body-md">
              {errorMsg}
            </div>
          )}

          {/* 操作按钮 */}
          <div className="pt-8 flex gap-4">
            <Link
              to="/accounts"
              className="flex-1 py-3 px-4 border border-outline text-on-surface font-headline-md text-headline-md rounded-lg hover:bg-surface-container-low transition-colors text-center"
            >
              取消
            </Link>
            <button
              type="submit"
              disabled={!name.trim() || !type || submitting}
              className="flex-1 py-3 px-4 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm disabled:opacity-60 disabled:cursor-not-allowed inline-flex items-center justify-center gap-2"
            >
              {submitting && (
                <span
                  className="material-symbols-outlined animate-spin"
                  style={{ fontSize: '18px' }}
                >
                  progress_activity
                </span>
              )}
              保存账户
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}