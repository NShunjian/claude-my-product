import { computed } from 'vue'
import { t as translate, LANGS, type Lang } from './dict'
import { useLanguageStore } from '@/stores/language'

export { LANGS, type Lang } from './dict'

export function useLanguage() {
  const store = useLanguageStore()
  const t = (key: string) => translate(store.lang, key)
  return { lang: computed(() => store.lang), setLang: store.setLang, t, LANGS }
}
