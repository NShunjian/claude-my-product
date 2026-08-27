import { RecordModal } from '../components/RecordModal'
import { EXPENSE_CATEGORIES } from '../data/categories'

export function RecordExpense() {
  return (
    <RecordModal
      kind="expense"
      categories={EXPENSE_CATEGORIES}
      defaultCategoryId="food"
      accent="primary"
    />
  )
}