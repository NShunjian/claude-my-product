import { useEffect } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import ReportPage from './pages/ReportPage'
import AccountPage from './pages/AccountPage'
import SettingsPage from './pages/SettingsPage'
import AuthPage from './pages/AuthPage'
import { initDB } from './db'
import { seedDemoData } from './utils/demoData'
import { useAppStore } from './stores/useAppStore'
import { useAuthStore } from './stores/useAuthStore'

function App() {
  const { isDark } = useAppStore()
  const { isAuthenticated } = useAuthStore()

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
      <Route
        path="/login"
        element={isAuthenticated ? <Navigate to="/" replace /> : <AuthPage />}
      />
      <Route
        path="/"
        element={isAuthenticated ? <Layout /> : <Navigate to="/login" replace />}
      >
        <Route index element={<HomePage />} />
        <Route path="report" element={<ReportPage />} />
        <Route path="account" element={<AccountPage />} />
        <Route path="settings" element={<SettingsPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default App
