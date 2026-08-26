# 轻账 (QingZhang) Backend

Express 5 + TypeScript backend providing authentication APIs for the "轻账" frontend.

## Requirements
- Node.js >= 22
- MySQL 9.x running on `localhost:3306` with database `qingzhang` (see [../../004.数据库脚本/](../../004.数据库脚本/))

## Quick Start
```bash
cp .env.example .env
# edit JWT_SECRET to a 32+ byte random string
npm install
npm run dev
```
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
| POST | /api/auth/register | -- | `{username, password}` | `201 {token, user}` |
| POST | /api/auth/login    | -- | `{username, password}` | `200 {token, user}` |
| GET  | /api/auth/me       | Bearer | -- | `200 {user}` |
| POST | /api/auth/logout  | Bearer | -- | `200 {ok:true}` |

## Manual curl test
```bash
# register
curl -X POST http://localhost:4000/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"secret123"}'

# login
TOKEN=$(curl -s -X POST http://localhost:4000/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","password":"secret123"}' | jq -r .token)

# me
curl http://localhost:4000/api/auth/me -H "Authorization: Bearer $TOKEN"
```

## Error format
All errors return:
```json
{ "error": { "code": "INVALID_INPUT", "message": "用户名至少 2 个字符" } }
```

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

See [docs/SPEC.md](docs/SPEC.md) for the full design spec.
