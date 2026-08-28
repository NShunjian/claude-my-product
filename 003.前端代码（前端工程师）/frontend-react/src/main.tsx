import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { AuthProvider } from './auth/AuthContext'
import { LanguageProvider } from './i18n/LanguageContext'
import { setInitialHtmlTheme, ThemeProvider } from './theme/ThemeContext'
import { VersionProvider } from './version/VersionContext'
import './index.css'

const rootEl = document.getElementById('root')
if (!rootEl) throw new Error('root element missing')

// 防 FOUC: 在 createRoot 之前同步读 localStorage 并在 <html> 上设 .dark 类
setInitialHtmlTheme()

createRoot(rootEl).render(
  <StrictMode>
    <BrowserRouter>
      <LanguageProvider>
        <VersionProvider>
          <ThemeProvider>
            <AuthProvider>
              <App />
            </AuthProvider>
          </ThemeProvider>
        </VersionProvider>
      </LanguageProvider>
    </BrowserRouter>
  </StrictMode>,
)