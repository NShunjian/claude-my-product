/**
 * Toast Store:对齐 uniapp stores/toast.ts 1:1。
 */
import { AppStorageV2 } from '@kit.ArkUI'
import type { ToastItem } from '../model/Types'

@ObservedV2
export class ToastStore {
  @Trace items: ToastItem[] = []
  private nextId: number = 1

  show(text: string, durationMs: number = 2200): void {
    const id = this.nextId++
    this.items.push({ id, text })
    setTimeout(() => {
      this.items = this.items.filter(i => i.id !== id)
    }, durationMs)
  }
}

export const toastStore: ToastStore = AppStorageV2.connect(ToastStore, 'toastStore', () => new ToastStore())!
export function getToast(): ToastStore { return toastStore }
