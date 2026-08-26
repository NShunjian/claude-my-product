import { defineConfig } from 'vitest/config'
import dotenv from 'dotenv'

// Must be set before dotenv.config() so the override wins over .env
process.env.RATE_LIMIT_MAX = '10000'
dotenv.config()

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    globals: false,
    environment: 'node',
  },
})
