import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [tailwindcss(), react()],
  server: {
    host: true, // 监听所有接口,局域网设备可访问(配 CORS 允许 http://192.168.31.46:5174 后,手机扫码访问本机 dev)
    port: 5174,
    strictPort: true,
  },
})
