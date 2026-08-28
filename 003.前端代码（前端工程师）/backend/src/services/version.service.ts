import { createRequire } from 'node:module'

/**
 * 版本信息服务（最小可工作版）：
 *   - 启动时从 backend/package.json 同步读 version
 *   - 模块顶层缓存，避免每次请求都读盘
 *   - 与前端 package.json 解耦：前端只展示后端权威版本
 *
 * 用 createRequire 而非顶层 `import pkg with {type:'json'}` 是为了
 * 1) 不引入额外 TS 配置项（已经开 resolveJsonModule）
 * 2) ESM 下 `import json` 在 dev (tsx) 和 prod (tsc) 行为差异更小
 */
const require = createRequire(import.meta.url)
type PkgShape = { version?: unknown }
const pkg = require('../../package.json') as PkgShape
const VERSION: string =
  typeof pkg.version === 'string' && pkg.version.length > 0 ? pkg.version : '0.0.0'

/** 返回当前后端部署版本字符串 */
export const getVersion = (): string => VERSION