import { Navigate, Route, Routes } from 'react-router-dom'
import { ProtectedRoute } from './auth/ProtectedRoute'
import { SidebarLayout } from './layouts/SidebarLayout'
import { Login } from './pages/Login'
import { Home } from './pages/Home'
import { Transactions } from './pages/Transactions'
import { RecordExpense } from './pages/RecordExpense'
import { RecordIncome } from './pages/RecordIncome'
import { ReportMonthly } from './pages/ReportMonthly'
import { ReportYearly } from './pages/ReportYearly'
import { Accounts } from './pages/Accounts'
import { AccountAdd } from './pages/AccountAdd'
import { Books } from './pages/Books'
import { BookMembers } from './pages/BookMembers'
import { Settings } from './pages/Settings'
import { ProfileEdit } from './pages/ProfileEdit'

export default function App() {
  return (
    <Routes>
      {/* Standalone */}
      <Route path="/login" element={<Login />} />

      {/* Record modals — NOT under SidebarLayout */}
      <Route path="/record/expense" element={<RecordExpense />} />
      <Route path="/record/income" element={<RecordIncome />} />

      {/* Protected with sidebar layout */}
      <Route element={<ProtectedRoute />}>
        <Route element={<SidebarLayout />}>
          <Route path="/" element={<Home />} />
          <Route path="/transactions" element={<Transactions />} />
          <Route path="/reports/monthly" element={<ReportMonthly />} />
          <Route path="/reports/yearly" element={<ReportYearly />} />
          <Route path="/accounts" element={<Accounts />} />
          <Route path="/accounts/new" element={<AccountAdd />} />
          <Route path="/books" element={<Books />} />
          <Route path="/books/:uuid/members" element={<BookMembers />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/profile/edit" element={<ProfileEdit />} />
        </Route>
      </Route>

      {/* Fallback */}
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
