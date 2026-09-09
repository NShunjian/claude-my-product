import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig, loadEnv } from 'vite'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const ROOT_DIR = path.resolve(__dirname, '../..')

// VITE_API_BASE 解析优先级:
//   1. 本项目 .env.local / .env.[mode]   (覆盖优先,留给特殊场景)
//   2. 仓库根 .env 的 LAN_IP + :4001     (默认,改 LAN_IP 一处即可)
const resolveApiBase = (mode: string) => {
  const rootEnv = loadEnv(mode, ROOT_DIR, '')
  const projectEnv = loadEnv(mode, __dirname, '')
  if (projectEnv.VITE_API_BASE) return projectEnv.VITE_API_BASE
  const lanIp = rootEnv.LAN_IP || 'localhost'
  return `http://${lanIp}:4001`
}

export default defineConfig(({ mode }) => {
  const apiBase = resolveApiBase(mode)
  return {
    plugins: [tailwindcss(), react()],
    server: {
      host: true, // 监听所有接口,局域网设备可访问
      port: 5173,
      strictPort: true,
    },
    define: {
      'import.meta.env.VITE_API_BASE': JSON.stringify(apiBase)
    }
  }
})
