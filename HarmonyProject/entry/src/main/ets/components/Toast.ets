/**
 * Toast 宿主:对齐 uniapp components/Toast.vue 1:1。
 */
import { toastStore } from '../stores/toast'
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'
import type { ToastItem } from '../model/Types'

@Component
export struct ToastHost {
  build() {
    Stack() {
      ForEach(toastStore.items, (item: ToastItem) => {
        Row() {
          Text(item.text)
            .fontSize(14)
            .fontColor(Color.White)
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .backgroundColor('#000000CC')
            .borderRadius(20)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .position({ x: 0, y: 0 })
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ top: 80 })
      }, (item: ToastItem) => `${item.id}`)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }
}
