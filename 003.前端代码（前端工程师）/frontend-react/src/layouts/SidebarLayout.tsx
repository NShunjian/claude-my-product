import { Outlet } from 'react-router-dom'
import { PageTitleProvider } from '../components/PageTitleContext'
import { Sidebar } from '../components/Sidebar'
import { TopBar } from '../components/TopBar'

export function SidebarLayout() {
  return (
    <PageTitleProvider>
      <div className="flex">
        <Sidebar />
        <main className="flex-1 ml-64 flex flex-col min-h-screen">
          <TopBar />
          <div className="p-8 max-w-5xl mx-auto w-full">
            <Outlet />
          </div>
        </main>
      </div>
    </PageTitleProvider>
  )
}
