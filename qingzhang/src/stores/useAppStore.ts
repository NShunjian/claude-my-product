import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import dayjs from 'dayjs'

interface AppState {
  isDark: boolean
  currentMonth: string
  toggleTheme: () => void
  setCurrentMonth: (month: string) => void
}

export const useAppStore = create<AppState>()(
  persist(
    (set) => ({
      isDark: false,
      currentMonth: dayjs().format('YYYY-MM'),
      toggleTheme: () => set((state) => ({ isDark: !state.isDark })),
      setCurrentMonth: (month: string) => set({ currentMonth: month }),
    }),
    {
      name: 'qingzhang-app-storage',
    }
  )
)
