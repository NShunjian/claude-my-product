/**
 * 全局 UIAbilityContext 持有。
 * ponytail: EntryAbility.onCreate 里 setCtx(ctx),store 层直接复用,免去 ctx 透传。
 */
import { common } from '@kit.AbilityKit'

let ctx: common.UIAbilityContext | null = null

export function setCtx(c: common.UIAbilityContext): void { ctx = c }
export function getCtx(): common.UIAbilityContext {
  if (!ctx) throw new Error('UIAbilityContext 未初始化')
  return ctx
}
