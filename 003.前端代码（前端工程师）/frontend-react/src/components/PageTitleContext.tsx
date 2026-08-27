import { createContext, useContext, useState, type ReactNode } from 'react'

interface PageTitleContextValue {
  title: string
  setTitle: (title: string) => void
  backTo: string | null
  setBackTo: (to: string | null) => void
  backLabel: string | null
  setBackLabel: (label: string | null) => void
}

export const PageTitleContext = createContext<PageTitleContextValue>({
  title: '',
  setTitle: () => {},
  backTo: null,
  setBackTo: () => {},
  backLabel: null,
  setBackLabel: () => {},
})

export function PageTitleProvider({ children }: { children: ReactNode }) {
  const [title, setTitle] = useState<string>('')
  const [backTo, setBackTo] = useState<string | null>(null)
  const [backLabel, setBackLabel] = useState<string | null>(null)

  return (
    <PageTitleContext.Provider
      value={{ title, setTitle, backTo, setBackTo, backLabel, setBackLabel }}
    >
      {children}
    </PageTitleContext.Provider>
  )
}

export function usePageTitle(title: string): void {
  const { setTitle } = useContext(PageTitleContext)
  // Set title on every render — title value is constant per page so it's safe
  setTitle(title)
}

export function usePageBack(to: string | null, label?: string | null): void {
  const { setBackTo, setBackLabel } = useContext(PageTitleContext)
  setBackTo(to)
  setBackLabel(label ?? null)
}