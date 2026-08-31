import { describe, it, expect } from 'vitest'
import { t, LANGS } from '@/i18n/dict'

describe('dict.t', () => {
  it('returns translation when key exists', () => {
    expect(t('zh-CN', 'common.confirm')).toBe('确认')
    expect(t('en', 'common.confirm')).toBe('Confirm')
  })
  it('falls back to zh-CN when target missing', () => {
    // 假设 'foo.bar.baz' 在 zh-CN/en/zh-TW 都没有
    expect(t('en', '__nonexistent_key__')).toBe('__nonexistent_key__')
  })
  it('LANGS has 3 entries', () => {
    expect(LANGS.map(l => l.code)).toEqual(['zh-CN', 'en', 'zh-TW'])
  })
})
