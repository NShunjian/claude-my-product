import { useMemo } from 'react'
import { RecordModal } from '../components/RecordModal'
import { RECORDS_CHANGED_EVENT, useAccounts, useCategories } from '../lib/hooks'
import { toAccounts, toCategories } from '../lib/finance-mappers'
import * as recordsApi from '../api/records'

export function RecordExpense() {
  const accountsQ = useAccounts()
  const catsQ = useCategories('expense')

  const accounts = useMemo(() => (accountsQ.data ? toAccounts(accountsQ.data) : []), [accountsQ.data])
  const categories = useMemo(() => (catsQ.data ? toCategories(catsQ.data) : []), [catsQ.data])

  async function handleSubmit(payload: {
    type: 'expense' | 'income'
    categoryId: string
    accountId: string
    amount: number
    note: string
    recordDate: string
  }): Promise<void> {
    // RecordModal 只对 expense/income 调用,RecordExpense 固定 type=expense
    await recordsApi.createRecord({
      type: 'expense',
      categoryId: payload.categoryId,
      accountId: payload.accountId,
      amount: payload.amount,
      note: payload.note || undefined,
      recordDate: payload.recordDate,
    })
    // 触发外部列表刷新(若在 history 列表页)
    window.dispatchEvent(new CustomEvent(RECORDS_CHANGED_EVENT))
  }

  return (
    <RecordModal
      kind="expense"
      categories={categories}
      accounts={accounts}
      defaultCategoryId={categories[0]?.id}
      accent="primary"
      onSubmit={handleSubmit}
    />
  )
}