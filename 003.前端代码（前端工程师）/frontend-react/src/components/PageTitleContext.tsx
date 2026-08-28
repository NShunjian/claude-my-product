import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'

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

  // useState 的 setter 引用稳定；用 useMemo 锁住 value 对象本身，避免消费侧 useEffect 误以为 setTitle 变了
  const value = useMemo<PageTitleContextValue>(
    () => ({ title, setTitle, backTo, setBackTo, backLabel, setBackLabel }),
    [title, backTo, backLabel],
  )

  return <PageTitleContext.Provider value={value}>{children}</PageTitleContext.Provider>
}

export function usePageTitle(title: string): void {
  const { setTitle } = useContext(PageTitleContext)
  // 必须放在 useEffect 里，不能在 render 期间 setState：
  // render 中触发其他组件的 setState 会被 React 19 警告 + 静默丢弃，进而拖垮同帧内的其他 setState（比如 toast）。
  useEffect(() => {
    setTitle(title)
  }, [title, setTitle])
}

export function usePageBack(to: string | null, label?: string | null): void {
  const { setBackTo, setBackLabel } = useContext(PageTitleContext)
  useEffect(() => {
    setBackTo(to)
    setBackLabel(label ?? null)
  }, [to, label, setBackTo, setBackLabel])
}