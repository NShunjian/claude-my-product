import { defineStore } from 'pinia'
import { ref } from 'vue'

/**
 * 快速记账弹框全局状态 —— modal 挂在 App.vue(窗口最外层)而不是某个 page 内部,
 * 避免被 page-root 的 position:fixed + bottom:var(--tab-bar-height) 容器裁掉底部。
 * 任何 page 想打开就直接 quickAdd.open('expense' | 'income'),close 也走 store。
 * savedAt 是单调递增的时间戳,page 端 watch 它就能在保存后拿到回调(emit
 * 'saved' 不再适合跨组件层级)。
 */
export const useQuickAddStore = defineStore('quickAdd', () => {
  const show = ref(false)
  const kind = ref<'expense' | 'income'>('expense')
  // 每次保存成功 +1,page watch 它就能在保存后做刷新。
  const savedAt = ref(0)

  function open(k: 'expense' | 'income' = 'expense') {
    kind.value = k
    show.value = true
  }

  function close() {
    show.value = false
  }

  function notifySaved() {
    savedAt.value++
  }

  return { show, kind, savedAt, open, close, notifySaved }
})