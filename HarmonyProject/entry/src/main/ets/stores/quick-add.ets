/**
 * QuickAdd 全局 modal:对齐 uniapp stores/quick-add.ts 1:1。
 */
import { AppStorageV2 } from '@kit.ArkUI'

export type QuickAddKind = 'expense' | 'income'

@ObservedV2
export class QuickAddStore {
  @Trace show: boolean = false
  @Trace kind: QuickAddKind = 'expense'
  @Trace savedAt: number = 0

  open(kind: QuickAddKind = 'expense'): void { this.kind = kind; this.show = true }
  close(): void { this.show = false }
  notifySaved(): void { this.savedAt = Date.now(); this.show = false }
}

export const quickAddStore: QuickAddStore = AppStorageV2.connect(QuickAddStore, 'quickAddStore', () => new QuickAddStore())!
export function getQuickAdd(): QuickAddStore { return quickAddStore }
