import { create } from 'zustand'
import { Account } from '../types'
import { db } from '../db'
import { v4 as uuidv4 } from 'uuid'

interface AccountState {
  accounts: Account[]
  fetchAccounts: () => Promise<void>
  addAccount: (account: Omit<Account, 'id' | 'balance'>) => Promise<void>
  updateAccount: (id: string, account: Partial<Account>) => Promise<void>
  deleteAccount: (id: string) => Promise<void>
}

export const useAccountStore = create<AccountState>((set) => ({
  accounts: [],

  fetchAccounts: async () => {
    const accounts = await db.accounts.toArray()
    const records = await db.records.toArray()

    const accountsWithBalance = accounts.map((account) => {
      const relatedRecords = records.filter((r) => r.accountId === account.id)
      const income = relatedRecords
        .filter((r) => r.type === 'income')
        .reduce((sum, r) => sum + r.amount, 0)
      const expense = relatedRecords
        .filter((r) => r.type === 'expense')
        .reduce((sum, r) => sum + r.amount, 0)
      return { ...account, balance: account.initialBalance + income - expense }
    })

    set({ accounts: accountsWithBalance })
  },

  addAccount: async (accountData) => {
    const account: Account = {
      ...accountData,
      id: uuidv4(),
      balance: accountData.initialBalance,
    }
    await db.accounts.add(account)
  },

  updateAccount: async (id, account) => {
    await db.accounts.update(id, account)
  },

  deleteAccount: async (id) => {
    const count = await db.records.where('accountId').equals(id).count()
    if (count > 0) {
      throw new Error(`该账户有${count}笔记录，无法删除`)
    }
    await db.accounts.delete(id)
  },
}))
