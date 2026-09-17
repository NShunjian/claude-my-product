/**
 * 全局 modal-open 状态:与 uniapp utils/modal-state.ts 1:1。
 * ponytail: HarmonyOS 下用作 bottom sheet mask 控制。
 */
import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class ModalState {
  @Trace open: boolean = false
}

export const modalState: ModalState = AppStorageV2.connect(ModalState, 'modalState', () => new ModalState())!
