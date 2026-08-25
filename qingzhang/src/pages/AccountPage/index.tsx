import React, { useState, useEffect } from 'react'
import { useAccountStore } from '../../stores/useAccountStore'
import { Account } from '../../types'
import { Plus } from '../../components/Icons'

const AccountPage: React.FC = () => {
  const { accounts, fetchAccounts, addAccount, deleteAccount, updateAccount } = useAccountStore()
  const [isFormOpen, setIsFormOpen] = useState(false)
  const [editingAccount, setEditingAccount] = useState<Account | null>(null)
  const [name, setName] = useState('')
  const [initialBalance, setInitialBalance] = useState('')

  useEffect(() => {
    fetchAccounts()
  }, [fetchAccounts])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name || initialBalance === '') return

    const balance = parseFloat(initialBalance)
    if (editingAccount) {
      await updateAccount(editingAccount.id, { name, initialBalance: balance })
    } else {
      await addAccount({
        name,
        icon: '💳',
        initialBalance: balance,
        isDefault: false,
        sortOrder: accounts.length,
      })
    }
    resetForm()
    fetchAccounts()
  }

  const resetForm = () => {
    setName('')
    setInitialBalance('')
    setEditingAccount(null)
    setIsFormOpen(false)
  }

  const handleEdit = (account: Account) => {
    setEditingAccount(account)
    setName(account.name)
    setInitialBalance(account.initialBalance.toString())
    setIsFormOpen(true)
  }

  const handleDelete = async (account: Account) => {
    if (window.confirm('确定要删除该账户吗？')) {
      try {
        await deleteAccount(account.id)
        fetchAccounts()
      } catch (error: any) {
        alert(error.message)
      }
    }
  }

  const totalBalance = accounts.reduce((sum, a) => sum + a.balance, 0)

  return (
    <div className="min-h-full pb-20">
      <header className="sticky top-0 z-10 bg-[var(--color-bg-page)] px-4 py-4">
        <h1 className="text-xl font-bold text-[var(--color-text-primary)]">账户</h1>
      </header>

      <div className="px-4 pb-4">
        <div className="mb-4 rounded-2xl bg-gradient-to-br from-[var(--color-primary)] to-[#63b3ed] p-4 text-white">
          <div className="text-sm opacity-80">总资产</div>
          <div className="mt-1 text-3xl font-bold">¥{totalBalance.toFixed(2)}</div>
        </div>

        <div className="space-y-3">
          {accounts.map((account) => (
            <div
              key={account.id}
              className="flex items-center justify-between rounded-2xl bg-[var(--color-bg-card)] p-4 shadow-sm"
            >
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-full bg-[var(--color-primary-light)] text-2xl text-[var(--color-primary)]">
                  {account.icon}
                </div>
                <div>
                  <div className="font-medium text-[var(--color-text-primary)]">{account.name}</div>
                  <div className="text-sm text-[var(--color-text-secondary)]">余额 ¥{account.balance.toFixed(2)}</div>
                </div>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => handleEdit(account)}
                  className="rounded-lg px-3 py-1 text-sm text-[var(--color-primary)]"
                >
                  编辑
                </button>
                <button
                  onClick={() => handleDelete(account)}
                  className="rounded-lg px-3 py-1 text-sm text-[var(--color-danger)]"
                >
                  删除
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>

      <button
        onClick={() => setIsFormOpen(true)}
        className="fixed bottom-20 right-4 z-30 flex h-14 w-14 items-center justify-center rounded-full bg-[var(--color-primary)] text-white shadow-lg"
      >
        <Plus size={28} />
      </button>

      {isFormOpen && (
        <div className="fixed inset-0 z-50 flex items-end bg-black/50" onClick={resetForm}>
          <div
            className="w-full rounded-t-3xl bg-[var(--color-bg-card)] p-4"
            onClick={(e) => e.stopPropagation()}
          >
            <h2 className="mb-4 text-lg font-semibold text-[var(--color-text-primary)]">
              {editingAccount ? '编辑账户' : '新增账户'}
            </h2>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="mb-1 block text-sm text-[var(--color-text-secondary)]">账户名称</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full rounded-xl border border-[var(--color-divider)] bg-[var(--color-bg-page)] px-4 py-3 text-[var(--color-text-primary)]"
                  placeholder="如：招商银行"
                />
              </div>
              <div>
                <label className="mb-1 block text-sm text-[var(--color-text-secondary)]">初始余额</label>
                <input
                  type="number"
                  value={initialBalance}
                  onChange={(e) => setInitialBalance(e.target.value)}
                  className="w-full rounded-xl border border-[var(--color-divider)] bg-[var(--color-bg-page)] px-4 py-3 text-[var(--color-text-primary)]"
                  placeholder="0.00"
                />
              </div>
              <div className="flex gap-3">
                <button
                  type="button"
                  onClick={resetForm}
                  className="flex-1 rounded-xl border border-[var(--color-divider)] py-3 text-[var(--color-text-primary)]"
                >
                  取消
                </button>
                <button
                  type="submit"
                  className="flex-1 rounded-xl bg-[var(--color-primary)] py-3 text-white"
                >
                  保存
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}

export default AccountPage
