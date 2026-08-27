import { RecordModal } from '../components/RecordModal'
import { INCOME_CATEGORIES } from '../data/categories'

export function RecordIncome() {
  return (
    <RecordModal
      kind="income"
      categories={INCOME_CATEGORIES}
      defaultCategoryId="salary"
      accent="secondary"
    />
  )
}