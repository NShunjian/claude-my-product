/**
 * 006 admin-frontend — vitest 全局 setup
 *
 * 职责:
 *   - @testing-library/react 自动 cleanup
 *   - 注入 window.matchMedia polyfill(react-router 7 + 暗色主题依赖)
 *   - 屏蔽 AntD / Tailwind 噪音
 *
 * 工具栈:vitest + @testing-library/react + happy-dom + MSW(可选)
 */
import { afterEach, beforeAll } from 'vitest'
import { cleanup } from '@testing-library/react'
import '@testing-library/jest-dom/vitest'

afterEach(() => {
  cleanup()
})

beforeAll(() => {
  if (!window.matchMedia) {
    Object.defineProperty(window, 'matchMedia', {
      writable: true,
      value: (query: string) => ({
        matches: false,
        media: query,
        onchange: null,
        addListener: () => {},
        removeListener: () => {},
        addEventListener: () => {},
        removeEventListener: () => {},
        dispatchEvent: () => false,
      }),
    })
  }
})