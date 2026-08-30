import { Navigate, Route, Routes } from 'react-router-dom'
import { AdminAuthProvider } from './auth/AdminAuthContext'
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
  return (
    <AdminAuthProvider>
      <ToastProvider>
        <Routes>
          <Route path="/login" element={<AdminLogin />} />
          <Route path="/dashboard" element={
            <ProtectedRoute><AdminDashboard /></ProtectedRoute>
          } />
          <Route path="/users" element={
            <ProtectedRoute><Placeholder name="用户管理" /></ProtectedRoute>
          } />
          <Route path="/categories" element={
            <ProtectedRoute><Placeholder name="预设分类" /></ProtectedRoute>
          } />
          <Route path="/books" element={
            <ProtectedRoute><Placeholder name="账本审计" /></ProtectedRoute>
          } />
          <Route path="/records" element={
            <ProtectedRoute><Placeholder name="流水审计" /></ProtectedRoute>
          } />
          <Route path="/audit-logs" element={
            <ProtectedRoute><Placeholder name="审计日志" /></ProtectedRoute>
          } />
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
