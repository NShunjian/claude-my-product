/**
 * URLSearchParams polyfill:对齐 uniapp utils/url-polyfill.ts。
 * ponytail: HarmonyOS ArkTS 不带 URLSearchParams,补一个最小实现。
 */

function encode(s: string): string {
  return encodeURIComponent(s).replace(/'/g, '%27').replace(/\(/g, '%28').replace(/\)/g, '%29')
}

function decode(s: string): string {
  return decodeURIComponent(s.replace(/\+/g, ' '))
}

export class URLSearchParams {
  private entries_: Array<[string, string]> = []

  constructor(init?: string | Array<[string, string]> | Record<string, string> | null) {
    if (typeof init === 'string') {
      const s = init.startsWith('?') ? init.slice(1) : init
      if (s.length > 0) {
        for (const part of s.split('&')) {
          if (!part) continue
          const eq = part.indexOf('=')
          const k = eq === -1 ? decode(part) : decode(part.slice(0, eq))
          const v = eq === -1 ? '' : decode(part.slice(eq + 1))
          this.entries_.push([k, v])
        }
      }
    } else if (Array.isArray(init)) {
      for (const [k, v] of init) this.entries_.push([k, v])
    } else if (init && typeof init === 'object') {
      for (const k of Object.keys(init)) this.entries_.push([k, String((init as Record<string, string>)[k])])
    }
  }

  append(name: string, value: string): void { this.entries_.push([name, value]) }
  delete(name: string): void { this.entries_ = this.entries_.filter(e => e[0] !== name) }
  get(name: string): string | null {
    for (const e of this.entries_) if (e[0] === name) return e[1]
    return null
  }
  getAll(name: string): string[] { return this.entries_.filter(e => e[0] === name).map(e => e[1]) }
  has(name: string): boolean { return this.entries_.some(e => e[0] === name) }
  set(name: string, value: string): void {
    const filtered = this.entries_.filter(e => e[0] !== name)
    filtered.push([name, value])
    this.entries_ = filtered
  }
  forEach(cb: (value: string, name: string) => void): void {
    for (const [k, v] of this.entries_) cb(v, k)
  }
  toString(): string {
    return this.entries_.map(([k, v]) => `${encode(k)}=${encode(v)}`).join('&')
  }
  keys(): IterableIterator<string> { return this.entries_.map(e => e[0]).values() }
  values(): IterableIterator<string> { return this.entries_.map(e => e[1]).values() }
  entries(): IterableIterator<[string, string]> { return this.entries_.values() }
  [Symbol.iterator](): IterableIterator<[string, string]> { return this.entries().values() }
}
