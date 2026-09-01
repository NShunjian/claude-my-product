import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { TransactionRow } from '../components/TransactionRow'
import { CategoryBreakdown } from '../components/CategoryBreakdown'
import { MonthPicker } from '../components/MonthPicker'
import { useAccounts, useCategories, useRecords } from '../lib/hooks'
import { toAccounts, toCategories, toTransactions } from '../lib/finance-mappers'
import { useLanguage } from '../i18n/LanguageContext'
import type { Account, Category, Transaction } from '../lib/finance-types'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

function dateLabel(iso: string, today: Date, t: (key: string) => string): string {
  const d = new Date(iso)
  const sameDay = (a: Date, b: Date): boolean =>
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  const monthDay = `${d.getMonth() + 1}月${d.getDate()}日`
  if (sameDay(d, today)) return `${t('home.today')}, ${monthDay}`
  const yesterday = new Date(today)
  yesterday.setDate(today.getDate() - 1)
  if (sameDay(d, yesterday)) return `${t('home.yesterday')}, ${monthDay}`
  return monthDay
}

function currentMonthYYYYMM(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split('-').map(Number)
  const d = new Date(y, m - 1 + delta, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

function formatMonthLabel(month: string): string {
  const [y, m] = month.split('-')
  return `${y} 年 ${parseInt(m, 10)} 月`
}

export function Home() {
  const { t } = useLanguage()
  usePageTitle(t('pageTitle.home'))
  usePageBack(null)

  const [month, setMonth] = useState(currentMonthYYYYMM)
  const today = useMemo(() => new Date(), [])

  const yearOptions = useMemo(() => {
    const cur = new Date().getFullYear()
    const years: number[] = []
    for (let y = 2020; y <= cur + 2; y++) years.push(y)
    return years
  }, [])

  function goPrev() { setMonth((m) => shiftMonth(m, -1)) }
  function goNext() { setMonth((m) => shiftMonth(m, 1)) }

  const accountsQ = useAccounts()
  const expenseCatsQ = useCategories('expense')
  const incomeCatsQ = useCategories('income')
  const recordsQ = useRecords({ month })

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

  const thisMonthTxns = allTxns

  const thisMonthIncome = useMemo(
    () => thisMonthTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0),
    [thisMonthTxns],
  )

  const thisMonthExpense = useMemo(
    () => thisMonthTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [thisMonthTxns],
  )

  const totalAssets = useMemo(
    () => accounts.reduce((s, a) => s + a.balance, 0),
    [accounts],
  )

  const monthlyBalance = thisMonthIncome - thisMonthExpense

  const recentTxns = thisMonthTxns.slice(0, 8)

  const groupedTxns = useMemo(() => {
    const groups = new Map<string, Transaction[]>()
    for (const t of recentTxns) {
      const arr = groups.get(t.date) ?? []
      arr.push(t)
      groups.set(t.date, arr)
    }
    return Array.from(groups.entries()).map(([date, txns]) => {
      const net = txns.reduce(
        (s, t) => s + (t.type === 'income' ? t.amount : -t.amount),
        0,
      )
      return { date, txns, net, label: dateLabel(date, today, t) }
    })
  }, [recentTxns, today, t])

  const findAccount = (id: string): Account | undefined =>
    accounts.find((a) => a.id === id)

  const isLoading = accountsQ.loading || recordsQ.loading
  const isError = !isLoading && (!!accountsQ.error || !!recordsQ.error)
  const errMsg = accountsQ.error?.message ?? recordsQ.error?.message ?? null

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="font-display-lg text-display-lg text-text-primary mb-1">{t('home.overview')}</h2>
          <p className="font-body-md text-body-md text-on-surface-variant">
            {formatMonthLabel(month)}
          </p>
        </div>
        <div className="flex items-center gap-2 px-4 py-2 rounded-xl bg-bg-card border border-divider">
          <button
            type="button"
            onClick={goPrev}
            aria-label={t('home.prevMonth')}
            className="text-on-surface-variant hover:text-primary transition-colors"
          >
            <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
              chevron_left
            </span>
          </button>
          <MonthPicker
            value={month}
            onChange={setMonth}
            yearOptions={yearOptions}
            displayTemplate={t('home.monthYear')}
            triggerLabel={t('home.pickMonth')}
            labels={{
              yearLabel: t('home.picker.yearLabel'),
              clear: t('home.picker.clear'),
              thisMonth: t('home.picker.thisMonth'),
            }}
          />
          <button
            type="button"
            onClick={goNext}
            aria-label={t('home.nextMonth')}
            className="text-on-surface-variant hover:text-primary transition-colors"
          >
            <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
              chevron_right
            </span>
          </button>
        </div>
      </div>

      {isError && (
        <div className="bg-error-container text-on-error-container rounded-xl p-4 font-body-md text-body-md">
          {t('home.loadErrorPrefix')}{errMsg}
        </div>
      )}

      {/* Row 1: 总资产 */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm relative overflow-hidden">
        <div className="absolute top-0 right-0 p-4 opacity-10 pointer-events-none">
          <span className="material-symbols-outlined text-primary" style={{ fontSize: '80px', lineHeight: 1, display: 'block' }}>
            account_balance_wallet
          </span>
        </div>
        <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">{t('home.totalAssets')}</p>
        <div className="flex items-baseline gap-1">
          <span className="font-label-mono text-label-mono text-primary">¥</span>
          <span className="font-label-mono text-[40px] leading-tight text-primary font-bold">
            {formatMoney(totalAssets)}
          </span>
        </div>
        <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-2">
          {t('home.accountsCount').replace('{n}', String(accounts.length))}
        </p>
      </div>

      {/* Row 2: 三张 KPI 卡 */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">{t('home.monthExpense')}</p>
          <div className="flex items-baseline gap-1">
            <span className="font-label-mono text-label-mono text-error">¥</span>
            <span className="font-label-mono text-[32px] leading-tight text-error font-bold">
              {formatMoney(thisMonthExpense)}
            </span>
          </div>
        </div>
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">{t('home.monthIncome')}</p>
          <div className="flex items-baseline gap-1">
            <span className="font-label-mono text-label-mono text-secondary">¥</span>
            <span className="font-label-mono text-[32px] leading-tight text-secondary font-bold">
              {formatMoney(thisMonthIncome)}
            </span>
          </div>
        </div>
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">{t('home.monthBalance')}</p>
          <div className="flex items-baseline gap-1">
            <span className="font-label-mono text-label-mono" style={{ color: monthlyBalance >= 0 ? '#006d40' : '#ba1a1a' }}>
              {monthlyBalance >= 0 ? '¥' : '-¥'}
            </span>
            <span className="font-label-mono text-[32px] leading-tight font-bold" style={{ color: monthlyBalance >= 0 ? '#006d40' : '#ba1a1a' }}>
              {formatMoney(Math.abs(monthlyBalance))}
            </span>
          </div>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-2">
            {monthlyBalance >= 0 ? t('home.surplus') : t('home.overBudget')}
          </p>
        </div>
      </div>

      {/* 最近交易 */}
      <div className="bg-bg-card rounded-xl border border-divider shadow-sm overflow-hidden">
        <div className="p-4 border-b border-divider bg-surface-bright flex justify-between items-center">
          <h3 className="font-headline-md text-headline-md text-text-primary">{t('home.recentTransactions')}</h3>
          <Link to="/transactions" className="text-primary hover:text-primary-container font-caption-sm text-caption-sm flex items-center gap-1">
            {t('home.viewAll')} <span className="material-symbols-outlined" style={{ fontSize: '16px' }}>arrow_forward</span>
          </Link>
        </div>
        <div className="p-4">
          {isLoading ? (
            <p className="text-on-surface-variant font-body-md text-body-md text-center py-8">{t('home.loading')}</p>
          ) : recentTxns.length === 0 ? (
            <p className="text-on-surface-variant font-body-md text-body-md text-center py-8">{t('home.empty')}</p>
          ) : (
            groupedTxns.map((group, idx) => (
              <div
                key={group.date}
                className={
                  idx === 0
                    ? ''
                    : `pt-4 border-t border-divider ${idx === groupedTxns.length - 1 ? '' : 'pb-2'}`
                }
              >
                <div className="flex justify-between items-center mb-2">
                  <span className="font-caption-sm text-caption-sm text-on-surface-variant font-semibold">
                    {group.label}
                  </span>
                  <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                    {group.net >= 0 ? '¥' : '¥ -'}{Math.abs(group.net).toFixed(2)}
                  </span>
                </div>
                <div className="flex flex-col gap-1">
                  {group.txns.map((txn) => (
                    <TransactionRow
                      key={txn.id}
                      transaction={txn}
                      account={findAccount(txn.accountId)}
                      categories={[...expenseCats, ...incomeCats]}
                    />
                  ))}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Category breakdown */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <CategoryBreakdown
          title={t('home.expenseByCategory')}
          categories={expenseCats}
          transactions={thisMonthTxns}
          type="expense"
          totalAmount={thisMonthExpense}
        />
        <CategoryBreakdown
          title={t('home.incomeByCategory')}
          categories={incomeCats}
          transactions={thisMonthTxns}
          type="income"
          totalAmount={thisMonthIncome}
        />
      </div>
    </div>
  )
}
