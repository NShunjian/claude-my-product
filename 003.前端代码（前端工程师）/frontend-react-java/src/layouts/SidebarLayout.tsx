import { Outlet } from 'react-router-dom'
import { PageTitleProvider } from '../components/PageTitleContext'
import { Sidebar } from '../components/Sidebar'
import { TopBar } from '../components/TopBar'
import { BookProvider } from '../lib/book-context'

export function SidebarLayout() {
  return (
    <PageTitleProvider>
      <BookProvider>
        <div className="flex">
          <Sidebar />
          <main className="flex-1 ml-64 flex flex-col min-h-screen">
            <TopBar />
            <div className="p-8 w-full">
              <Outlet />
            </div>
          </main>
        </div>
      </BookProvider>
    </PageTitleProvider>
  )
}
