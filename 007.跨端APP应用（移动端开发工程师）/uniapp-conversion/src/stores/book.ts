import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import * as api from '@/api/books'
import type { Book } from '@/api/books'

const CURRENT_KEY = 'qz_current_book_uuid'

export const useBookStore = defineStore('book', () => {
  const books = ref<Book[]>([])
  const currentId = ref<string | null>(uni.getStorageSync(CURRENT_KEY) ?? null)
  const loading = ref(false)

  const current = computed(() => books.value.find(b => b.uuid === currentId.value) ?? null)

  async function reload() {
    loading.value = true
    try {
      books.value = await api.listBooks()
      // 优先用持久化的 currentId,否则选 is_default,再否则选第一个
      if (!currentId.value || !books.value.find(b => b.uuid === currentId.value)) {
        const def = books.value.find(b => b.isDefault) ?? books.value[0]
        if (def) {
          currentId.value = def.uuid
          uni.setStorageSync(CURRENT_KEY, def.uuid)
        }
      }
    } finally {
      loading.value = false
    }
  }

  function setCurrent(uuid: string) {
    currentId.value = uuid
    uni.setStorageSync(CURRENT_KEY, uuid)
  }

  async function createBook(input: api.CreateBookInput) {
    const b = await api.createBook(input)
    await reload()
    return b
  }

  async function updateBook(uuid: string, input: api.UpdateBookInput) {
    const b = await api.updateBook(uuid, input)
    await reload()
    return b
  }

  async function deleteBook(uuid: string) {
    await api.deleteBook(uuid)
    if (currentId.value === uuid) currentId.value = null
    await reload()
  }

  async function setDefault(uuid: string) {
    const b = await api.setDefaultBook(uuid)
    await reload()
    return b
  }

  return { books, current, currentId, loading, reload, setCurrent, createBook, updateBook, deleteBook, setDefault }
})
