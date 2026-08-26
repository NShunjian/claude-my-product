export interface Account {
  id: string
  name: string
  type: 'Digital Wallet' | 'Bank' | 'Credit Card' | 'Cash'
  balance: number // negative for credit card debt
  icon: string
  colorToken: 'cat-teal' | 'cat-blue' | 'primary' | 'error' | 'cat-brown'
  trailingNote?: string // e.g. "**** 8842" or "Limit: ¥50k"
}

export const ACCOUNTS: Account[] = [
  {
    id: 'wxpay',
    name: '微信支付',
    type: 'Digital Wallet',
    balance: 3256.8,
    icon: 'account_balance_wallet',
    colorToken: 'cat-teal',
    trailingNote: '**** 7621',
  },
  {
    id: 'alipay',
    name: '支付宝',
    type: 'Digital Wallet',
    balance: 15840.5,
    icon: 'account_balance_wallet',
    colorToken: 'cat-blue',
    trailingNote: '**** 3892',
  },
  {
    id: 'cmb',
    name: '招商银行',
    type: 'Bank',
    balance: 42890.32,
    icon: 'account_balance',
    colorToken: 'primary',
    trailingNote: '**** 8842',
  },
  {
    id: 'ccb',
    name: '建设银行',
    type: 'Credit Card',
    balance: -8250.0,
    icon: 'credit_card',
    colorToken: 'error',
    trailingNote: 'Limit: ¥50k',
  },
  {
    id: 'cash',
    name: '现金',
    type: 'Cash',
    balance: 1200.0,
    icon: 'payments',
    colorToken: 'cat-brown',
  },
]
