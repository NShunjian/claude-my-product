<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useAuthStore } from '@/stores/auth'
import { useBookStore } from '@/stores/book'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { useThemeStore } from '@/stores/theme'
import { LANGS } from '@/i18n/dict'

const auth = useAuthStore()
const book = useBookStore()
const toast = useToastStore()
const { t, lang, setLang } = useLanguage()
const theme = useThemeStore()

const username = ref('')
const password = ref('')
const busy = ref(false)

// navigationStyle: custom 后页面顶端 = 屏幕顶端,需要让出顶部状态栏高度,
// 否则 logo 会进入状态栏区域。H5 上 statusBarHeight = 0,不影响。
const statusBarHeight = ref(0)
// #ifdef MP-WEIXIN || APP-PLUS
try {
  statusBarHeight.value = uni.getSystemInfoSync().statusBarHeight ?? 0
} catch { /* fallback 0 */ }
// #endif

// 随机化密码字段的 name,防止浏览器把它当成上次保存的密码字段自动填充;
// 退出登录(reLaunch 回登录页)后,Chrome 等浏览器仍可能把保存的密码填回来,
// 必须额外清理。做法与 profile/edit.vue 的 nukePasswordFields 一致。
const pwdNameSeed = Math.random().toString(36).slice(2, 10)
function nukePasswordFields() {
  setTimeout(() => {
    if (typeof document === 'undefined') return
    document.querySelectorAll<HTMLInputElement>('.qz-pwd-input').forEach((el) => {
      if (el.value) {
        el.value = ''
        el.dispatchEvent(new Event('input', { bubbles: true }))
      }
    })
  }, 1500)
}
function unlockPwd() {
  // uniapp H5 下 @focus 的 currentTarget/target 不一定是原生 input(可能是包装对象),
  // 直接查 DOM 找 .qz-pwd-input 移除 readonly,避免 e.target 没有 removeAttribute 报错
  if (typeof document === 'undefined') return
  document.querySelectorAll<HTMLInputElement>('.qz-pwd-input').forEach((el) => {
    el.removeAttribute('readonly')
  })
}

// mount 时回填上次登录保存的真实 username,避免浏览器把 displayName 误填到字段里
onMounted(() => {
  const last = auth.getLastUsername()
  if (last) username.value = last
  nukePasswordFields()
})
onShow(nukePasswordFields)

async function submit() {
  if (!username.value || !password.value) { toast.show(t('login.fillAll')); return }
  busy.value = true
  try {
    await auth.login({ username: username.value, password: password.value })
    // 登录成功后立刻拉账本列表,否则首页 watch 触发时 book.current 还是 null,load() 直接 return
    await book.reload()
    uni.reLaunch({ url: '/pages/index/index' })
  } catch (e: any) {
    toast.show(e?.message ?? t('login.opFailed'))
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <view class="login" :style="{ paddingTop: `calc(${statusBarHeight}px + 180rpx)` }">
    <view class="head">
      <view class="logo-wrap"><text class="logo-text">Q</text></view>
      <text class="brand">{{ t('login.brandName') }}</text>
    </view>
    <view class="card">
      <view class="field">
        <text class="label">{{ t('login.username') }}</text>
        <input v-model="username" class="input" :placeholder="t('login.username')" type="text" name="qz_login_username" autocomplete="off" />
      </view>
      <view class="field">
        <text class="label">{{ t('login.password') }}</text>
        <!--
          readonly + Chrome autofill nuke 只在 H5 有意义。
          微信小程序里 document 不存在,unlockPwd 永远 early-return,readonly 解不掉,
          readonly 的 input 在 mp 里会拦截焦点链 → 把 button 的 tap 也带走。
          所以 mp 端就不加 readonly 了。
        -->
        <!-- #ifdef H5 -->
        <input v-model="password" class="input qz-pwd-input" :placeholder="t('login.password')" type="password" :name="`qz_login_pwd_${pwdNameSeed}`" autocomplete="new-password" readonly data-form-type="other" data-1p-ignore @focus="unlockPwd" />
        <!-- #endif -->
        <!-- #ifdef MP-WEIXIN -->
        <!-- 微信小程序里 type="password" 渲染失效(显示明文),必须用 type="text" + password="true" 才会出掩码圆点 -->
        <input v-model="password" class="input qz-pwd-input" :placeholder="t('login.password')" type="text" password="true" :name="`qz_login_pwd_${pwdNameSeed}`" @focus="unlockPwd" />
        <!-- #endif -->
      </view>
      <!--
        微信小程序里 <button> 的 tap 经常被 form-type 默认行为 / hover-class / 内部焦点链吃掉,
        最稳的做法是用 <view> + hover-class 伪装成按钮,绕过所有 button 的特殊处理。
        点击行为通过 @tap 触发,H5 / mp 一致。
      -->
      <view
        class="btn-primary"
        :class="{ 'btn-disabled': busy }"
        hover-class="btn-hover"
        hover-stay-time="80"
        @tap="submit"
      >
        <text class="btn-primary-text">{{ busy ? t('login.submitting') : t('login.submit') }}</text>
      </view>
    </view>
    <view class="prefs">
      <picker mode="selector" :range="LANGS.map(l => l.label)" :value="LANGS.findIndex(l => l.code === lang)" @change="(e: any) => setLang(LANGS[Number(e.detail.value)].code)">
        <view class="pref-item">{{ LANGS.find(l => l.code === lang)?.label }}</view>
      </picker>
      <view class="pref-item" @tap="theme.setMode(theme.mode === 'dark' ? 'light' : 'dark')">
        {{ theme.mode === 'dark' ? '🌙' : '☀️' }}
      </view>
    </view>
  </view>
</template>

<style scoped>
/* height: 100vh + overflow: hidden 禁掉整个页面滚动:H5 上 body 默认会跟着溢出滚动,
   mp 上 view 本来就不滚,加这个无副作用;height 写死避免内容溢出后 body 跟着滚 */
.login { padding: 80rpx 48rpx; display: flex; flex-direction: column; gap: 48rpx; height: 100vh; overflow: hidden; background: var(--c-bg); }
.head { display: flex; align-items: center; gap: 16rpx; justify-content: center; }
.logo-wrap { width: 80rpx; height: 80rpx; border-radius: 20rpx; background: var(--c-primary); display: flex; align-items: center; justify-content: center; }
.logo-text { color: #fff; font-weight: 700; font-size: 40rpx; }
.brand { font-size: 40rpx; font-weight: 700; }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 40rpx; display: flex; flex-direction: column; gap: 32rpx; border: 1px solid var(--c-divider); }
.field { display: flex; flex-direction: column; gap: 12rpx; }
.label { font-size: 28rpx; color: var(--c-text-variant); }
.input { border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 20rpx; background: var(--c-bg); color: var(--c-text); font-size: 30rpx; }
.btn-primary {
  background: var(--c-primary);
  color: #fff;
  border-radius: 12rpx;
  padding: 24rpx;
  font-size: 32rpx;
  font-weight: 600;
  text-align: center;
  line-height: 1.4;
}
.btn-primary-text { color: #fff; font-size: 32rpx; font-weight: 600; }
.btn-disabled { opacity: 0.6; }
.btn-hover { background: #1f6acc; }
.prefs { display: flex; gap: 16rpx; justify-content: flex-end; }
.pref-item { padding: 12rpx 20rpx; border-radius: 16rpx; background: var(--c-surface); font-size: 26rpx; }
</style>
