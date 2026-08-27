import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import request from 'supertest'
import { v4 as uuid } from 'uuid'
import { createApp } from '../src/app.js'
import { closePool, getPool } from '../src/db/pool.js'

const app = createApp()

const uniq = (label: string) => `${label.replace(/-/g, '')}_${uuid().slice(0, 8).replace(/-/g, '')}`
const PASSWORD = 'Demo@123'

let token = ''
let username = ''

const register = async (label: string) => {
  const u = uniq(label)
  const res = await request(app)
    .post('/api/auth/register')
    .send({ username: u, password: PASSWORD })
  expect(res.status, `register failed: ${JSON.stringify(res.body)}`).toBe(201)
  expect(res.body.token).toBeTypeOf('string')
  return { user: u, token: res.body.token as string }
}

beforeAll(async () => {
  const r = await register('users-test')
  token = r.token
  username = r.user
})

afterAll(async () => {
  if (username) {
    const pool = getPool()
    await pool.query(
      `DELETE a, b FROM users u
         LEFT JOIN accounts a ON a.user_id = u.id
         LEFT JOIN books    b ON b.owner_id = u.id
       WHERE u.username = ?`,
      [username],
    )
  }
  await closePool()
})

describe('PATCH /api/users/me', () => {
  it('要求鉴权（401）', async () => {
    const res = await request(app).patch('/api/users/me').send({ displayName: 'x' })
    expect(res.status).toBe(401)
  })

  it('更新 displayName / gender / age 成功', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ displayName: '小明', gender: 'male', age: 28 })

    expect(res.status).toBe(200)
    expect(res.body.user).toMatchObject({
      displayName: '小明',
      gender: 'male',
      age: 28,
    })
  })

  it('允许部分字段更新（avatar）', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ avatar: 'https://cdn.example.com/avatars/test.png' })

    expect(res.status).toBe(200)
    expect(res.body.user.avatar).toBe('https://cdn.example.com/avatars/test.png')
    // 之前设置的字段不被清除
    expect(res.body.user.displayName).toBe('小明')
    expect(res.body.user.age).toBe(28)
  })

  it('displayName 空字符串被拒绝', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ displayName: '' })

    expect(res.status).toBe(400)
    expect(res.body.error?.message).toMatch(/昵称/)
  })

  it('avatar 不是 URL 被拒绝', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ avatar: 'not-a-url' })

    expect(res.status).toBe(400)
    expect(res.body.error?.message).toMatch(/URL/)
  })

  it('age 超出范围被拒绝', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ age: 999 })

    expect(res.status).toBe(400)
  })

  it('gender 取值非法被拒绝', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ gender: 'unknown' })

    expect(res.status).toBe(400)
  })

  it('空 body 被拒绝（要求至少一个字段）', async () => {
    const res = await request(app)
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({})

    expect(res.status).toBe(400)
    expect(res.body.error?.message).toMatch(/字段/)
  })
})

describe('POST /api/users/me/password', () => {
  it('要求鉴权（401）', async () => {
    const res = await request(app)
      .post('/api/users/me/password')
      .send({ oldPassword: PASSWORD, newPassword: 'NewPass1' })
    expect(res.status).toBe(401)
  })

  it('使用正确旧密码修改成功', async () => {
    const res = await request(app)
      .post('/api/users/me/password')
      .set('Authorization', `Bearer ${token}`)
      .send({ oldPassword: PASSWORD, newPassword: 'NewPass1' })

    expect(res.status).toBe(200)
    expect(res.body.ok).toBe(true)

    // 用新密码能登录
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ username, password: 'NewPass1' })
    expect(loginRes.status).toBe(200)
    expect(loginRes.body.token).toBeTypeOf('string')
    token = loginRes.body.token
  })

  it('旧密码错误被拒绝（401）', async () => {
    const res = await request(app)
      .post('/api/users/me/password')
      .set('Authorization', `Bearer ${token}`)
      .send({ oldPassword: 'WRONG-PASS', newPassword: 'AnotherPass1' })

    expect(res.status).toBe(401)
    expect(res.body.error?.message).toMatch(/旧密码/)
  })

  it('新密码过短被拒绝', async () => {
    const res = await request(app)
      .post('/api/users/me/password')
      .set('Authorization', `Bearer ${token}`)
      .send({ oldPassword: 'NewPass1', newPassword: '123' })

    expect(res.status).toBe(400)
    expect(res.body.error?.message).toMatch(/至少 6 位/)
  })

  it('缺少 oldPassword 被拒绝', async () => {
    const res = await request(app)
      .post('/api/users/me/password')
      .set('Authorization', `Bearer ${token}`)
      .send({ newPassword: 'NewPass1' })

    expect(res.status).toBe(400)
  })
})