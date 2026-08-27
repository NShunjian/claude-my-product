import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'

// 原型账户类型（与 Accounts.tsx themeKey 对应）
const ACCOUNT_TYPES = [
  { value: '', label: '选择类型', disabled: true },
  { value: 'wechat', label: '微信支付' },
  { value: 'alipay', label: '支付宝' },
  { value: 'bank', label: '银行卡' },
  { value: 'cash', label: '现金' },
  { value: 'credit', label: '信用卡' },
  { value: 'other', label: '其他' },
]

// 原型账户图标（5 个圆形按钮）
const ICONS = ['account_balance_wallet', 'credit_card', 'account_balance', 'payments', 'phone_iphone']

export function AccountAdd() {
  usePageTitle('添加账户')
  usePageBack('/accounts', '账户管理')
  const navigate = useNavigate()

  const [name, setName] = useState('')
  const [type, setType] = useState('')
  const [balance, setBalance] = useState('0.00')
  const [icon, setIcon] = useState(ICONS[0])
  const [isDefault, setIsDefault] = useState(false)

  function handleSubmit(e: React.FormEvent<HTMLFormElement>): void {
    e.preventDefault()
    // In real app, call API here
    navigate('/accounts')
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
                onChange={(e) => setType(e.target.value)}
                className="w-full bg-transparent border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-0 py-2 font-body-md text-body-md text-on-surface appearance-none transition-colors pr-8"
              >
                {ACCOUNT_TYPES.map((t) => (
                  <option key={t.value} value={t.value} disabled={t.disabled}>
                    {t.label}
                  </option>
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
              disabled={!name || !type}
              className="flex-1 py-3 px-4 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm disabled:opacity-60 disabled:cursor-not-allowed"
            >
              保存账户
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}