<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage, LANGS } from '@/i18n/useLanguage'
import { updateProfile, changePassword } from '@/api/users'
import type { Gender } from '@/api/users'
import { t } from '@/i18n/dict'
import AppHeader from '@/components/AppHeader.vue'
import { goBack } from '@/utils/back'

const auth = useAuthStore()
const toast = useToastStore()
const { lang, setLang } = useLanguage()

// ── profile fields ────────────────────────────────────────────────────────
const gender = ref<Gender | ''>('')
const age = ref('')
const displayName = ref('')
const savingProfile = ref(false)
const profileMsg = ref<{ kind: 'ok' | 'err'; text: string } | null>(null)

// sync from auth user
watch(() => auth.user, (u) => {
  displayName.value = u?.displayName ?? ''
  gender.value = (u?.gender as Gender | undefined) ?? ''
  age.value = u?.age != null ? String(u.age) : ''
}, { immediate: true })

// 浏览器密码管理器在 Vue 渲染后再注入旧凭据(Chrome 通常 200-1000ms 才填,
// 也可能 1500ms 后二次填充);setTimeout + 直接操作 DOM 才能压住它;同时触发 input 事件让 v-model 同步 Vue state。
// 用 keydown 而非 input 事件标记用户真实输入,避免 Chrome autofill 触发的 input 误标记为用户输入。
function nukePasswordFields() {
  if (typeof document === 'undefined') return
  const inputs = Array.from(document.querySelectorAll<HTMLInputElement>('.qz-pwd-input'))
  inputs.forEach((el) => {
    if (el.dataset.nukeBound === '1') return
    el.dataset.nukeBound = '1'
    el.addEventListener('keydown', () => { el.dataset.userTyped = '1' }, { once: true })
  })
  const tryNuke = () => {
    inputs.forEach((el) => {
      if (el.dataset.userTyped === '1') return
      if (el.value) {
        el.value = ''
        el.dispatchEvent(new Event('input', { bubbles: true }))
      }
    })
  }
  // 多个时点兜底:Chrome 可能 200ms 填一次、1500ms 后再填一次
  tryNuke()
  setTimeout(tryNuke, 500)
  setTimeout(tryNuke, 1500)
  setTimeout(tryNuke, 3000)
}

onMounted(nukePasswordFields)
onShow(nukePasswordFields)

/** readonly 字段 Chrome 不会自动填充,聚焦时再放行,既压住密码管理器又不影响用户手动输入 */
function unlockPwd() {
  // uniapp H5 下 @focus 的 currentTarget/target 不一定是原生 input(可能是包装对象),
  // 直接查 DOM 找 .qz-pwd-input 移除 readonly,避免 e.target 没有 removeAttribute 报错
  if (typeof document === 'undefined') return
  document.querySelectorAll<HTMLInputElement>('.qz-pwd-input').forEach((el) => {
    el.removeAttribute('readonly')
  })
}

async function handleSaveProfile() {
  profileMsg.value = null
  const trimmedName = displayName.value.trim()
  if (!trimmedName) {
    profileMsg.value = { kind: 'err', text: t(lang, 'profileEdit.nameRequired') }
    return
  }
  const parsedAge = age.value.trim() === '' ? null : Number(age.value)
  if (parsedAge !== null && (!Number.isFinite(parsedAge) || parsedAge < 0 || parsedAge > 150)) {
    profileMsg.value = { kind: 'err', text: t(lang, 'profileEdit.ageInvalid') }
    return
  }
  savingProfile.value = true
  try {
    await updateProfile({
      displayName: trimmedName,
      gender: gender.value === '' ? null : gender.value,
      age: parsedAge,
    })
    await auth.me()
    profileMsg.value = { kind: 'ok', text: t(lang, 'profileEdit.profileSaved') }
    // 保存成功 → 用 history-aware goBack 回到上一页(自定义 nav 下,不走 uni.navigateBack 兜底)
    goBack()
  } catch (err: any) {
    profileMsg.value = { kind: 'err', text: err?.message ?? t(lang, 'profileEdit.saveFailDefault') }
  } finally {
    savingProfile.value = false
  }
}

// ── avatar ────────────────────────────────────────────────────────────────
const avatarPreview = ref<string | null>(null)
const avatarMsg = ref<{ kind: 'ok' | 'err'; text: string } | null>(null)
const savingAvatar = ref(false)

/** 跨平台选择图片并压缩为 base64（匹配 React compressAvatar 行为） */
function triggerAvatarInput() {
  uni.chooseImage({
    count: 1,
    sizeType: ['compressed'],
    sourceType: ['album', 'camera'],
    success: (res) => {
      const tempFilePath = res.tempFilePaths[0]
      readAvatarBase64(tempFilePath)
        .then((dataUrl) => {
          avatarPreview.value = dataUrl
          avatarMsg.value = { kind: 'ok', text: t(lang, 'profileEdit.avatarPreviewReady') }
        })
        .catch((err: any) => {
          avatarMsg.value = {
            kind: 'err',
            text: err?.message ?? t(lang, 'profileEdit.avatarProcessFailDefault'),
          }
        })
    },
    fail: () => {
      // user cancelled — no-op
    },
  })
}

/**
 * 读取本地图片为 base64 dataURL。
 * - H5: XMLHttpRequest → FileReader（与 React compressAvatar 行为一致）
 * - native/app: uni.getFileSystemManager().readFile（canvas 跨平台不可用）
 */
function readAvatarBase64(tempFilePath: string): Promise<string> {
  return new Promise((resolve, reject) => {
    // #ifdef H5
    const xhr = new XMLHttpRequest()
    xhr.open('GET', tempFilePath, true)
    xhr.responseType = 'blob'
    xhr.onload = () => {
      if (xhr.status === 200) {
        const reader = new FileReader()
        reader.onload = () => resolve(reader.result as string)
        reader.onerror = () => reject(new Error(t(lang, 'profileEdit.avatarReadFail')))
        reader.readAsDataURL(xhr.response)
      } else {
        reject(new Error(t(lang, 'profileEdit.avatarReadFail')))
      }
    }
    xhr.onerror = () => reject(new Error(t(lang, 'profileEdit.avatarReadFail')))
    xhr.send()
    // #endif

    // #ifndef H5
    uni.getFileSystemManager().readFile({
      filePath: tempFilePath,
      encoding: 'base64',
      success: (r) => resolve(`data:image/jpeg;base64,${r.data}`),
      fail: () => reject(new Error(t(lang, 'profileEdit.avatarReadFail'))),
    })
    // #endif
  })
}

async function handleSaveAvatar() {
  avatarMsg.value = null
  if (!avatarPreview.value) {
    avatarMsg.value = { kind: 'err', text: t(lang, 'profileEdit.avatarSelectFile') }
    return
  }
  savingAvatar.value = true
  try {
    await updateProfile({ avatar: avatarPreview.value })
    await auth.me()
    avatarPreview.value = null
    avatarMsg.value = { kind: 'ok', text: t(lang, 'profileEdit.avatarUpdated') }
    // 保存成功 → 用 history-aware goBack 回到上一页(自定义 nav 下,不走 uni.navigateBack 兜底)
    goBack()
  } catch (err: any) {
    avatarMsg.value = { kind: 'err', text: err?.message ?? t(lang, 'profileEdit.saveFailDefault') }
  } finally {
    savingAvatar.value = false
  }
}

// ── password ───────────────────────────────────────────────────────────────
const currentPwd = ref('')
const newPwd = ref('')
const confirmPwd = ref('')
const savingPwd = ref(false)
const pwdMsg = ref<{ kind: 'ok' | 'err'; text: string } | null>(null)

/** 随机化密码字段的 name 属性,Chrome 通过 name=current-password/new-password 识别密码字段,
 *  改成一次性随机串后 Chrome 完全识别不出来,直接放弃自动填充 */
const pwdNameSeed = Math.random().toString(36).slice(2, 10)

async function handleChangePassword() {
  pwdMsg.value = null
  if (!currentPwd.value || !newPwd.value || !confirmPwd.value) {
    pwdMsg.value = { kind: 'err', text: t(lang, 'profileEdit.passwordFillAll') }
    return
  }
  if (newPwd.value !== confirmPwd.value) {
    pwdMsg.value = { kind: 'err', text: t(lang, 'profileEdit.passwordMismatch') }
    return
  }
  if (newPwd.value.length < 8) {
    pwdMsg.value = { kind: 'err', text: t(lang, 'profileEdit.passwordTooShort') }
    return
  }
  if (newPwd.value === currentPwd.value) {
    pwdMsg.value = { kind: 'err', text: t(lang, 'profileEdit.passwordSame') }
    return
  }
  savingPwd.value = true
  try {
    await changePassword({ oldPassword: currentPwd.value, newPassword: newPwd.value })
    currentPwd.value = ''
    newPwd.value = ''
    confirmPwd.value = ''
    pwdMsg.value = { kind: 'ok', text: t(lang, 'profileEdit.passwordChanged') }
    // 保存成功 → 用 history-aware goBack 回到上一页(自定义 nav 下,不走 uni.navigateBack 兜底)
    goBack()
  } catch (err: any) {
    pwdMsg.value = { kind: 'err', text: err?.message ?? t(lang, 'profileEdit.passwordChangeFailDefault') }
  } finally {
    savingPwd.value = false
  }
}

// ── common ─────────────────────────────────────────────────────────────────
const msgOk = (msg: { kind: 'ok' | 'err'; text: string }) => msg.kind === 'ok'
</script>

<template>
  <AppHeader :title="t(lang, 'profileEdit.title')" back @back="goBack" />
  <view class="page">
    <!-- avatar section -->
    <view class="card">
      <view class="section-header">
        <text class="section-title">{{ t(lang, 'profileEdit.avatarSection') }}</text>
        <text class="section-desc">{{ t(lang, 'profileEdit.avatarDesc') }}</text>
      </view>

      <view class="avatar-center">
        <view class="avatar-circle-lg">
          <image v-if="avatarPreview || auth.user?.avatar" :src="avatarPreview ?? auth.user!.avatar!" class="avatar-img" mode="aspectFill" />
          <text v-else class="avatar-icon-lg">account_circle</text>
        </view>

        <button class="btn-outline" @tap="triggerAvatarInput">
          <text class="mat-icon" style="font-size:18px">upload</text>
          {{ t(lang, 'profileEdit.uploadAvatar') }}
        </button>

        <view v-if="avatarMsg" :class="['msg', msgOk(avatarMsg) ? 'msg-ok' : 'msg-err']">
          <text>{{ avatarMsg.text }}</text>
        </view>
      </view>

      <view class="card-footer">
        <view class="flex-end">
          <button class="btn-primary" :disabled="savingAvatar || !avatarPreview" @tap="handleSaveAvatar">
            <text v-if="savingAvatar" class="mat-icon spin">progress_activity</text>
            {{ t(lang, 'profileEdit.saveAvatar') }}
          </button>
        </view>
      </view>
    </view>

    <!-- profile section -->
    <view class="card">
      <view class="section-header">
        <text class="section-title">{{ t(lang, 'profileEdit.profileSection') }}</text>
        <text class="section-desc">{{ t(lang, 'profileEdit.profileDesc') }}</text>
      </view>

      <view class="field">
        <text class="field-label">{{ t(lang, 'profileEdit.displayName') }}</text>
        <view class="input-wrap">
          <text class="input-icon mat-icon">person</text>
          <input v-model="displayName" class="text-input" :placeholder="t(lang, 'profileEdit.displayNamePlaceholder')" />
        </view>
      </view>

      <!-- gender -->
      <view class="field">
        <text class="field-label">{{ t(lang, 'profileEdit.gender') }}</text>
        <view class="gender-row">
          <view :class="['gender-btn', gender === 'male' ? 'gender-active' : '']" @tap="gender = 'male'">
            <text class="mat-icon" style="font-size:20px">male</text>
            {{ t(lang, 'profileEdit.gender.male') }}
          </view>
          <view :class="['gender-btn', gender === 'female' ? 'gender-active' : '']" @tap="gender = 'female'">
            <text class="mat-icon" style="font-size:20px">female</text>
            {{ t(lang, 'profileEdit.gender.female') }}
          </view>
        </view>
      </view>

      <!-- age -->
      <view class="field">
        <text class="field-label">{{ t(lang, 'profileEdit.age') }}</text>
        <view class="input-wrap">
          <text class="input-icon mat-icon">calendar_month</text>
          <input v-model="age" class="text-input" type="number" min="0" max="150" :placeholder="t(lang, 'profileEdit.agePlaceholder')" />
        </view>
      </view>

      <view v-if="profileMsg" :class="['msg', msgOk(profileMsg) ? 'msg-ok' : 'msg-err']">
        <text>{{ profileMsg.text }}</text>
      </view>

      <view class="card-footer">
        <view class="flex-end">
          <button class="btn-primary" :disabled="savingProfile" @tap="handleSaveProfile">
            <text v-if="savingProfile" class="mat-icon spin">progress_activity</text>
            {{ t(lang, 'profileEdit.saveProfile') }}
          </button>
        </view>
      </view>
    </view>

    <!-- security section -->
    <view class="card">
      <view class="section-header">
        <text class="section-title">{{ t(lang, 'profileEdit.securitySection') }}</text>
        <text class="section-desc">{{ t(lang, 'profileEdit.securityDesc') }}</text>
      </view>

      <view class="field">
        <text class="field-label">{{ t(lang, 'profileEdit.oldPassword') }}</text>
        <view class="input-wrap">
          <text class="input-icon mat-icon">lock</text>
          <input v-model="currentPwd" class="text-input qz-pwd-input" type="password" :name="`qz_pwd_${pwdNameSeed}_current`" autocomplete="new-password" readonly data-form-type="other" data-1p-ignore @focus="unlockPwd" :placeholder="t(lang, 'profileEdit.oldPasswordPlaceholder')" />
        </view>
      </view>

      <view class="field">
        <text class="field-label">{{ t(lang, 'profileEdit.newPassword') }}</text>
        <view class="input-wrap">
          <text class="input-icon mat-icon">key</text>
          <input v-model="newPwd" class="text-input qz-pwd-input" type="password" :name="`qz_pwd_${pwdNameSeed}_new`" autocomplete="new-password" readonly data-form-type="other" data-1p-ignore @focus="unlockPwd" :placeholder="t(lang, 'profileEdit.newPasswordPlaceholder')" />
        </view>
      </view>

      <view class="field">
        <text class="field-label">{{ t(lang, 'profileEdit.confirmPassword') }}</text>
        <view class="input-wrap">
          <text class="input-icon mat-icon">shield</text>
          <input v-model="confirmPwd" class="text-input qz-pwd-input" type="password" :name="`qz_pwd_${pwdNameSeed}_confirm`" autocomplete="new-password" readonly data-form-type="other" data-1p-ignore @focus="unlockPwd" :placeholder="t(lang, 'profileEdit.confirmPasswordPlaceholder')" />
        </view>
      </view>

      <view v-if="pwdMsg" :class="['msg', msgOk(pwdMsg) ? 'msg-ok' : 'msg-err']">
        <text>{{ pwdMsg.text }}</text>
      </view>

      <view class="card-footer">
        <view class="flex-end">
          <button class="btn-primary" :disabled="savingPwd" @tap="handleChangePassword">
            <text v-if="savingPwd" class="mat-icon spin">progress_activity</text>
            {{ t(lang, 'profileEdit.savePassword') }}
          </button>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { min-height: 100vh; background: var(--c-bg); padding: 32rpx; display: flex; flex-direction: column; gap: 32rpx; }
.card { background: var(--c-bg-card); border-radius: 24rpx; padding: 48rpx; border: 1px solid var(--c-divider); display: flex; flex-direction: column; gap: 0; }
.section-header { margin-bottom: 40rpx; }
.section-title { font-size: 40rpx; font-weight: 700; color: var(--c-text); display: block; margin-bottom: 8rpx; }
.section-desc { font-size: 28rpx; color: var(--c-text-variant); }
.avatar-center { display: flex; flex-direction: column; align-items: center; gap: 32rpx; margin-bottom: 40rpx; }
.avatar-circle-lg { width: 240rpx; height: 240rpx; border-radius: 50%; background: var(--c-primary-light); display: flex; align-items: center; justify-content: center; overflow: hidden; }
.avatar-img { width: 100%; height: 100%; }
.avatar-icon-lg { font-family: 'Material Symbols Outlined'; font-size: 120rpx; font-weight: normal; font-style: normal; color: var(--c-primary); }
.btn-outline { display: inline-flex; align-items: center; justify-content: center; gap: 8rpx; height: 72rpx; line-height: 1; border: 1px solid var(--c-divider); border-radius: 16rpx; padding: 0 32rpx; font-size: 28rpx; color: var(--c-text); background: transparent; margin: 0; }
.btn-outline::after { border: none; }
.mat-icon { font-family: 'Material Symbols Outlined'; font-weight: normal; font-style: normal; }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.msg { border-radius: 12rpx; padding: 16rpx 24rpx; font-size: 26rpx; }
.msg-ok { background: var(--c-secondary-container); color: var(--c-on-secondary-container); }
.msg-err { background: var(--c-error-container); color: var(--c-on-error-container); }
.card-footer { border-top: 1px solid var(--c-divider); padding-top: 32rpx; margin-top: 40rpx; }
.flex-end { display: flex; justify-content: flex-end; }
.btn-primary { display: inline-flex; align-items: center; justify-content: center; gap: 8rpx; height: 80rpx; line-height: 1; background: var(--c-primary); color: #fff; border-radius: 16rpx; padding: 0 40rpx; font-size: 30rpx; font-weight: 600; border: none; margin: 0; }
.btn-primary::after { border: none; }
.btn-primary:disabled { opacity: 0.6; }
.field { margin-bottom: 32rpx; }
.field-label { font-size: 32rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 12rpx; }
.input-wrap { position: relative; display: flex; align-items: center; }
.input-icon { position: absolute; left: 28rpx; color: var(--c-text-variant); font-size: 40rpx; line-height: 1; }
.text-input { width: 100%; background: var(--c-bg); border: 1px solid var(--c-divider); border-radius: 16rpx; padding: 28rpx 28rpx 28rpx 88rpx; color: var(--c-text); font-size: 30rpx; box-sizing: border-box; height: 88rpx; }
/* 覆盖 Chrome 自动填充的浅蓝色高亮,即便它偷偷填了也看不出来 */
.text-input:-webkit-autofill,
.text-input:-webkit-autofill:hover,
.text-input:-webkit-autofill:focus { -webkit-box-shadow: 0 0 0 1000px var(--c-bg) inset !important; -webkit-text-fill-color: var(--c-text) !important; transition: background-color 5000s ease-in-out 0s; }
.gender-row { display: flex; gap: 24rpx; }
.gender-btn { flex: 1; display: flex; align-items: center; justify-content: center; gap: 12rpx; height: 88rpx; line-height: 1; border-radius: 16rpx; border: 1px solid var(--c-divider); background: var(--c-bg); color: var(--c-text); font-size: 30rpx; transition: all 0.2s; }
.gender-btn .mat-icon { font-size: 32rpx; }
.gender-active { border: 2px solid var(--c-primary); background: var(--c-primary-light); color: var(--c-primary); font-weight: 600; }
</style>
