import { defineConfig } from 'vitest/config'
import dotenv from 'dotenv'

// Load .env before any module evaluates process.env
dotenv.config()

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    globals: false,
    environment: 'node',
  },
})
