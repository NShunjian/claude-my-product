import { Navigate, Route, Routes } from 'react-router-dom'
import { AdminAuthProvider } from './auth/AdminAuthContext'
import { AdminLayout } from './layouts/AdminLayout'
import { ConfirmDialogRender, ConfirmProvider } from './components/ConfirmDialog'
import { ProtectedRoute } from './components/ProtectedRoute'
import { ToastProvider } from './components/Toast'
import { AdminLogin } from './pages/AdminLogin'
import { AdminDashboard } from './pages/AdminDashboard'

function Placeholder({ name }: { name: string }) {
  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-2">{name}</h1>
      <p className="text-on-surface-variant">B4 占位页面</p>
    </div>
  )
}

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
            <Route path="/users" element={<Placeholder name="用户管理" />} />
            <Route path="/categories" element={<Placeholder name="预设分类" />} />
            <Route path="/books" element={<Placeholder name="账本审计" />} />
            <Route path="/records" element={<Placeholder name="流水审计" />} />
            <Route path="/audit-logs" element={<Placeholder name="审计日志" />} />
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
