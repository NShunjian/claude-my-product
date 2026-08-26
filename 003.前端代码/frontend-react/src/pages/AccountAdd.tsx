import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { usePageTitle } from '../components/PageTitleContext'

const ACCOUNT_TYPES = ['Digital Wallet', 'Bank', 'Credit Card', 'Cash'] as const
type AccountType = (typeof ACCOUNT_TYPES)[number]

const ICONS = ['account_balance_wallet', 'account_balance', 'credit_card', 'payments', 'savings', 'school', 'home', 'store']

export function AccountAdd() {
  usePageTitle('添加账户')
  const navigate = useNavigate()
  const [name, setName] = useState<string>('')
  const [type, setType] = useState<AccountType>('Bank')
  const [balance, setBalance] = useState<string>('')
  const [icon, setIcon] = useState<string>('account_balance_wallet')

  function handleSubmit(e: React.FormEvent<HTMLFormElement>): void {
    e.preventDefault()
    // In real app, call API here
    navigate('/accounts')
  }

  return (
    <div className="space-y-6">
      {/* Breadcrumb back */}
      <div className="flex items-center gap-2 text-on-surface-variant font-body-md text-body-md">
        <a
          href="/accounts"
          className="flex items-center gap-1 hover:text-primary transition-colors"
        >
          <span className="material-symbols-outlined text-2xl">arrow_back</span>
          <span>账户管理</span>
        </a>
        <span className="text-outline">/</span>
        <span className="text-primary font-semibold">添加账户</span>
      </div>

      {/* Form */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 md:p-8 shadow-sm">
        <form onSubmit={handleSubmit} className="space-y-8">
          {/* Account name */}
          <div className="space-y-2">
            <label
              htmlFor="account_name"
              className="block font-headline-md text-headline-md text-on-surface"
            >
              账户名称
            </label>
            <input
              id="account_name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="例如 招商银行卡"
              className="w-full bg-transparent border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-0 py-2 font-body-md text-body-md text-on-surface placeholder:text-outline transition-colors"
            />
          </div>

          {/* Account type */}
          <div className="space-y-3">
            <label className="block font-headline-md text-headline-md text-on-surface">
              账户类型
            </label>
            <div className="flex flex-wrap gap-2">
              {ACCOUNT_TYPES.map((t) => (
                <button
                  key={t}
                  type="button"
                  onClick={() => setType(t)}
                  className={`px-4 py-2 rounded-lg font-body-md text-body-md transition-colors ${
                    type === t
                      ? 'bg-primary-light text-primary border-2 border-primary'
                      : 'bg-surface-container text-on-surface-variant border-2 border-transparent hover:border-outline-variant'
                  }`}
                >
                  {t}
                </button>
              ))}
            </div>
          </div>

          {/* Balance */}
          <div className="space-y-2">
            <label
              htmlFor="balance"
              className="block font-headline-md text-headline-md text-on-surface"
            >
              余额
            </label>
            <div className="relative">
              <span className="absolute left-0 top-1/2 -translate-y-1/2 font-body-md text-body-md text-on-surface-variant">
                ¥
              </span>
              <input
                id="balance"
                type="text"
                inputMode="decimal"
                value={balance}
                onChange={(e) => setBalance(e.target.value)}
                placeholder="0.00"
                className="w-full bg-transparent border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-8 py-2 font-body-md text-body-md text-on-surface placeholder:text-outline transition-colors"
              />
            </div>
            {type === 'Credit Card' && (
              <p className="font-caption-sm text-caption-sm text-on-surface-variant">
                信用卡请填写负数，如 -5000.00
              </p>
            )}
          </div>

          {/* Icon */}
          <div className="space-y-3">
            <label className="block font-headline-md text-headline-md text-on-surface">
              图标
            </label>
            <div className="flex flex-wrap gap-3">
              {ICONS.map((ic) => (
                <button
                  key={ic}
                  type="button"
                  onClick={() => setIcon(ic)}
                  className={`w-12 h-12 rounded-xl flex items-center justify-center transition-colors ${
                    icon === ic
                      ? 'bg-primary-light border-2 border-primary'
                      : 'bg-surface-container border-2 border-transparent hover:border-outline-variant'
                  }`}
                >
                  <span
                    className="material-symbols-outlined text-xl text-on-surface-variant"
                    style={{ fontVariationSettings: icon === ic ? "'FILL' 1" : "'FILL' 0" }}
                  >
                    {ic}
                  </span>
                </button>
              ))}
            </div>
          </div>

          {/* Submit */}
          <div className="pt-4">
            <button
              type="submit"
              disabled={!name}
              className="w-full bg-primary text-on-primary font-headline-md text-headline-md py-3 rounded-lg hover:bg-primary-container transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
            >
              保存
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
