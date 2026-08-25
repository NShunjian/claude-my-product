import { useEffect } from 'react'
import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import ReportPage from './pages/ReportPage'
import AccountPage from './pages/AccountPage'
import SettingsPage from './pages/SettingsPage'
import { initDB } from './db'
import { seedDemoData } from './utils/demoData'
import { useAppStore } from './stores/useAppStore'

function App() {
  const { isDark } = useAppStore()

  useEffect(() => {
    initDB().then(async () => {
      await seedDemoData()
    }).catch(console.error)
  }, [])

  useEffect(() => {
    if (isDark) {
      document.documentElement.classList.add('dark')
    } else {
      document.documentElement.classList.remove('dark')
    }
  }, [isDark])

  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<HomePage />} />
        <Route path="report" element={<ReportPage />} />
        <Route path="account" element={<AccountPage />} />
        <Route path="settings" element={<SettingsPage />} />
      </Route>
    </Routes>
  )
}

export default App
