import Dexie, { Table } from 'dexie'
import { Record, Account, Category } from '../types'
import { createPresetCategories } from '../constants/categories'
import { PRESET_ACCOUNTS } from '../constants/accounts'

class QingZhangDB extends Dexie {
  records!: Table<Record, string>
  accounts!: Table<Account, string>
  categories!: Table<Category, string>

  constructor() {
    super('qingzhang')
    this.version(1).stores({
      records: 'id, type, categoryId, accountId, recordDate, createdAt',
      accounts: 'id, isDefault, sortOrder',
      categories: 'id, type, sortOrder',
    })
  }
}

export const db = new QingZhangDB()

export const initDB = async () => {
  const categoryCount = await db.categories.count()
  if (categoryCount === 0) {
    await db.categories.bulkAdd(createPresetCategories())
  }

  const accountCount = await db.accounts.count()
  if (accountCount === 0) {
    await db.accounts.bulkAdd(PRESET_ACCOUNTS.map((a) => ({ ...a })))
  }
}
