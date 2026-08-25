import { create } from 'zustand'
import { Record, RecordWithDetails } from '../types'
import { db } from '../db'
import { v4 as uuidv4 } from 'uuid'

interface RecordState {
  records: RecordWithDetails[]
  addRecord: (record: Omit<Record, 'id' | 'createdAt' | 'updatedAt'>) => Promise<void>
  updateRecord: (id: string, record: Partial<Record>) => Promise<void>
  deleteRecord: (id: string) => Promise<void>
  fetchRecords: () => Promise<void>
}

export const useRecordStore = create<RecordState>((set) => ({
  records: [],

  addRecord: async (recordData) => {
    const now = Date.now()
    const newRecord: Record = {
      ...recordData,
      id: uuidv4(),
      createdAt: now,
      updatedAt: now,
    }
    await db.records.add(newRecord)
  },

  updateRecord: async (id, record) => {
    await db.records.update(id, { ...record, updatedAt: Date.now() })
  },

  deleteRecord: async (id) => {
    await db.records.delete(id)
  },

  fetchRecords: async () => {
    const records = await db.records.toArray()
    const categories = await db.categories.toArray()
    const accounts = await db.accounts.toArray()

    const categoryMap = new Map(categories.map((c) => [c.id, c]))
    const accountMap = new Map(accounts.map((a) => [a.id, a]))

    const recordsWithDetails: RecordWithDetails[] = records.map((r) => ({
      ...r,
      category: categoryMap.get(r.categoryId) || ({} as any),
      account: accountMap.get(r.accountId) || ({} as any),
    }))

    set({ records: recordsWithDetails })
  },
}))
