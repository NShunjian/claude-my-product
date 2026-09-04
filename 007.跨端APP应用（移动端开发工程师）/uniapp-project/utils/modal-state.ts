import { ref } from 'vue'

/**
 * 全局 modal 打开状态 — 任何 modal 打开时置 true,关闭时置 false。
 * AppHeader 等兄弟组件 watch 这个值,在 modal 打开时把自己隐藏。
 *
 * 为什么不用 overlay 遮罩盖住 AppHeader:
 * iOS app-plus 的 WKWebView 里 .qa-overlay(z-index:10000, position:fixed) 偶尔
 * 压不住同 page-root 内 AppHeader(z-index:100, position:sticky) — sticky 元素在
 * iOS 上可能获得 elevated stacking context,导致 .qa-overlay 即便 z-index 更高也盖不住,
 * "首页" 字样漏出。调高 z-index / 加 transform translateZ / 把 modal teleport 到 body
 * 都试过,WKWebView 这边不稳定。
 *
 * 退一步:modal 打开时让 AppHeader 直接 display:none,三端视觉效果一致(H5/MP 上原本
 * 也看不到 AppHeader,只是底层机制从"被遮"变成"被隐藏")。
 */
export const modalOpen = ref(false)