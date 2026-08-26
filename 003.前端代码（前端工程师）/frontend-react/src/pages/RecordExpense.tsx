import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { EXPENSE_CATEGORIES } from '../data/categories'
import { ACCOUNTS } from '../data/accounts'

const COLOR_MAP: Record<string, string> = {
  'cat-pink': '#ED64A6',
  'cat-blue': '#4299E1',
  'cat-purple': '#805AD5',
  'cat-teal': '#319795',
  'cat-brown': '#8B6E4E',
  secondary: '#006d40',
  outline: '#727782',
}

export function RecordExpense() {
  const navigate = useNavigate()
  const [amount, setAmount] = useState<string>('')
  const [note, setNote] = useState<string>('')
  const [categoryId, setCategoryId] = useState<string>('food')
  const [accountId, setAccountId] = useState<string>(ACCOUNTS[0]?.id ?? '')
  const [showSuccess, setShowSuccess] = useState<boolean>(false)

  function handleSubmit(e: React.FormEvent<HTMLFormElement>): void {
    e.preventDefault()
    if (!amount) return
    setShowSuccess(true)
    setTimeout(() => navigate(-1), 1200)
  }

  function handleClose(): void {
    navigate(-1)
  }

  return (
    <div className="fixed inset-0 z-50 flex flex-col justify-end md:justify-center items-center pointer-events-none p-0 md:p-6">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-on-background/60 backdrop-blur-sm pointer-events-auto"
        onClick={handleClose}
      />

      {/* Sheet */}
      <div className="w-full max-w-md bg-bg-card rounded-t-[24px] md:rounded-xl shadow-2xl pointer-events-auto flex flex-col max-h-[90vh] md:max-h-[800px] overflow-hidden border border-divider relative z-10">
        {/* Handle */}
        <div className="flex justify-center pt-3 pb-1 md:hidden">
          <div className="w-10 h-1 rounded-full bg-outline-variant" />
        </div>

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-divider">
          <h2 className="font-headline-md text-headline-md text-text-primary">记一笔支出</h2>
          <button
            type="button"
            onClick={handleClose}
            className="text-on-surface-variant hover:text-primary transition-colors p-1"
          >
            <span className="material-symbols-outlined text-2xl">close</span>
          </button>
        </div>

        {showSuccess ? (
          <div className="flex-1 flex flex-col items-center justify-center p-8">
            <div className="w-16 h-16 rounded-full bg-secondary-container flex items-center justify-center mb-4">
              <span className="material-symbols-outlined text-secondary text-3xl" style={{ fontVariationSettings: "'FILL' 1" }}>check</span>
            </div>
            <p className="font-headline-md text-headline-md text-text-primary">记录成功</p>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-6">
            {/* Amount display */}
            <div className="text-center">
              <p className="font-label-mono text-label-mono text-primary mb-1">
                {amount ? `-¥${amount}` : '-¥0.00'}
              </p>
              <input
                type="text"
                inputMode="decimal"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.00"
                className="w-full text-center text-4xl font-label-mono text-text-primary bg-transparent outline-none border-b-2 border-divider focus:border-primary transition-colors pb-2 placeholder-outline"
              />
            </div>

            {/* Category grid */}
            <div>
              <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">选择分类</p>
              <div className="grid grid-cols-4 gap-2">
                {EXPENSE_CATEGORIES.map((cat) => {
                  const color = COLOR_MAP[cat.colorToken]
                  const isSelected = cat.id === categoryId
                  return (
                    <button
                      key={cat.id}
                      type="button"
                      onClick={() => setCategoryId(cat.id)}
                      className={`flex flex-col items-center gap-1 p-2 rounded-xl transition-colors ${
                        isSelected ? 'bg-primary-light border-2 border-primary' : 'bg-surface-container'
                      }`}
                    >
                      <span
                        className="material-symbols-outlined text-xl"
                        style={{ color, fontVariationSettings: "'FILL' 1" }}
                      >
                        {cat.icon}
                      </span>
                      <span className="font-caption-sm text-caption-sm text-text-primary">
                        {cat.name}
                      </span>
                    </button>
                  )
                })}
              </div>
            </div>

            {/* Account */}
            <div>
              <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">账户</p>
              <select
                className="w-full bg-surface-container border border-outline-variant text-text-primary text-body-md font-body-md rounded-lg py-3 px-4 focus:border-primary focus:ring-0"
                value={accountId}
                onChange={(e) => setAccountId(e.target.value)}
              >
                {ACCOUNTS.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    {acc.name}
                  </option>
                ))}
              </select>
            </div>

            {/* Note */}
            <div>
              <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">备注</p>
              <input
                type="text"
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="添加备注..."
                className="w-full bg-surface-container border border-outline-variant text-text-primary text-body-md font-body-md rounded-lg py-3 px-4 focus:border-primary focus:ring-0 placeholder-outline"
              />
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={!amount}
              className="w-full bg-primary text-on-primary font-headline-md text-headline-md py-3 rounded-lg hover:bg-primary-container transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
            >
              保存
            </button>
          </form>
        )}
      </div>
    </div>
  )
}
