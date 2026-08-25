import { Account } from '../types'

export const PRESET_ACCOUNTS: Account[] = [
  {
    id: 'account-wechat',
    name: '微信支付',
    icon: '💳',
    initialBalance: 0,
    balance: 0,
    isDefault: true,
    sortOrder: 0,
  },
  {
    id: 'account-alipay',
    name: '支付宝',
    icon: '💳',
    initialBalance: 0,
    balance: 0,
    isDefault: false,
    sortOrder: 1,
  },
  {
    id: 'account-cash',
    name: '现金',
    icon: '💵',
    initialBalance: 0,
    balance: 0,
    isDefault: false,
    sortOrder: 2,
  },
  {
    id: 'account-bank',
    name: '银行卡',
    icon: '🏦',
    initialBalance: 0,
    balance: 0,
    isDefault: false,
    sortOrder: 3,
  },
  {
    id: 'account-credit',
    name: '信用卡',
    icon: '💳',
    initialBalance: 0,
    balance: 0,
    isDefault: false,
    sortOrder: 4,
  },
]
