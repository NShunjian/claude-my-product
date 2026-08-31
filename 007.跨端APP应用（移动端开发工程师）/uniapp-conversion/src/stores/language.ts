import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Lang } from '@/i18n/dict'

const KEY = 'qz_lang'

export const useLanguageStore = defineStore('language', () => {
  const lang = ref<Lang>((uni.getStorageSync(KEY) as Lang) ?? 'zh-CN')

  function setLang(l: Lang) {
    lang.value = l
    uni.setStorageSync(KEY, l)
  }

  function hydrate() { /* 启动时已从 storage 读,无需操作 */ }

  return { lang, setLang, hydrate }
})
