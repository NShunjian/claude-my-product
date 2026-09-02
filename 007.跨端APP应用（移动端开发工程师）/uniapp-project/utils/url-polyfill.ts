/**
 * 微信小程序基础库(<2.x 部分版本)没有 URLSearchParams / URL 全局,
 * Vue 3 runtime 在 SSR / 模板解析路径上会用到,缺了就 ReferenceError,
 * 整个页面不渲染 → 首页空数据。
 *
 * 这里给最常用的 URLSearchParams 写个最小 polyfill,
 * 只够 Vue 3 + 项目自身用,不全按 WHATWG 规范实现。
 *
 * H5 / 现代 mp 基础库里已经有原生 URLSearchParams,这里直接跳过。
 */

if (typeof globalThis.URLSearchParams === 'undefined') {
  class URLSearchParamsPolyfill {
    private store: Array<[string, string]> = []

    constructor(init?: string | URLSearchParamsPolyfill | Array<[string, string]> | Record<string, string>) {
      if (!init) return

      if (typeof init === 'string') {
        const s = init.startsWith('?') ? init.slice(1) : init
        if (!s) return
        for (const pair of s.split('&')) {
          if (!pair) continue
          const idx = pair.indexOf('=')
          const rawK = idx === -1 ? pair : pair.slice(0, idx)
          const rawV = idx === -1 ? '' : pair.slice(idx + 1)
          if (!rawK) continue
          this.store.push([decodeURIComponent(rawK), decodeURIComponent(rawV.replace(/\+/g, ' '))])
        }
      } else if (init instanceof URLSearchParamsPolyfill) {
        this.store = init.store.slice()
      } else if (Array.isArray(init)) {
        for (const [k, v] of init) this.store.push([String(k), String(v)])
      } else {
        for (const k of Object.keys(init)) this.store.push([k, String(init[k])])
      }
    }

    append(name: string, value: string): void {
      this.store.push([name, String(value)])
    }

    delete(name: string): void {
      this.store = this.store.filter(([k]) => k !== name)
    }

    get(name: string): string | null {
      const hit = this.store.find(([k]) => k === name)
      return hit ? hit[1] : null
    }

    getAll(name: string): string[] {
      return this.store.filter(([k]) => k === name).map(([, v]) => v)
    }

    has(name: string): boolean {
      return this.store.some(([k]) => k === name)
    }

    set(name: string, value: string): void {
      this.delete(name)
      this.store.push([name, String(value)])
    }

    toString(): string {
      return this.store
        .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
        .join('&')
    }

    forEach(cb: (value: string, key: string, parent: this) => void): void {
      for (const [k, v] of this.store.slice()) cb(v, k, this)
    }

    *entries(): IterableIterator<[string, string]> {
      for (const e of this.store) yield e
    }

    *keys(): IterableIterator<string> {
      for (const [k] of this.store) yield k
    }

    *values(): IterableIterator<string> {
      for (const [, v] of this.store) yield v
    }

    [Symbol.iterator](): IterableIterator<[string, string]> {
      return this.entries()
    }
  }

  // @ts-expect-error — 微信小程序运行时缺少该全局,这里补上
  globalThis.URLSearchParams = URLSearchParamsPolyfill
}

export {}