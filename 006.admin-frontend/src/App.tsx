import { Navigate, Route, Routes } from 'react-router-dom'
import { AdminAuthProvider } from './auth/AdminAuthContext'
import { AdminLayout } from './layouts/AdminLayout'
import { ConfirmDialogRender, ConfirmProvider } from './components/ConfirmDialog'
import { ProtectedRoute } from './components/ProtectedRoute'
import { ToastProvider } from './components/Toast'
import { AdminLogin } from './pages/AdminLogin'
import { AdminDashboard } from './pages/AdminDashboard'
import { AdminUsers } from './pages/AdminUsers'
import { AdminCategories } from './pages/AdminCategories'
import { AdminBooks } from './pages/AdminBooks'
import { AdminRecords } from './pages/AdminRecords'
import { AdminAuditLogs } from './pages/AdminAuditLogs'

function App() {
  const confirmApi = ConfirmProvider()
  return (
    <AdminAuthProvider>
      <ConfirmDialogRender api={confirmApi} />
      <ToastProvider>
        <Routes>
          <Route path="/login" element={<AdminLogin />} />
          <Route element={<ProtectedRoute><AdminLayout /></ProtectedRoute>}>
            <Route path="/dashboard" element={<AdminDashboard />} />
            <Route path="/users" element={<AdminUsers />} />
            <Route path="/categories" element={<AdminCategories />} />
            <Route path="/books" element={<AdminBooks />} />
            <Route path="/records" element={<AdminRecords />} />
            <Route path="/audit-logs" element={<AdminAuditLogs />} />
          </Route>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="*" element={
            <div className="min-h-screen flex items-center justify-center text-on-surface-variant">
              404 — 页面不存在
            </div>
          } />
        </Routes>
      </ToastProvider>
    </AdminAuthProvider>
  )
}

export default App
