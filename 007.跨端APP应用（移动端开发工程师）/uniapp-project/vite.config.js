import { defineConfig, loadEnv } from 'vite'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import uni from '@dcloudio/vite-plugin-uni'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const ROOT_DIR = path.resolve(__dirname, '../..')

// VITE_API_BASE 解析优先级:
//   1. 本项目 .env.local / .env.development   (覆盖优先,本地调试 / staging 用)
//   2. 仓库根 .env 的 LAN_IP + :4001          (默认,改 LAN_IP 一处即可)
//
// 故意忽略 .env.production:HBuilderX 默认 production 编译,但 .env.production 里的
// VITE_API_BASE 经常是占位符(https://your-prod-host),污染默认值。生产真地址应在
// CI/CD 里通过环境变量注入,而不是跟仓库一起提交。
const resolveApiBase = (mode) => {
  const rootEnv = loadEnv(mode, ROOT_DIR, '')
  const projectEnv = loadEnv(mode, __dirname, '')
  if (mode !== 'production' && projectEnv.VITE_API_BASE) return projectEnv.VITE_API_BASE
  const lanIp = rootEnv.LAN_IP || 'localhost'
  return `http://${lanIp}:4001`
}

export default defineConfig(({ mode }) => {
  const apiBase = resolveApiBase(mode)
  return {
    plugins: [uni()],
    server: {
      port: 5181,    // H5 dev server 端口,跟 005 CorsConfig 5181 对齐
      host: '0.0.0.0'// 监听所有接口,手机扫码访问 dev
    },
    define: {
      'import.meta.env.VITE_API_BASE': JSON.stringify(apiBase)
    }
  }
})
