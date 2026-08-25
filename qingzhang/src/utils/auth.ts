// 简单的密码哈希工具：SHA-256 + 随机 salt
// 注意：这是本地单机应用的轻量级方案，非生产级安全

const generateSalt = (): string => {
  const arr = new Uint8Array(16)
  crypto.getRandomValues(arr)
  return Array.from(arr)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

const sha256 = async (text: string): Promise<string> => {
  const encoder = new TextEncoder()
  const data = encoder.encode(text)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

export const hashPassword = async (password: string): Promise<{ hash: string; salt: string }> => {
  const salt = generateSalt()
  const hash = await sha256(salt + password)
  return { hash, salt }
}

export const verifyPassword = async (password: string, salt: string, expectedHash: string): Promise<boolean> => {
  const hash = await sha256(salt + password)
  return hash === expectedHash
}
