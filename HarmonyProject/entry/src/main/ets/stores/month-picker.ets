/**
 * MonthPicker 全局 modal store:由 MonthPicker 触发打开,Index.ets 在全屏
 * Stack(覆盖 tabbar)渲染 mask + 卡片。
 * ponytail: 不用 bindContentCover —— 它绑在 Home 这个 TabContent 内,
 * 渲染范围被 tabbar 截掉。提到 Index 全栈自然覆盖整个屏幕。
 */
import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class MonthPickerStore {
  @Trace show: boolean = false
  @Trace showYearDropdown: boolean = false
  @Trace showYearPicker: boolean = false
  @Trace draftYear: number = new Date().getFullYear()
  @Trace yearPickerValue: number = new Date().getFullYear()
  @Trace initialValue: string = ''
  @Trace pendingValue: string = ''

  private listeners: Array<() => void> = []
  subscribe(fn: () => void): () => void {
    this.listeners.push(fn)
    return () => {
      const i = this.listeners.indexOf(fn)
      if (i >= 0) this.listeners.splice(i, 1)
    }
  }
  private fire(): void {
    for (const fn of this.listeners.slice()) {
      try { fn() } catch { /* 容忍 */ }
    }
  }

  open(currentValue: string): void {
    this.initialValue = currentValue
    this.draftYear = Number(currentValue.split('-')[0]) || new Date().getFullYear()
    this.showYearDropdown = false
    this.show = true
    this.fire()
  }
  close(): void {
    this.show = false
    this.showYearDropdown = false
    this.showYearPicker = false
    this.fire()
  }
  toggleYearDropdown(): void {
    this.showYearDropdown = !this.showYearDropdown
    this.fire()
  }
  setDraftYear(y: number): void {
    this.draftYear = y
    this.showYearDropdown = false
    this.fire()
  }
  // 底部年份选择器(对齐 uniapp picker-view 从底部弹起)
  openYearPicker(): void {
    this.yearPickerValue = this.draftYear
    this.showYearPicker = true
    this.fire()
  }
  closeYearPicker(): void {
    this.showYearPicker = false
    this.fire()
  }
  setYearPickerValue(y: number): void {
    this.yearPickerValue = y
    this.fire()
  }
  confirmYearPicker(): void {
    this.draftYear = this.yearPickerValue
    this.showYearPicker = false
    this.fire()
  }
  emit(newValue: string): void {
    this.pendingValue = newValue
    this.show = false
    this.showYearDropdown = false
    this.showYearPicker = false
    this.fire()
  }
}

export const monthPickerStore: MonthPickerStore = AppStorageV2.connect(MonthPickerStore, 'monthPickerStore', () => new MonthPickerStore())!
export function getMonthPicker(): MonthPickerStore { return monthPickerStore }