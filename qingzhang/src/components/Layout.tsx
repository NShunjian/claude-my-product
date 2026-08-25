import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useEffect } from 'react'
import { useRecordStore } from '../stores/useRecordStore'
import { useAccountStore } from '../stores/useAccountStore'
import TabBar from './TabBar'
import { Home, PieChart, Wallet, Settings } from './Icons'

const tabs = [
  { key: 'home', label: '首页', path: '/', icon: Home },
  { key: 'report', label: '报表', path: '/report', icon: PieChart },
  { key: 'account', label: '账户', path: '/account', icon: Wallet },
  { key: 'settings', label: '我的', path: '/settings', icon: Settings },
]

function Layout() {
  const location = useLocation()
  const navigate = useNavigate()
  const { fetchRecords } = useRecordStore()
  const { fetchAccounts } = useAccountStore()

  useEffect(() => {
    fetchRecords()
    fetchAccounts()
  }, [fetchRecords, fetchAccounts])

  return (
    <div className="flex h-full flex-col">
      <main className="flex-1 overflow-y-auto overflow-x-hidden pb-20">
        <Outlet />
      </main>
      <TabBar tabs={tabs} activePath={location.pathname} onChange={(path) => navigate(path)} />
    </div>
  )
}

export default Layout
