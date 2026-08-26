import { usePageTitle } from '../components/PageTitleContext'
import { ACCOUNTS } from '../data/accounts'
import { Link } from 'react-router-dom'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

const COLOR_MAP: Record<string, string> = {
  'cat-teal': '#319795',
  'cat-blue': '#4299E1',
  primary: '#005394',
  error: '#ba1a1a',
  'cat-brown': '#8B6E4E',
}

const TYPE_ICON: Record<string, string> = {
  'Digital Wallet': 'account_balance_wallet',
  Bank: 'account_balance',
  'Credit Card': 'credit_card',
  Cash: 'payments',
}

export function Accounts() {
  usePageTitle('账户管理')

  const totalBalance = ACCOUNTS.reduce((s, a) => s + a.balance, 0)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-end">
        <div>
          <h2 className="font-display-lg text-display-lg text-text-primary mb-1">账户管理</h2>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant">
            共 {ACCOUNTS.length} 个账户
          </p>
        </div>
        <Link
          to="/accounts/new"
          className="flex items-center gap-2 bg-primary text-on-primary font-headline-md text-headline-md px-4 py-2 rounded-lg hover:bg-primary-container transition-colors"
        >
          <span className="material-symbols-outlined text-lg" style={{ fontVariationSettings: "'FILL' 1" }}>
            add
          </span>
          添加账户
        </Link>
      </div>

      {/* Total balance */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
        <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1">总资产</p>
        <p className="font-label-mono text-label-mono text-text-primary mb-2">
          ¥{formatMoney(totalBalance)}
        </p>
        <p className="font-caption-sm text-caption-sm text-on-surface-variant">
          净资产（不含信用卡）¥{formatMoney(ACCOUNTS.filter((a) => a.balance >= 0).reduce((s, a) => s + a.balance, 0))}
        </p>
      </div>

      {/* Account list */}
      <div className="bg-bg-card rounded-xl border border-divider overflow-hidden shadow-sm">
        {ACCOUNTS.map((acc, i) => {
          const color = COLOR_MAP[acc.colorToken] ?? '#727782'
          const icon = TYPE_ICON[acc.type] ?? 'account_balance_wallet'
          const isLast = i === ACCOUNTS.length - 1

          return (
            <div
              key={acc.id}
              className={`flex items-center gap-4 p-4 ${!isLast ? 'border-b border-divider' : ''}`}
            >
              <div
                className="w-12 h-12 rounded-full flex items-center justify-center shrink-0"
                style={{ backgroundColor: color, opacity: 0.15 }}
              >
                <span
                  className="material-symbols-outlined text-xl"
                  style={{ color, fontVariationSettings: "'FILL' 1" }}
                >
                  {icon}
                </span>
              </div>

              <div className="flex-1 min-w-0">
                <p className="font-body-md text-body-md text-text-primary font-semibold">
                  {acc.name}
                </p>
                <p className="font-caption-sm text-caption-sm text-on-surface-variant">
                  {acc.type}
                  {acc.trailingNote && (
                    <span className="ml-2 text-outline">{acc.trailingNote}</span>
                  )}
                </p>
              </div>

              <p
                className={`font-label-mono text-label-mono shrink-0 ${
                  acc.balance < 0 ? 'text-error' : 'text-text-primary'
                }`}
              >
                {acc.balance < 0 ? '-' : ''}¥{formatMoney(Math.abs(acc.balance))}
              </p>
            </div>
          )
        })}
      </div>
    </div>
  )
}
