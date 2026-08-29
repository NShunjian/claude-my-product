import { Component } from 'react'
import type { ErrorInfo, ReactNode } from 'react'
import { useLanguage } from '../i18n/LanguageContext'

interface Props {
  children: ReactNode
}

interface State {
  error: Error | null
}

/**
 * 顶层错误边界：捕获子树 render 阶段抛出的错误，避免整张 App 白屏。
 * fallback 提供"刷新页面"按钮，把 reload 责任交给用户。
 */
// ErrorBoundary 是 class component,不能直接用 hook。包一个函数式壳子把 t() 注入。
function ErrorBoundaryView({
  children,
}: {
  children: (t: (key: string) => string) => ReactNode
}): ReactNode {
  const { t } = useLanguage()
  return children(t)
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null }

  static getDerivedStateFromError(error: Error): State {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    // 只在 console 留痕,不上报(暂无埋点基础设施)
    console.error('[ErrorBoundary] caught error', error, info.componentStack)
  }

  private handleReload = (): void => {
    window.location.reload()
  }

  private handleReset = (): void => {
    // 尝试回到首页而非整页 reload——若错误只发生在某个页面,这能让用户继续用其他功能
    this.setState({ error: null })
    if (window.location.pathname !== '/') {
      window.location.assign('/')
    }
  }

  render(): ReactNode {
    const { error } = this.state
    if (!error) return this.props.children

    return (
      <ErrorBoundaryView>
        {(t) => (
          <div
            role="alert"
            className="bg-bg-page text-text-primary min-h-screen flex flex-col items-center justify-center p-8 font-body-md text-body-md"
          >
            <span
              className="material-symbols-outlined text-error mb-4"
              style={{ fontSize: '48px', fontVariationSettings: "'FILL' 1" }}
              aria-hidden="true"
            >
              error
            </span>
            <h1 className="font-headline-lg text-headline-lg text-text-primary mb-2">
              {t('errorBoundary.title')}
            </h1>
            <p className="text-on-surface-variant mb-6 text-center max-w-md">
              {t('errorBoundary.desc')}
            </p>
            <div className="flex gap-3">
              <button
                type="button"
                onClick={this.handleReset}
                className="px-5 py-2.5 border border-outline text-on-surface rounded-lg hover:bg-surface-container-low transition-colors"
              >
                {t('errorBoundary.backHome')}
              </button>
              <button
                type="button"
                onClick={this.handleReload}
                className="px-5 py-2.5 bg-primary text-on-primary rounded-lg hover:bg-primary-container transition-colors"
              >
                {t('errorBoundary.reload')}
              </button>
            </div>
            {import.meta.env.DEV && (
              <pre className="mt-8 px-4 py-3 bg-surface-container-low text-on-surface-variant rounded text-xs max-w-2xl overflow-auto">
                {error.message}
              </pre>
            )}
          </div>
        )}
      </ErrorBoundaryView>
    )
  }
}
