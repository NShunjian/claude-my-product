/**
 * 007 uniapp-project — vitest 全局 setup
 *
 * 挑战:
 *   - 项目主进程是 uni-app 编译产物(H5 / APP-PLUS / MP-WEIXIN)
 *   - vitest 直接跑的是 Node 环境,uni.* / wx.* / getApp() 等平台 API 不存在
 *   - stores/* 用 defineStore(依赖包)需要 Pinia 实例
 *
 * 策略:
 *   - 仅测试**平台无关的纯逻辑**部分(utils/ + stores/ + 部分 components/)
 *   - 含 `<!-- #ifdef H5 || APP-PLUS -->` 等平台条件编译的代码不在本测试范围
 *   - 平台特定行为(QuickAddModal iOS 直接渲染分支等)留给真机 E2E
 *
 * 工具:vitest + happy-dom + @vue/test-utils + pinia testing helper
 */
import { afterEach, beforeAll, vi } from 'vitest'

beforeAll(() => {
  // 屏蔽 uni 全局 API(测试中碰到时返回 undefined,不崩)
  vi.stubGlobal('uni', {
    getStorageSync: () => '',
    setStorageSync: () => {},
    removeStorageSync: () => {},
    request: () => Promise.resolve({ data: {}, statusCode: 200 }),
    getSystemInfoSync: () => ({ system: 'iOS', platform: 'ios' }),
    reLaunch: () => {},
    showToast: () => {},
    hideTabBar: () => {},
    showTabBar: () => {},
    switchTab: () => {},
  })
  // 屏蔽 getApp / getCurrentPages
  vi.stubGlobal('getApp', () => ({}))
  vi.stubGlobal('getCurrentPages', () => [])
})

afterEach(() => {
  vi.restoreAllMocks()
})