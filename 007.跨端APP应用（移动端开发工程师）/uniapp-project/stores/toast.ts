import { defineStore } from 'pinia'
import { ref } from 'vue'

interface ToastItem { id: number; message: string }

let counter = 0

export const useToastStore = defineStore('toast', () => {
  const items = ref<ToastItem[]>([])

  function show(message: string, duration = 3000) {
    const id = ++counter
    items.value.push({ id, message })
    setTimeout(() => {
      items.value = items.value.filter(i => i.id !== id)
    }, duration)
  }

  return { items, show }
})
