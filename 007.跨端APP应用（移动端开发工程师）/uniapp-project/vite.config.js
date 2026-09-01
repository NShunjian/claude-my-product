import { defineConfig } from 'vite'
import uni from '@dcloudio/vite-plugin-uni'

export default defineConfig({
  plugins: [uni()],
  server: {
    port: 5181,    // 改成你想要的端口，例如 4001
    host: '0.0.0.0'// 开启局域网访问，手机可以调试
  }
})
