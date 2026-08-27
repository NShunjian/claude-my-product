export interface Account {
  id: string
  name: string
  /** 卡片副标题：英文账户类型 / 卡号 **** 8842 */
  subtitle: string
  /** 主题 key：决定 icon 背景色 + icon 颜色 + icon 名（与原型对应） */
  themeKey: 'wechat' | 'alipay' | 'bank' | 'credit' | 'cash'
  balance: number // 负数 = 信用卡欠款
  /** 仅信用卡：显示额度 Limit: ¥50k */
  creditLimit?: string
}

export const ACCOUNTS: Account[] = [
  {
    id: 'wechat',
    name: '微信支付',
    subtitle: 'Digital Wallet',
    themeKey: 'wechat',
    balance: 4250.0,
  },
  {
    id: 'alipay',
    name: '支付宝',
    subtitle: 'Digital Wallet',
    themeKey: 'alipay',
    balance: 12400.0,
  },
  {
    id: 'icbc',
    name: '工商银行储蓄卡',
    subtitle: '**** 8842',
    themeKey: 'bank',
    balance: 125000.0,
  },
  {
    id: 'cmb-credit',
    name: '招行信用卡',
    subtitle: '**** 4291',
    themeKey: 'credit',
    balance: -3200.0,
    creditLimit: '50k',
  },
  {
    id: 'cash',
    name: '现金',
    subtitle: 'Physical Currency',
    themeKey: 'cash',
    balance: 4400.0,
  },
]