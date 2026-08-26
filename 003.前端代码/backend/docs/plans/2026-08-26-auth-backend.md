# 轻账后端登录/注册 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Express.js + TypeScript backend providing `/api/auth/{register,login,me,logout}` for the "轻账" project, backed by the existing MySQL `qingzhang.users` table.

**Architecture:** Layered Express 5 app (routes → controllers → services → utils). MySQL access through `mysql2/promise` connection pool. Passwords hashed with bcrypt; auth tokens are JWT (HS256). All inputs validated with zod schemas. All errors funnel through one middleware.

**Tech Stack:** Node.js 22 LTS, TypeScript 5.6, Express 5, bcrypt 5, jsonwebtoken 9, zod 3, mysql2/promise 3, dotenv 16, helmet, cors, express-rate-limit, vitest, supertest.

**Spec:** [../SPEC.md](../SPEC.md) (design spec).

---

## Global Constraints

Copied verbatim from the spec — every task implicitly inherits these:

- **Runtime:** Node.js ≥ 22 LTS
- **TypeScript strict mode** (`"strict": true` in tsconfig)
- **MySQL:** host=localhost, port=3306, user=root, password=123456, database=qingzhang (matches existing Docker setup)
- **bcrypt cost factor:** 12
- **JWT:** HS256, expires in 7 days, secret must be ≥ 32 bytes
- **Rate limit:** /login and /register: 10 req/min per IP
- **CORS origin:** `http://localhost:5173` only (dev)
- **Username rule:** 2-20 chars, unique (case-sensitive)
- **Password rule:** 6-32 chars
- **Error format:** `{ "error": { "code": "...", "message": "..." } }`
- **No plaintext password logging; no token logging**
- **Source files under:** `003.前端代码（前端工程师）/backend/`
- **Frontend not touched** (Dexie-based V1.0.1 auth stays as-is this iteration)

---

## File Structure

```
backend/
├── package.json                        ← deps & scripts
├── tsconfig.json                       ← strict TS
├── vitest.config.ts                    ← test config
├── .env.example                        ← committed env template
├── .gitignore                          ← ignores node_modules, .env
├── README.md                           ← run instructions
├── docs/
│   ├── SPEC.md                         ← (already written)
│   └── plans/
│       └── 2026-08-26-auth-backend.md  ← this file
└── src/
    ├── index.ts                        ← entry: starts server
    ├── app.ts                          ← Express app factory (testable)
    ├── config/
    │   └── env.ts                      ← env loader + zod validation
    ├── db/
    │   └── pool.ts                     ← MySQL connection pool
    ├── constants/
    │   └── errors.ts                   ← error codes & AppError class
    ├── types/
    │   └── index.ts                    ← User / AuthRequest interfaces
    ├── utils/
    │   ├── hash.ts                     ← bcrypt wrappers
    │   └── jwt.ts                      ← JWT sign/verify
    ├── schemas/
    │   └── auth.schema.ts              ← zod input schemas
    ├── middleware/
    │   ├── auth.ts                     ← JWT verification
    │   ├── error.ts                    ← unified error handler
    │   └── rate-limit.ts               ← login/register limiter
    ├── services/
    │   └── auth.service.ts             ← business logic
    ├── controllers/
    │   └── auth.controller.ts          ← HTTP handlers
    └── routes/
        └── auth.routes.ts              ← /api/auth/* router

tests/
├── env.test.ts
├── pool.test.ts
├── hash.test.ts
├── jwt.test.ts
├── auth.middleware.test.ts
├── auth.service.test.ts
└── auth.routes.test.ts                 ← supertest E2E
```

---

## Task 1: Project Scaffolding

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `vitest.config.ts`
- Create: `.env.example`
- Create: `.gitignore`
- Create: `src/app.ts`
- Create: `src/index.ts`
- Create: `tests/smoke.test.ts`

**Interfaces:** None yet — this task just stands up the toolchain and a "hello world" route used to verify wiring.

- [ ] **Step 1: Write package.json**

```json
{
  "name": "qingzhang-backend",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22" },
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "bcrypt": "^5.1.1",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^5.0.1",
    "express-rate-limit": "^7.4.1",
    "helmet": "^8.0.0",
    "jsonwebtoken": "^9.0.2",
    "mysql2": "^3.11.5",
    "uuid": "^11.0.3",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/bcrypt": "^5.0.2",
    "@types/cors": "^2.8.17",
    "@types/express": "^5.0.0",
    "@types/jsonwebtoken": "^9.0.7",
    "@types/node": "^22.10.0",
    "@types/supertest": "^6.0.2",
    "supertest": "^7.0.0",
    "tsx": "^4.19.2",
    "typescript": "^5.6.3",
    "vitest": "^2.1.8"
  }
}
```

- [ ] **Step 2: Write tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": false,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

- [ ] **Step 3: Write vitest.config.ts**

```ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['tests/**/*.test.ts'],
    globals: false,
    environment: 'node',
  },
})
```

- [ ] **Step 4: Write .env.example**

```env
PORT=4000
NODE_ENV=development

DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=123456
DB_NAME=qingzhang

JWT_SECRET=change-me-to-a-32-byte-random-string-please
JWT_EXPIRES_IN=7d

CORS_ORIGIN=http://localhost:5173
BCRYPT_COST=12
```

- [ ] **Step 5: Write .gitignore**

```
node_modules/
dist/
.env
*.log
.DS_Store
coverage/
```

- [ ] **Step 6: Write src/app.ts**

```ts
import express, { type Application } from 'express'

export const createApp = (): Application => {
  const app = express()
  app.get('/health', (_req, res) => res.json({ ok: true }))
  return app
}
```

- [ ] **Step 7: Write src/index.ts**

```ts
import 'dotenv/config'
import { createApp } from './app.js'

const app = createApp()
const port = Number(process.env.PORT ?? 4000)

app.listen(port, () => {
  console.log(`[qingzhang-backend] listening on http://localhost:${port}`)
})
```

- [ ] **Step 8: Write tests/smoke.test.ts**

```ts
import { describe, it, expect } from 'vitest'
import request from 'supertest'
import { createApp } from '../src/app.js'

describe('health check', () => {
  it('returns ok', async () => {
    const app = createApp()
    const res = await request(app).get('/health')
    expect(res.status).toBe(200)
    expect(res.body).toEqual({ ok: true })
  })
})
```

- [ ] **Step 9: Install dependencies & run smoke test**

Run: `cd "003.前端代码（前端工程师）/backend" && npm install && npm test`
Expected: 1 test passes.

- [ ] **Step 10: Commit**

```bash
git add package.json tsconfig.json vitest.config.ts .env.example .gitignore src/ tests/
git commit -m "chore: scaffold Express + TS backend with healthcheck"
```

---

## Task 2: Environment Configuration (env.ts)

**Files:**
- Create: `src/config/env.ts`
- Create: `tests/env.test.ts`

**Interfaces:**
- Consumes: process.env
- Produces: `env` (frozen object) with keys: PORT, NODE_ENV, DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME, JWT_SECRET, JWT_EXPIRES_IN, CORS_ORIGIN, BCRYPT_COST

- [ ] **Step 1: Write failing test (tests/env.test.ts)**

```ts
import { describe, it, expect, beforeEach } from 'vitest'

describe('env loader', () => {
  beforeEach(() => {
    delete process.env.PORT
    delete process.env.DB_HOST
    delete process.env.JWT_SECRET
  })

  it('throws when JWT_SECRET is missing', async () => {
    await expect(import('../src/config/env.js')).rejects.toThrow(/JWT_SECRET/)
  })

  it('throws when DB_HOST is missing', async () => {
    process.env.JWT_SECRET = 'a'.repeat(32)
    await expect(import('../src/config/env.js?missing=db')).rejects.toThrow(/DB_HOST/)
  })

  it('parses BCRYPT_COST as integer with default 12', async () => {
    process.env.JWT_SECRET = 'a'.repeat(32)
    process.env.DB_HOST = 'localhost'
    const { env } = await import(`../src/config/env.js?ok=${Date.now()}`)
    expect(env.BCRYPT_COST).toBe(12)
    expect(env.PORT).toBe(4000)
    expect(env.JWT_EXPIRES_IN).toBe('7d')
  })
})
```

- [ ] **Step 2: Run tests, expect failure**

Run: `npm test -- env.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write src/config/env.ts**

```ts
import { z } from 'zod'

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(4000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),

  DB_HOST: z.string().min(1),
  DB_PORT: z.coerce.number().int().positive().default(3306),
  DB_USER: z.string().min(1),
  DB_PASSWORD: z.string(),
  DB_NAME: z.string().min(1),

  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 bytes'),
  JWT_EXPIRES_IN: z.string().default('7d'),

  CORS_ORIGIN: z.string().url().default('http://localhost:5173'),
  BCRYPT_COST: z.coerce.number().int().min(4).max(15).default(12),
})

export const env = Object.freeze(envSchema.parse(process.env))
export type Env = typeof env
```

- [ ] **Step 4: Run tests, expect pass**

Run: `npm test -- env.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add src/config/env.ts tests/env.test.ts
git commit -m "feat(config): add zod-validated env loader"
```

---

## Task 3: MySQL Connection Pool

**Files:**
- Create: `src/db/pool.ts`
- Create: `tests/pool.test.ts`

**Interfaces:**
- Consumes: `env` from `src/config/env.ts`
- Produces: `pool` (mysql2/promise Pool)

- [ ] **Step 1: Write failing test**

```ts
import { describe, it, expect } from 'vitest'
import { getPool, closePool } from '../src/db/pool.js'

describe('MySQL pool', () => {
  it('returns a working pool', async () => {
    const pool = getPool()
    const [rows] = await pool.query('SELECT 1 AS one')
    expect((rows as any)[0].one).toBe(1)
    await closePool()
  })

  it('returns the same singleton across calls', () => {
    const a = getPool()
    const b = getPool()
    expect(a).toBe(b)
  })
})
```

- [ ] **Step 2: Run tests, expect failure**

Run: `npm test -- pool.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write src/db/pool.ts**

```ts
import mysql from 'mysql2/promise'
import { env } from '../config/env.js'

let pool: mysql.Pool | undefined

export const getPool = (): mysql.Pool => {
  if (!pool) {
    pool = mysql.createPool({
      host: env.DB_HOST,
      port: env.DB_PORT,
      user: env.DB_USER,
      password: env.DB_PASSWORD,
      database: env.DB_NAME,
      waitForConnections: true,
      connectionLimit: 10,
      charset: 'utf8mb4_unicode_ci',
      dateStrings: false,
      supportBigNumbers: true,
      bigNumberStrings: false,
    })
  }
  return pool
}

export const closePool = async (): Promise<void> => {
  if (pool) {
    await pool.end()
    pool = undefined
  }
}
```

- [ ] **Step 4: Run tests, expect pass**

Run: `npm test -- pool.test.ts`
Expected: PASS. (Requires `cp .env.example .env` and a running MySQL with the `qingzhang` DB.)

- [ ] **Step 5: Commit**

```bash
git add src/db/pool.ts tests/pool.test.ts
git commit -m "feat(db): add mysql2/promise singleton pool"
```

---

## Task 4: Types & Error Constants

**Files:**
- Create: `src/types/index.ts`
- Create: `src/constants/errors.ts`
- Create: `tests/errors.test.ts`

**Interfaces:**
- `User`: id (number), uuid, username, displayName|null, createdAt (string)
- `JwtPayload`: sub (number), uuid, username
- `AuthRequest`: extends Express Request with `user?: JwtPayload`
- `AppError`: custom error with `status`, `code`, `message`

- [ ] **Step 1: Write failing test (tests/errors.test.ts)**

```ts
import { describe, it, expect } from 'vitest'
import { AppError, ErrorCode } from '../src/constants/errors.js'

describe('AppError', () => {
  it('carries status, code, and message', () => {
    const e = new AppError(401, ErrorCode.INVALID_CREDENTIALS, '用户名或密码错误')
    expect(e).toBeInstanceOf(Error)
    expect(e.status).toBe(401)
    expect(e.code).toBe('INVALID_CREDENTIALS')
    expect(e.message).toBe('用户名或密码错误')
  })
})
```

- [ ] **Step 2: Run, expect fail**

Run: `npm test -- errors.test.ts`
Expected: FAIL.

- [ ] **Step 3: Write src/constants/errors.ts**

```ts
export enum ErrorCode {
  INVALID_INPUT = 'INVALID_INPUT',
  USERNAME_TAKEN = 'USERNAME_TAKEN',
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  MISSING_TOKEN = 'MISSING_TOKEN',
  INVALID_TOKEN = 'INVALID_TOKEN',
  USER_NOT_FOUND = 'USER_NOT_FOUND',
  RATE_LIMIT = 'RATE_LIMIT',
  INTERNAL = 'INTERNAL',
}

export class AppError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: ErrorCode,
    message: string,
  ) {
    super(message)
    this.name = 'AppError'
  }
}
```

- [ ] **Step 4: Write src/types/index.ts**

```ts
export interface User {
  id: number
  uuid: string
  username: string
  displayName: string | null
  createdAt: string
}

export interface JwtPayload {
  sub: number
  uuid: string
  username: string
}
```

- [ ] **Step 5: Run, expect pass**

Run: `npm test -- errors.test.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/types/index.ts src/constants/errors.ts tests/errors.test.ts
git commit -m "feat(types): add User/JwtPayload + AppError"
```

---

## Task 5: bcrypt Hash Utility (TDD)

**Files:**
- Create: `src/utils/hash.ts`
- Create: `tests/hash.test.ts`

**Interfaces:**
- `hashPassword(plain: string): Promise<string>`
- `verifyPassword(plain: string, hash: string): Promise<boolean>`

- [ ] **Step 1: Write failing test**

```ts
import { describe, it, expect } from 'vitest'
import { hashPassword, verifyPassword } from '../src/utils/hash.js'

describe('hash utils', () => {
  it('hashes and verifies the same password', async () => {
    const hash = await hashPassword('hello-world-123')
    expect(hash).not.toBe('hello-world-123')
    expect(hash.length).toBeGreaterThan(40)
    expect(await verifyPassword('hello-world-123', hash)).toBe(true)
  })

  it('rejects wrong password', async () => {
    const hash = await hashPassword('correct-horse')
    expect(await verifyPassword('wrong-horse', hash)).toBe(false)
  })
})
```

- [ ] **Step 2: Run, expect fail**

Run: `npm test -- hash.test.ts`
Expected: FAIL.

- [ ] **Step 3: Write src/utils/hash.ts**

```ts
import bcrypt from 'bcrypt'
import { env } from '../config/env.js'

export const hashPassword = (plain: string): Promise<string> =>
  bcrypt.hash(plain, env.BCRYPT_COST)

export const verifyPassword = (plain: string, hash: string): Promise<boolean> =>
  bcrypt.compare(plain, hash)
```

- [ ] **Step 4: Run, expect pass**

Run: `npm test -- hash.test.ts`
Expected: PASS (2 tests, ~500ms each).

- [ ] **Step 5: Commit**

```bash
git add src/utils/hash.ts tests/hash.test.ts
git commit -m "feat(utils): add bcrypt hash/verify wrappers"
```

---

## Task 6: JWT Utility (TDD)

**Files:**
- Create: `src/utils/jwt.ts`
- Create: `tests/jwt.test.ts`

**Interfaces:**
- `signToken(payload: JwtPayload): string`
- `verifyToken(token: string): JwtPayload`

- [ ] **Step 1: Write failing test**

```ts
import { describe, it, expect } from 'vitest'
import { signToken, verifyToken } from '../src/utils/jwt.js'
import type { JwtPayload } from '../src/types/index.js'

describe('jwt utils', () => {
  const payload: JwtPayload = { sub: 1, uuid: 'u-1', username: 'alice' }

  it('signs and verifies', () => {
    const token = signToken(payload)
    expect(typeof token).toBe('string')
    expect(verifyToken(token)).toMatchObject(payload)
  })

  it('throws on bad token', () => {
    expect(() => verifyToken('not-a-real-token')).toThrow()
  })
})
```

- [ ] **Step 2: Run, expect fail**

Run: `npm test -- jwt.test.ts`
Expected: FAIL.

- [ ] **Step 3: Write src/utils/jwt.ts**

```ts
import jwt from 'jsonwebtoken'
import { env } from '../config/env.js'
import type { JwtPayload } from '../types/index.js'

export const signToken = (payload: JwtPayload): string =>
  jwt.sign(payload, env.JWT_SECRET, {
    algorithm: 'HS256',
    expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'],
  })

export const verifyToken = (token: string): JwtPayload => {
  const decoded = jwt.verify(token, env.JWT_SECRET, { algorithms: ['HS256'] })
  if (typeof decoded === 'string') {
    throw new Error('Invalid token payload')
  }
  return {
    sub: Number(decoded.sub),
    uuid: String((decoded as Record<string, unknown>).uuid),
    username: String((decoded as Record<string, unknown>).username),
  }
}
```

- [ ] **Step 4: Run, expect pass**

Run: `npm test -- jwt.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/utils/jwt.ts tests/jwt.test.ts
git commit -m "feat(utils): add JWT sign/verify"
```

---

## Task 7: Zod Auth Schemas

**Files:**
- Create: `src/schemas/auth.schema.ts`

**Interfaces:**
- `registerSchema`: `{ username: 2-20 chars, password: 6-32 chars }`
- `loginSchema`: `{ username: ≥1 char, password: ≥1 char }`
- Type helpers: `RegisterInput`, `LoginInput`

- [ ] **Step 1: Write src/schemas/auth.schema.ts**

```ts
import { z } from 'zod'

const usernameRule = z
  .string()
  .trim()
  .min(2, '用户名至少 2 个字符')
  .max(20, '用户名最多 20 个字符')
  .regex(/^[A-Za-z0-9_一-龥]+$/, '用户名仅限字母/数字/中文/下划线')

const passwordRule = z
  .string()
  .min(6, '密码至少 6 位')
  .max(32, '密码最多 32 位')

export const registerSchema = z.object({
  username: usernameRule,
  password: passwordRule,
})

export const loginSchema = z.object({
  username: z.string().trim().min(1, '用户名不能为空'),
  password: z.string().min(1, '密码不能为空'),
})

export type RegisterInput = z.infer<typeof registerSchema>
export type LoginInput = z.infer<typeof loginSchema>
```

- [ ] **Step 2: Commit**

```bash
git add src/schemas/auth.schema.ts
git commit -m "feat(schemas): add register/login zod schemas"
```

---

## Task 8: Error Middleware

**Files:**
- Create: `src/middleware/error.ts`
- Create: `src/middleware/not-found.ts`

**Interfaces:**
- `errorHandler(err, req, res, next)` — converts `AppError`, `ZodError`, and unknown errors into the unified `{ error: { code, message } }` response.
- `notFoundHandler(req, res)` — 404 fallback.

- [ ] **Step 1: Write src/middleware/not-found.ts**

```ts
import type { Request, Response } from 'express'
import { AppError, ErrorCode } from '../constants/errors.js'

export const notFoundHandler = (_req: Request, _res: Response, next: (e?: unknown) => void) => {
  next(new AppError(404, ErrorCode.INTERNAL, '路由不存在'))
}
```

- [ ] **Step 2: Write src/middleware/error.ts**

```ts
import type { ErrorRequestHandler } from 'express'
import { ZodError } from 'zod'
import { AppError, ErrorCode } from '../constants/errors.js'

export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  // zod 校验失败
  if (err instanceof ZodError) {
    res.status(400).json({
      error: {
        code: ErrorCode.INVALID_INPUT,
        message: err.issues[0]?.message ?? '参数校验失败',
      },
    })
    return
  }

  // 自定义业务错误
  if (err instanceof AppError) {
    res.status(err.status).json({ error: { code: err.code, message: err.message } })
    return
  }

  // 兜底
  console.error('[unhandled error]', err)
  res.status(500).json({
    error: { code: ErrorCode.INTERNAL, message: '服务器内部错误' },
  })
}
```

- [ ] **Step 3: Commit**

```bash
git add src/middleware/error.ts src/middleware/not-found.ts
git commit -m "feat(middleware): add unified error handler + 404"
```

---

## Task 9: Auth Middleware (JWT verify)

**Files:**
- Create: `src/middleware/auth.ts`
- Create: `tests/auth.middleware.test.ts`

**Interfaces:**
- `requireAuth(req, res, next)` — reads `Authorization: Bearer <token>`, verifies it, attaches `req.user = JwtPayload`. On failure calls `next(AppError)`.

- [ ] **Step 1: Write failing test**

```ts
import { describe, it, expect, beforeAll } from 'vitest'
import express from 'express'
import request from 'supertest'
import { signToken } from '../src/utils/jwt.js'
import { requireAuth } from '../src/middleware/auth.js'
import { errorHandler } from '../src/middleware/error.js'

const buildApp = () => {
  const app = express()
  app.get('/protected', requireAuth, (req, res) => res.json({ user: req.user }))
  app.use(errorHandler)
  return app
}

describe('requireAuth middleware', () => {
  it('returns 401 when no Authorization header', async () => {
    const res = await request(buildApp()).get('/protected')
    expect(res.status).toBe(401)
    expect(res.body.error.code).toBe('MISSING_TOKEN')
  })

  it('returns 401 for bad token', async () => {
    const res = await request(buildApp()).get('/protected').set('Authorization', 'Bearer not-a-token')
    expect(res.status).toBe(401)
    expect(res.body.error.code).toBe('INVALID_TOKEN')
  })

  it('attaches user on valid token', async () => {
    const token = signToken({ sub: 42, uuid: 'u', username: 'alice' })
    const res = await request(buildApp()).get('/protected').set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(200)
    expect(res.body.user).toMatchObject({ sub: 42, username: 'alice' })
  })
})
```

- [ ] **Step 2: Run, expect fail**

Run: `npm test -- auth.middleware.test.ts`
Expected: FAIL.

- [ ] **Step 3: Write src/middleware/auth.ts**

```ts
import type { Request, RequestHandler } from 'express'
import { AppError, ErrorCode } from '../constants/errors.js'
import { verifyToken } from '../utils/jwt.js'
import type { JwtPayload } from '../types/index.js'

export const requireAuth: RequestHandler = (req, _res, next) => {
  const header = req.header('authorization')
  if (!header || !header.startsWith('Bearer ')) {
    return next(new AppError(401, ErrorCode.MISSING_TOKEN, '未登录或登录已过期'))
  }
  const token = header.slice('Bearer '.length).trim()
  try {
    const payload: JwtPayload = verifyToken(token)
    ;(req as Request & { user?: JwtPayload }).user = payload
    next()
  } catch {
    next(new AppError(401, ErrorCode.INVALID_TOKEN, 'token 无效或已过期'))
  }
}
```

- [ ] **Step 4: Run, expect pass**

Run: `npm test -- auth.middleware.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add src/middleware/auth.ts tests/auth.middleware.test.ts
git commit -m "feat(middleware): add JWT requireAuth"
```

---

## Task 10: Auth Service (TDD)

**Files:**
- Create: `src/services/auth.service.ts`
- Create: `tests/auth.service.test.ts`

**Interfaces:**
- `register(input: RegisterInput): Promise<{ user: User; token: string }>`
- `login(input: LoginInput): Promise<{ user: User; token: string }>`
- `getCurrentUser(uuid: string): Promise<User>`

- [ ] **Step 1: Write failing test**

```ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { v4 as uuid } from 'uuid'
import { register, login, getCurrentUser } from '../src/services/auth.service.js'
import { getPool, closePool } from '../src/db/pool.js'

const USERNAME = `svc_test_${uuid().slice(0, 8)}`
const PASSWORD = 'test-pass-123'

describe('auth service', () => {
  afterAll(async () => {
    // cleanup
    await getPool().query('DELETE FROM users WHERE username = ?', [USERNAME])
    await closePool()
  })

  it('register creates a user and returns token', async () => {
    const { user, token } = await register({ username: USERNAME, password: PASSWORD })
    expect(user.username).toBe(USERNAME)
    expect(user.id).toBeGreaterThan(0)
    expect(token).toMatch(/^eyJ/)
  })

  it('login with correct password succeeds', async () => {
    const { user } = await login({ username: USERNAME, password: PASSWORD })
    expect(user.username).toBe(USERNAME)
  })

  it('login with wrong password throws INVALID_CREDENTIALS', async () => {
    await expect(login({ username: USERNAME, password: 'wrong-pw-1' })).rejects.toMatchObject({
      status: 401,
      code: 'INVALID_CREDENTIALS',
    })
  })

  it('login with unknown user throws INVALID_CREDENTIALS', async () => {
    await expect(login({ username: 'no-s-huch-user', password: 'whatever' })).rejects.toMatchObject({
      status: 401,
      code: 'INVALID_CREDENTIALS',
    })
  })

  it('register with existing username throws USERNAME_TAKEN', async () => {
    await expect(register({ username: USERNAME, password: PASSWORD })).rejects.toMatchObject({
      status: 409,
      code: 'USERNAME_TAKEN',
    })
  })

  it('getCurrentUser returns the user by uuid', async () => {
    const { user } = await login({ username: USERNAME, password: PASSWORD })
    const fetched = await getCurrentUser(user.uuid)
    expect(fetched.username).toBe(USERNAME)
  })
})
```

- [ ] **Step 2: Run, expect fail**

Run: `npm test -- auth.service.test.ts`
Expected: FAIL.

- [ ] **Step 3: Write src/services/auth.service.ts**

```ts
import { v4 as uuidv4 } from 'uuid'
import type { ResultSetHeader, RowDataPacket } from 'mysql2'
import { getPool } from '../db/pool.js'
import { hashPassword, verifyPassword } from '../utils/hash.js'
import { signToken } from '../utils/jwt.js'
import { AppError, ErrorCode } from '../constants/errors.js'
import type { User, JwtPayload } from '../types/index.js'
import type { RegisterInput, LoginInput } from '../schemas/auth.schema.js'

interface UserRow extends RowDataPacket {
  id: number
  uuid: string
  username: string
  display_name: string | null
  created_at: Date
}

const toUser = (row: UserRow): User => ({
  id: Number(row.id),
  uuid: row.uuid,
  username: row.username,
  displayName: row.display_name,
  createdAt: new Date(row.created_at).toISOString(),
})

const issueToken = (row: UserRow): string =>
  signToken({ sub: Number(row.id), uuid: row.uuid, username: row.username } satisfies JwtPayload)

export const register = async (input: RegisterInput): Promise<{ user: User; token: string }> => {
  const pool = getPool()
  const [existing] = await pool.query<UserRow[]>(
    'SELECT id FROM users WHERE username = ? LIMIT 1',
    [input.username],
  )
  if (existing.length > 0) {
    throw new AppError(409, ErrorCode.USERNAME_TAKEN, '该用户名已被注册')
  }

  const hash = await hashPassword(input.password)
  const uuid = uuidv4()
  const [result] = await pool.query<ResultSetHeader>(
    'INSERT INTO users (uuid, username, password_hash, salt, status) VALUES (?, ?, ?, ?, 1)',
    [uuid, input.username, hash, 'bcrypt'],
  )
  const insertId = Number(result.insertId)

  // 回读完整行（保证 created_at 等由 DB 默认值填的字段拿到）
  const [rows] = await pool.query<UserRow[]>(
    'SELECT id, uuid, username, display_name, created_at FROM users WHERE id = ?',
    [insertId],
  )
  const row = rows[0]
  return { user: toUser(row), token: issueToken(row) }
}

export const login = async (input: LoginInput): Promise<{ user: User; token: string }> => {
  const pool = getPool()
  const [rows] = await pool.query<UserRow[]>(
    'SELECT id, uuid, username, password_hash, display_name, created_at FROM users WHERE username = ? LIMIT 1',
    [input.username],
  )
  const row = rows[0]
  if (!row) {
    throw new AppError(401, ErrorCode.INVALID_CREDENTIALS, '用户名或密码错误')
  }
  const ok = await verifyPassword(input.password, row.password_hash)
  if (!ok) {
    throw new AppError(401, ErrorCode.INVALID_CREDENTIALS, '用户名或密码错误')
  }
  // 更新最后登录时间
  await pool.query('UPDATE users SET last_login_at = CURRENT_TIMESTAMP(3) WHERE id = ?', [row.id])
  return { user: toUser(row), token: issueToken(row) }
}

export const getCurrentUser = async (uuid: string): Promise<User> => {
  const pool = getPool()
  const [rows] = await pool.query<UserRow[]>(
    'SELECT id, uuid, username, display_name, created_at FROM users WHERE uuid = ? LIMIT 1',
    [uuid],
  )
  const row = rows[0]
  if (!row) {
    throw new AppError(404, ErrorCode.USER_NOT_FOUND, '用户不存在')
  }
  return toUser(row)
}
```

- [ ] **Step 4: Run, expect pass**

Run: `npm test -- auth.service.test.ts`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add src/services/auth.service.ts tests/auth.service.test.ts
git commit -m "feat(service): add auth register/login/getCurrentUser"
```

---

## Task 11: Auth Controller & Routes

**Files:**
- Create: `src/controllers/auth.controller.ts`
- Create: `src/routes/auth.routes.ts`

**Interfaces:**
- `authController.register(req, res, next)` — wraps service.register
- `authController.login(req, res, next)`
- `authController.me(req, res, next)`
- `authController.logout(req, res)` — stateless ack
- Router exposes: `POST /register`, `POST /login`, `GET /me`, `POST /logout`

- [ ] **Step 1: Write src/controllers/auth.controller.ts**

```ts
import type { Request, Response, NextFunction } from 'express'
import * as authService from '../services/auth.service.js'
import type { LoginInput, RegisterInput } from '../schemas/auth.schema.js'

export const register = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = req.body as RegisterInput
    const result = await authService.register(input)
    res.status(201).json(result)
  } catch (e) {
    next(e)
  }
}

export const login = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = req.body as LoginInput
    const result = await authService.login(input)
    res.json(result)
  } catch (e) {
    next(e)
  }
}

export const me = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = req.user!
    const fresh = await authService.getCurrentUser(user.uuid)
    res.json({ user: fresh })
  } catch (e) {
    next(e)
  }
}

export const logout = (_req: Request, res: Response) => {
  res.json({ ok: true })
}
```

- [ ] **Step 2: Write src/routes/auth.routes.ts**

```ts
import { Router } from 'express'
import * as controller from '../controllers/auth.controller.js'
import { requireAuth } from '../middleware/auth.js'
import { authLimiter } from '../middleware/rate-limit.js'

export const authRouter = Router()

authRouter.post('/register', authLimiter, controller.register)
authRouter.post('/login',    authLimiter, controller.login)
authRouter.get('/me',        requireAuth,  controller.me)
authRouter.post('/logout',   requireAuth,  controller.logout)
```

- [ ] **Step 3: Commit**

```bash
git add src/controllers/auth.controller.ts src/routes/auth.routes.ts
git commit -m "feat(http): add auth controller + routes (limiter to be wired)"
```

---

## Task 12: Rate Limit Middleware

**Files:**
- Create: `src/middleware/rate-limit.ts`

- [ ] **Step 1: Write src/middleware/rate-limit.ts**

```ts
import rateLimit from 'express-rate-limit'
import { AppError, ErrorCode } from '../constants/errors.js'

export const authLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10,             // 10 requests per IP per minute
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req, _res, next) => {
    next(new AppError(429, ErrorCode.RATE_LIMIT, '请求过于频繁，请稍后再试'))
  },
})
```

- [ ] **Step 2: Commit**

```bash
git add src/middleware/rate-limit.ts
git commit -m "feat(middleware): add login/register rate limiter"
```

---

## Task 13: App Factory & Entry Point

**Files:**
- Modify: `src/app.ts`
- Modify: `src/index.ts`

**Interfaces:**
- `createApp()` returns a fully wired Express app with: helmet, cors, json parser, /health, /api/auth, errorHandler, notFoundHandler.

- [ ] **Step 1: Replace src/app.ts**

```ts
import express, { type Application } from 'express'
import helmet from 'helmet'
import cors from 'cors'
import { env } from './config/env.js'
import { authRouter } from './routes/auth.routes.js'
import { errorHandler } from './middleware/error.js'
import { notFoundHandler } from './middleware/not-found.js'

export const createApp = (): Application => {
  const app = express()
  app.use(helmet())
  app.use(cors({ origin: env.CORS_ORIGIN, credentials: true }))
  app.use(express.json({ limit: '64kb' }))

  app.get('/health', (_req, res) => res.json({ ok: true }))
  app.use('/api/auth', authRouter)

  app.use(notFoundHandler)
  app.use(errorHandler)
  return app
}
```

- [ ] **Step 2: Replace src/index.ts**

```ts
import { createApp } from './app.js'
import { env } from './config/env.js'
import { closePool } from './db/pool.js'

const app = createApp()
const server = app.listen(env.PORT, () => {
  console.log(`[qingzhang-backend] listening on http://localhost:${env.PORT}`)
  console.log(`[qingzhang-backend] env=${env.NODE_ENV} db=${env.DB_NAME}`)
})

const shutdown = async (signal: string) => {
  console.log(`\n[qingzhang-backend] received ${signal}, closing...`)
  server.close(async () => {
    await closePool()
    process.exit(0)
  })
}

process.on('SIGINT', () => void shutdown('SIGINT'))
process.on('SIGTERM', () => void shutdown('SIGTERM'))
```

- [ ] **Step 3: Commit**

```bash
git add src/app.ts src/index.ts
git commit -m "feat(app): wire middleware, router, error handling, graceful shutdown"
```

---

## Task 14: End-to-End Test (supertest)

**Files:**
- Create: `tests/auth.routes.test.ts`

**Interfaces:** Exercises full HTTP stack against the real MySQL DB.

- [ ] **Step 1: Write tests/auth.routes.test.ts**

```ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { v4 as uuid } from 'uuid'
import request from 'supertest'
import { createApp } from '../src/app.js'
import { getPool, closePool } from '../src/db/pool.js'

const USERNAME = `e2e_${uuid().slice(0, 8)}`
const PASSWORD = 'e2e-pass-123'

describe('POST /api/auth/* (E2E)', () => {
  const app = createApp()

  afterAll(async () => {
    await getPool().query('DELETE FROM users WHERE username = ?', [USERNAME])
    await closePool()
  })

  it('rejects invalid register input', async () => {
    const res = await request(app).post('/api/auth/register').send({ username: 'a', password: '1' })
    expect(res.status).toBe(400)
    expect(res.body.error.code).toBe('INVALID_INPUT')
  })

  it('registers a new user', async () => {
    const res = await request(app).post('/api/auth/register').send({ username: USERNAME, password: PASSWORD })
    expect(res.status).toBe(201)
    expect(res.body.user.username).toBe(USERNAME)
    expect(res.body.token).toMatch(/^eyJ/)
  })

  it('rejects duplicate username', async () => {
    const res = await request(app).post('/api/auth/register').send({ username: USERNAME, password: PASSWORD })
    expect(res.status).toBe(409)
    expect(res.body.error.code).toBe('USERNAME_TAKEN')
  })

  it('logs in with correct credentials', async () => {
    const res = await request(app).post('/api/auth/login').send({ username: USERNAME, password: PASSWORD })
    expect(res.status).toBe(200)
    expect(res.body.token).toBeDefined()
  })

  it('rejects wrong password with INVALID_CREDENTIALS', async () => {
    const res = await request(app).post('/api/auth/login').send({ username: USERNAME, password: 'wrong-pass' })
    expect(res.status).toBe(401)
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS')
  })

  it('GET /me requires token', async () => {
    const res = await request(app).get('/api/auth/me')
    expect(res.status).toBe(401)
  })

  it('GET /me with token returns user', async () => {
    const loginRes = await request(app).post('/api/auth/login').send({ username: USERNAME, password: PASSWORD })
    const token = loginRes.body.token as string
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`)
    expect(me.status).toBe(200)
    expect(me.body.user.username).toBe(USERNAME)
  })

  it('POST /logout acks', async () => {
    const loginRes = await request(app).post('/api/auth/login').send({ username: USERNAME, password: PASSWORD })
    const res = await request(app).post('/api/auth/logout').set('Authorization', `Bearer ${loginRes.body.token}`)
    expect(res.status).toBe(200)
    expect(res.body.ok).toBe(true)
  })
})
```

- [ ] **Step 2: Run all tests**

Run: `npm test`
Expected: All tests pass (smoke + env + pool + errors + hash + jwt + middleware + service + e2e ≈ 25+ tests).

- [ ] **Step 3: Commit**

```bash
git add tests/auth.routes.test.ts
git commit -m "test(e2e): supertest full auth flow against MySQL"
```

---

## Task 15: README & Live Verification

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README.md**

```markdown
# 轻账 (QingZhang) Backend

Express 5 + TypeScript backend providing authentication APIs for the "轻账" frontend.

## Requirements
- Node.js ≥ 22
- MySQL 9.x running on `localhost:3306` with database `qingzhang` (see [../../004.数据库脚本/](../../004.数据库脚本/))

## Quick Start
\`\`\`bash
cp .env.example .env
# edit JWT_SECRET to a 32+ byte random string
npm install
npm run dev
\`\`\`
Server starts on `http://localhost:4000`.

## Scripts
| command | purpose |
|---------|---------|
| `npm run dev` | tsx watch mode |
| `npm run build` | compile TS to dist/ |
| `npm start` | run compiled JS |
| `npm test` | vitest run (single) |
| `npm run test:watch` | vitest watch |

## API
| method | path | auth | body | response |
|--------|------|------|------|----------|
| POST | /api/auth/register | — | `{username, password}` | `201 {token, user}` |
| POST | /api/auth/login    | — | `{username, password}` | `200 {token, user}` |
| GET  | /api/auth/me       | Bearer | — | `200 {user}` |
| POST | /api/auth/logout  | Bearer | — | `200 {ok:true}` |

## Manual curl test
\`\`\`bash
# register
curl -X POST http://localhost:4000/api/auth/register \\
  -H 'Content-Type: application/json' \\
  -d '{"username":"alice","password":"secret123"}'

# login
TOKEN=$(curl -s -X POST http://localhost:4000/api/auth/login \\
  -H 'Content-Type: application/json' \\
  -d '{"username":"alice","password":"secret123"}' | jq -r .token)

# me
curl http://localhost:4000/api/auth/me -H "Authorization: Bearer $TOKEN"
\`\`\`

## Error format
All errors return:
\`\`\`json
{ "error": { "code": "INVALID_INPUT", "message": "用户名至少 2 个字符" } }
\`\`\`

## Architecture
```
src/
├── config/env.ts        zod-validated env
├── db/pool.ts           mysql2 singleton
├── middleware/          auth, error, rate-limit
├── routes/              auth router
├── controllers/         HTTP handlers
├── services/            business logic
├── schemas/             zod input schemas
├── utils/               hash, jwt
├── types/               shared interfaces
├── constants/errors.ts  AppError + ErrorCode enum
├── app.ts               Express factory (testable)
└── index.ts             entry: listen + graceful shutdown
```

See [../SPEC.md](../SPEC.md) for the full design spec.
```

- [ ] **Step 2: Live verification**

Run in two terminals:
```bash
# terminal 1
npm run dev

# terminal 2 (in project root)
curl -X POST http://localhost:4000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"smoketest","password":"smoke123"}'
```
Expected: `201 { token, user }`

Then:
```bash
TOKEN=$(curl -s -X POST http://localhost:4000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"smoketest","password":"smoke123"}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["token"])')

curl http://localhost:4000/api/auth/me -H "Authorization: Bearer $TOKEN"
```
Expected: `200 { user: { username: "smoketest", ... } }`

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add backend README with quickstart and API"
```

---

## Self-Review

### Spec coverage

| Spec section | Implemented in task |
| | |
| §四.1 POST /register | 10, 11, 14 |
| §四.2 POST /login | 10, 11, 14 |
| §四.3 GET /me | 9, 11, 14 |
| §四.4 POST /logout | 11, 14 |
| §五 数据流 | 10 (register), 11 (controller wiring) |
| §六 数据模型 (复用 users 表) | 10 (UserRow) |
| §七 安全 (bcrypt, JWT, 限流, helmet, CORS) | 5, 6, 12, 13 |
| §八 错误处理 (统一格式) | 4, 8, 13 |
| §九 .env.example | 1 |
| §十 测试策略 (unit + integration + E2E) | 5, 6, 9, 10, 14 |

### Placeholder scan
No "TBD" / "TODO" / "fill in" markers in the plan.

### Type consistency
- `User` defined in Task 4, used in Tasks 10, 11, 14. Same fields (`id, username, displayName|null, createdAt`).
- `JwtPayload` defined in Task 4, used in Tasks 6, 9, 10.
- `AppError`/`ErrorCode` defined in Task 4, used in Tasks 8, 9, 10, 11, 12.
- `RegisterInput`/`LoginInput` defined in Task 7, used in Tasks 10, 11.

All types flow consistently.

### Scope check
Single subsystem (auth API), no decomposition needed.

### Ambiguity check
- `password_hash` length: bcrypt = 60 chars; schema has `VARCHAR(255)` — safe.
- `salt` column: kept but unused by bcrypt (filled with literal `'bcrypt'`); non-breaking.
- Rate limit scope: per-IP (express-rate-limit default); no auth behind proxy → out of scope.

---

## Execution Handoff

Plan complete and saved to `003.前端代码（前端工程师）/backend/docs/plans/2026-08-26-auth-backend.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?