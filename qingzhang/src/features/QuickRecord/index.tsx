import React, { useState, useMemo, useEffect } from 'react'
import dayjs from 'dayjs'
import { useRecordStore } from '../../stores/useRecordStore'
import { useAccountStore } from '../../stores/useAccountStore'
import { Category, Account } from '../../types'
import { db } from '../../db'
import { Close } from '../../components/Icons'

interface QuickRecordProps {
  isOpen: boolean
  onClose: () => void
}

const QuickRecord: React.FC<QuickRecordProps> = ({ isOpen, onClose }) => {
  const { addRecord } = useRecordStore()
  const { accounts, fetchAccounts } = useAccountStore()
  const [type, setType] = useState<'expense' | 'income'>('expense')
  const [amount, setAmount] = useState('')
  const [selectedCategory, setSelectedCategory] = useState<Category | null>(null)
  const [selectedAccount, setSelectedAccount] = useState<Account | null>(null)
  const [note, setNote] = useState('')
  const [recordDate, setRecordDate] = useState(dayjs().format('YYYY-MM-DD'))
  const [categories, setCategories] = useState<Category[]>([])

  useEffect(() => {
    if (isOpen) {
      fetchAccounts()
      loadCategories()
      resetForm('expense')
    }
  }, [isOpen])

  const loadCategories = async () => {
    const cats = await db.categories.toArray()
    setCategories(cats.sort((a, b) => a.sortOrder - b.sortOrder))
  }

  const filteredCategories = useMemo(
    () => categories.filter((c) => c.type === type),
    [categories, type]
  )

  const resetForm = (nextType: 'expense' | 'income') => {
    setType(nextType)
    setAmount('')
    setNote('')
    setRecordDate(dayjs().format('YYYY-MM-DD'))
    setSelectedCategory(null)
    setSelectedAccount(null)
  }

  const handleNumberClick = (value: string) => {
    if (value === 'backspace') {
      setAmount((prev) => prev.slice(0, -1))
      return
    }
    if (value === '.' && amount.includes('.')) return
    if (amount.replace('.', '').length >= 7) return
    setAmount((prev) => prev + value)
  }

  const handleSubmit = async () => {
    const numAmount = parseFloat(amount || '0')
    if (numAmount <= 0 || !selectedCategory || !selectedAccount) return

    await addRecord({
      type,
      categoryId: selectedCategory.id,
      amount: numAmount,
      accountId: selectedAccount.id,
      note,
      recordDate,
    })

    setAmount('')
    setNote('')
    setSelectedCategory(null)
    setSelectedAccount(null)
    onClose()
  }

  const numberButtons = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'backspace']

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-end bg-black/50" onClick={onClose}>
      <div
        className="w-full max-w-[480px] transform rounded-t-3xl bg-[var(--color-bg-card)] p-4 transition-transform duration-300 ease-out"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-[var(--color-text-primary)]">记一笔</h2>
          <button onClick={onClose} className="p-1 text-[var(--color-text-secondary)]">
            <Close size={24} />
          </button>
        </div>

        <div className="mb-4 flex rounded-full bg-[var(--color-bg-page)] p-1">
          <button
            onClick={() => setType('expense')}
            className={`flex-1 rounded-full py-2 text-sm font-medium transition-all ${
              type === 'expense'
                ? 'bg-[var(--color-danger)] text-white'
                : 'text-[var(--color-text-secondary)]'
            }`}
          >
            支出
          </button>
          <button
            onClick={() => setType('income')}
            className={`flex-1 rounded-full py-2 text-sm font-medium transition-all ${
              type === 'income'
                ? 'bg-[var(--color-success)] text-white'
                : 'text-[var(--color-text-secondary)]'
            }`}
          >
            收入
          </button>
        </div>

        <div className="mb-4 grid grid-cols-4 gap-2">
          {filteredCategories.map((category) => (
            <button
              key={category.id}
              onClick={() => setSelectedCategory(category)}
              className={`flex flex-col items-center gap-1 rounded-xl p-2 transition-all ${
                selectedCategory?.id === category.id
                  ? 'bg-[var(--color-primary-light)] ring-2 ring-[var(--color-primary)]'
                  : 'bg-[var(--color-bg-page)]'
              }`}
            >
              <span
                className="flex h-10 w-10 items-center justify-center rounded-full text-lg"
                style={{ backgroundColor: `${category.color}20`, color: category.color }}
              >
                {category.icon}
              </span>
              <span className="text-xs text-[var(--color-text-primary)]">{category.name}</span>
            </button>
          ))}
        </div>

        <div className="mb-4 rounded-2xl bg-[var(--color-bg-page)] p-4">
          <div className="mb-2 text-right text-3xl font-bold text-[var(--color-text-primary)]">
            ¥{amount || '0.00'}
          </div>

          <div className="mb-3 flex gap-2">
            <input
              type="date"
              value={recordDate}
              onChange={(e) => setRecordDate(e.target.value)}
              className="rounded-lg border border-[var(--color-divider)] bg-[var(--color-bg-card)] px-2 py-1 text-sm text-[var(--color-text-primary)]"
            />
            <input
              type="text"
              placeholder="备注（可选）"
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="flex-1 rounded-lg border border-[var(--color-divider)] bg-[var(--color-bg-card)] px-2 py-1 text-sm text-[var(--color-text-primary)]"
              maxLength={50}
            />
          </div>

          <div className="mb-3 flex flex-wrap gap-2">
            {accounts.map((account) => (
              <button
                key={account.id}
                onClick={() => setSelectedAccount(account)}
                className={`rounded-full px-3 py-1 text-xs transition-all ${
                  selectedAccount?.id === account.id
                    ? 'bg-[var(--color-primary)] text-white'
                    : 'bg-[var(--color-bg-card)] text-[var(--color-text-secondary)]'
                }`}
              >
                {account.name}
              </button>
            ))}
          </div>

          <div className="grid grid-cols-4 gap-2">
            {numberButtons.map((btn) => (
              <button
                key={btn}
                onClick={() => handleNumberClick(btn)}
                className="flex aspect-square items-center justify-center rounded-xl bg-[var(--color-bg-card)] text-lg font-semibold text-[var(--color-text-primary)] active:bg-[var(--color-primary-light)] active:text-[var(--color-primary)]"
              >
                {btn === 'backspace' ? '⌫' : btn === '.' ? '.' : btn}
              </button>
            ))}
          </div>
        </div>

        <button
          onClick={handleSubmit}
          disabled={!amount || !selectedCategory || !selectedAccount}
          className="w-full rounded-2xl bg-[var(--color-primary)] py-3 font-semibold text-white transition-all disabled:opacity-50"
        >
          完成
        </button>
      </div>
    </div>
  )
}

export default QuickRecord
