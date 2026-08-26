import { createContext, useContext, useState, type ReactNode } from 'react'

interface PageTitleContextValue {
  title: string
  setTitle: (title: string) => void
}

export const PageTitleContext = createContext<PageTitleContextValue>({
  title: '',
  setTitle: () => {},
})

export function PageTitleProvider({ children }: { children: ReactNode }) {
  const [title, setTitle] = useState<string>('')

  return (
    <PageTitleContext.Provider value={{ title, setTitle }}>
      {children}
    </PageTitleContext.Provider>
  )
}

export function usePageTitle(title: string): void {
  const { setTitle } = useContext(PageTitleContext)
  // Set title on every render — title value is constant per page so it's safe
  setTitle(title)
}
