/**
 * 统一日志:对齐 uniapp utils/logger.ts 行为,console 输出 → DevEco Logcat。
 * ponytail: 单 domain + tag prefix,按子系统 [Tag] 分桶;emoji + 顶/底分隔线让 Logcat
 *          滚动时一眼能区分请求/响应/错误。
 *
 * 输出形态(Logcat 里):
 *   ╭─ 🔵 [Net] → GET /auth/me ─────────────────────────────────╮
 *   │ body: ""
 *   │ hdr : {"Authorization":"Bearer eyJ..."}
 *   ╰────────────────────────────────────────────────────────────╯
 *
 *   ╭─ 🟢 [Net] ← 200 GET /auth/me (162ms) ─────────────────────╮
 *   │ { ... 响应 data 竖版缩进 ... }
 *   ╰────────────────────────────────────────────────────────────╯
 */
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0x0000
const TAG = 'QingZhang'

type Level = 'debug' | 'info' | 'warn' | 'error'

// ── 等级图标 ────────────────────────────────────────────────
// 用彩色 emoji 让 Logcat 滚动时一眼定级;emoji 在 hilog 里会被原样打印。
class IconBag {
  debug: string = '🔵'
  info: string = '🟢'
  warn: string = '🟠'
  error: string = '🔴'
}
const LEVEL_ICON: IconBag = new IconBag()

// ── 分隔线 ───────────────────────────────────────────────────
// hilog 单行输出宽度大概 80 列较舒服,过长在 Logcat 里会被折成
// 多行反而难看。固定 60 列,窄屏机器也容得下。
const RULE_WIDTH = 60
const TOP = '╭─ '
const MID = ' │ '
const BOT = '╰' + '─'.repeat(RULE_WIDTH - 1)

function pad(s: string, n: number, ch: string = '─'): string {
  if (s.length >= n) return s
  return s + ch.repeat(n - s.length)
}

function safeStr(v: object | string | number | boolean): string {
  if (typeof v === 'string') return v
  try { return JSON.stringify(v, null, 2) } catch { return String(v) }
}

function indent(s: string, prefix: string): string {
  if (s === '') return ''
  return s.split('\n').map((line) => prefix + line).join('\n')
}

function emit(level: Level, tag: string, msg: string, detail: object | string | number | boolean): void {
  const icon: string = level === 'debug' ? LEVEL_ICON.debug
    : level === 'info' ? LEVEL_ICON.info
    : level === 'warn' ? LEVEL_ICON.warn
    : LEVEL_ICON.error
  // 顶部行: ╭─ icon [Tag] msg ────╮
  const head = `${TOP}${icon} [${tag}] ${msg} `
  const headPadded = pad(head + '╮', RULE_WIDTH, '─')

  // 内容行:缩进 2 空格 + │ 前缀,与头部对齐
  const body = indent(safeStr(detail), MID)
  const block = body === ''
    ? headPadded
    : headPadded + '\n' + body + '\n' + BOT

  switch (level) {
    case 'debug': hilog.debug(DOMAIN, TAG, '%{public}s', block); break
    case 'info':  hilog.info(DOMAIN, TAG, '%{public}s', block); break
    case 'warn':  hilog.warn(DOMAIN, TAG, '%{public}s', block); break
    case 'error': hilog.error(DOMAIN, TAG, '%{public}s', block); break
  }
}

export class Logger {
  debug(tag: string, msg: string, detail: object | string | number | boolean = ''): void { emit('debug', tag, msg, detail) }
  info(tag: string, msg: string, detail: object | string | number | boolean = ''): void { emit('info', tag, msg, detail) }
  warn(tag: string, msg: string, detail: object | string | number | boolean = ''): void { emit('warn', tag, msg, detail) }
  error(tag: string, msg: string, detail: object | string | number | boolean = ''): void { emit('error', tag, msg, detail) }
}

export const logger: Logger = new Logger()

export class TagBag {
  NET: string = 'Net'
  AUTH: string = 'Auth'
  STORE: string = 'Store'
  UI: string = 'UI'
  ROUTE: string = 'Route'
  APP: string = 'App'
}

export const TAGS: TagBag = new TagBag()
