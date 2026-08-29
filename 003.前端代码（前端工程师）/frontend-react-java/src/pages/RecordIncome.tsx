import { useMemo } from 'react'
import { RecordModal } from '../components/RecordModal'
import { RECORDS_CHANGED_EVENT, useAccounts, useCategories } from '../lib/hooks'
import { toAccounts, toCategories } from '../lib/finance-mappers'
import * as recordsApi from '../api/records'

export function RecordIncome() {
  const accountsQ = useAccounts()
  const catsQ = useCategories('income')

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
    await recordsApi.createRecord({
      type: 'income',
      categoryId: payload.categoryId,
      accountId: payload.accountId,
      amount: payload.amount,
      note: payload.note || undefined,
      recordDate: payload.recordDate,
    })
    window.dispatchEvent(new CustomEvent(RECORDS_CHANGED_EVENT))
  }

  return (
    <RecordModal
      kind="income"
      categories={categories}
      accounts={accounts}
      defaultCategoryId={categories[0]?.id}
      accent="secondary"
      onSubmit={handleSubmit}
    />
  )
}