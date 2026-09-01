import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { TransactionRow } from '../components/TransactionRow'
import { useAccounts, useCategories, useRecords } from '../lib/hooks'
import { toAccounts, toCategories, toTransactions } from '../lib/finance-mappers'
import { useLanguage } from '../i18n/LanguageContext'
import type { Account, Category, Transaction } from '../lib/finance-types'

const WEEKDAY_KEYS = [
  'transactions.weekdaySun',
  'transactions.weekdayMon',
  'transactions.weekdayTue',
  'transactions.weekdayWed',
  'transactions.weekdayThu',
  'transactions.weekdayFri',
  'transactions.weekdaySat',
]

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Math.abs(amount))
}

function formatMonth(month: string): string {
  const [y, m] = month.split('-')
  return `${y}年 ${parseInt(m, 10)}月`
}

function formatDayWithWeekday(iso: string, weekdays: string[]): string {
  const d = new Date(iso)
  return `${d.getMonth() + 1}月${d.getDate()}日, ${weekdays[d.getDay()]}`
}

const SELECT_ARROW =
  "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' height='24' width='24' viewBox='0 -960 960 960' fill='%23414750'%3E%3Cpath d='M480-345 226-599l57-57 197 197 197-197 57 57-254 254Z'/%3E%3C/svg%3E\")"
const SELECT_CLASS =
  'bg-surface-container-lowest border border-outline-variant text-text-primary text-body-md font-body-md font-medium rounded-lg py-2 pl-3 pr-9 focus:border-primary focus:ring-0 cursor-pointer appearance-none bg-no-repeat'
const SELECT_STYLE: React.CSSProperties = {
  backgroundImage: SELECT_ARROW,
  backgroundPosition: 'right 12px center',
  backgroundRepeat: 'no-repeat',
  backgroundSize: '20px 20px',
}

function currentMonth(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

/** 简单生成 6 个月的月份选项用于筛选下拉 */
function recentMonths(): string[] {
  const out: string[] = []
  const now = new Date()
  for (let i = 0; i < 6; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    out.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`)
  }
  return out
}

export function Transactions() {
  const { t } = useLanguage()
  const [searchParams] = useSearchParams()
  const weekdays = useMemo(() => WEEKDAY_KEYS.map((k) => t(k)), [t])
  usePageTitle(t('transactions.titleAll'))
  usePageBack('/', t('pageTitle.home'))

  // 来自 Home 页 ?month=YYYY-MM 的查询参数;格式不正确时回落到当前月
  const monthFromQuery = searchParams.get('month')
  const initialMonth =
    monthFromQuery && /^\d{4}-\d{2}$/.test(monthFromQuery) ? monthFromQuery : currentMonth()

  const [filterMonth, setFilterMonth] = useState<string>(initialMonth)
  const [filterCategory, setFilterCategory] = useState<string>('all')
  const [filterAccount, setFilterAccount] = useState<string>('all')

  const months = useMemo(recentMonths, [])

  const accountsQ = useAccounts()
  const expenseCatsQ = useCategories('expense')
  const incomeCatsQ = useCategories('income')
  const recordsQ = useRecords({ month: filterMonth })

  const accounts = useMemo<Account[]>(
    () => (accountsQ.data ? toAccounts(accountsQ.data) : []),
    [accountsQ.data],
  )
  const expenseCats = useMemo<Category[]>(
    () => (expenseCatsQ.data ? toCategories(expenseCatsQ.data) : []),
    [expenseCatsQ.data],
  )
  const incomeCats = useMemo<Category[]>(
    () => (incomeCatsQ.data ? toCategories(incomeCatsQ.data) : []),
    [incomeCatsQ.data],
  )
  const allTxns = useMemo<Transaction[]>(
    () => (recordsQ.data ? toTransactions(recordsQ.data) : []),
    [recordsQ.data],
  )
  const allCategories = useMemo<Category[]>(
    () => [...expenseCats, ...incomeCats],
    [expenseCats, incomeCats],
  )

  const findAccount = (id: string): Account | undefined => accounts.find((a) => a.id === id)

  const filteredTxns = useMemo(() => {
    return allTxns.filter((t) => {
      if (filterCategory !== 'all' && t.categoryId !== filterCategory) return false
      if (filterAccount !== 'all' && t.accountId !== filterAccount) return false
      return true
    }).sort((a, b) => (a.date < b.date ? 1 : -1))
  }, [allTxns, filterCategory, filterAccount])

  const { income, expense } = useMemo(() => {
    let inc = 0
    let exp = 0
    for (const t of filteredTxns) {
      if (t.type === 'income') inc += t.amount
      else exp += t.amount
    }
    return { income: inc, expense: exp }
  }, [filteredTxns])
  const net = income - expense

  const groupedTxns = useMemo(() => {
    const groups = new Map<string, Transaction[]>()
    for (const t of filteredTxns) {
      const arr = groups.get(t.date) ?? []
      arr.push(t)
      groups.set(t.date, arr)
    }
    return Array.from(groups.entries()).map(([date, txns]) => {
      // 同日内的交易按创建时间倒序(最新在前);createdAt 缺失时回落到 date 倒序
      const sorted = [...txns].sort((a, b) => {
        const aT = a.createdAt ?? a.date
        const bT = b.createdAt ?? b.date
        return aT < bT ? 1 : aT > bT ? -1 : 0
      })
      const groupNet = sorted.reduce(
        (s, t) => s + (t.type === 'income' ? t.amount : -t.amount),
        0,
      )
      return { date, txns: sorted, net: groupNet, label: formatDayWithWeekday(date, weekdays) }
    })
  }, [filteredTxns, weekdays])

  // 月份变更时，若当前账户/分类已不存在列表里，重置为 all
  useEffect(() => {
    if (filterAccount !== 'all' && !accounts.find((a) => a.id === filterAccount)) {
      setFilterAccount('all')
    }
  }, [accounts, filterAccount])
  useEffect(() => {
    if (filterCategory !== 'all' && !allCategories.find((c) => c.id === filterCategory)) {
      setFilterCategory('all')
    }
  }, [allCategories, filterCategory])

  const isLoading = recordsQ.loading
  const isError = !isLoading && !!recordsQ.error
  const errMsg = recordsQ.error?.message ?? null

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-bg-card rounded-xl border border-divider p-4 flex flex-col justify-center">
          <h2 className="font-headline-md text-headline-md text-text-primary mb-4">{t('transactions.filterLabel')}</h2>
          <div className="flex flex-wrap gap-3">
            <select className={SELECT_CLASS} style={SELECT_STYLE} value={filterMonth} onChange={(e) => setFilterMonth(e.target.value)}>
              {months.map((m) => <option key={m} value={m}>{formatMonth(m)}</option>)}
            </select>
            <select className={SELECT_CLASS} style={SELECT_STYLE} value={filterCategory} onChange={(e) => setFilterCategory(e.target.value)}>
              <option value="all">{t('transactions.allCategories')}</option>
              {allCategories.map((cat) => <option key={cat.id} value={cat.id}>{cat.name}</option>)}
            </select>
            <select className={SELECT_CLASS} style={SELECT_STYLE} value={filterAccount} onChange={(e) => setFilterAccount(e.target.value)}>
              <option value="all">{t('transactions.allAccounts')}</option>
              {accounts.map((acct) => <option key={acct.id} value={acct.id}>{acct.name}</option>)}
            </select>
          </div>
        </div>
        <div className="bg-primary text-on-primary rounded-xl p-4 flex flex-col justify-center relative overflow-hidden">
          <div className="absolute -right-10 -top-10 w-32 h-32 bg-primary-light opacity-10 rounded-full blur-2xl" />
          <span className="font-caption-sm text-caption-sm text-primary-light mb-1">{t('transactions.monthBalance')}</span>
          <span className="font-label-mono text-label-mono text-2xl">¥ {formatMoney(net)}</span>
          <div className="flex justify-between mt-4 font-body-md text-body-md">
            <div className="flex flex-col">
              <span className="text-primary-light">{t('transactions.income')}</span>
              <span className="font-label-mono text-label-mono">+¥ {formatMoney(income)}</span>
            </div>
            <div className="flex flex-col text-right">
              <span className="text-primary-light">{t('transactions.expense')}</span>
              <span className="font-label-mono text-label-mono">-¥ {formatMoney(expense)}</span>
            </div>
          </div>
        </div>
      </div>

      {isError && (
        <div className="bg-error-container text-on-error-container rounded-xl p-4 font-body-md text-body-md">
          {t('transactions.loadErrorPrefix')}{errMsg}
        </div>
      )}

      <div className="bg-bg-card rounded-xl border border-divider overflow-hidden">
        {isLoading ? (
          <p className="text-on-surface-variant font-body-md text-body-md text-center py-12">{t('transactions.loading')}</p>
        ) : filteredTxns.length === 0 ? (
          <p className="text-on-surface-variant font-body-md text-body-md text-center py-12">{t('transactions.empty')}</p>
        ) : (
          <div className="flex flex-col">
            {groupedTxns.map((group, idx) => (
              <div key={group.date} className={idx === 0 ? '' : 'mt-2'}>
                <div className="px-4 py-3 bg-surface-container-low border-b border-divider flex justify-between items-center">
                  <span className="font-headline-md text-headline-md text-text-primary text-sm">
                    {group.label}
                  </span>
                  <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                    {group.net >= 0 ? '+' : '-'}¥ {formatMoney(group.net)}
                  </span>
                </div>
                <div className="flex flex-col">
                  {group.txns.map((txn) => (
                    <TransactionRow
                      key={txn.id}
                      transaction={txn}
                      account={findAccount(txn.accountId)}
                      categories={allCategories}
                      variant="comfortable"
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
