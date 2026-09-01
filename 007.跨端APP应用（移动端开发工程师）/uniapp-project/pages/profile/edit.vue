<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage, LANGS } from '@/i18n/useLanguage'
import { updateProfile, changePassword } from '@/api/users'
import type { Gender } from '@/api/users'
import { t } from '@/i18n/dict'

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
          <input v-model="currentPwd" class="text-input" type="password" :placeholder="t(lang, 'profileEdit.oldPasswordPlaceholder')" />
        </view>
      </view>

      <view class="field">
        <text class="field-label">{{ t(lang, 'profileEdit.newPassword') }}</text>
        <view class="input-wrap">
          <text class="input-icon mat-icon">key</text>
          <input v-model="newPwd" class="text-input" type="password" :placeholder="t(lang, 'profileEdit.newPasswordPlaceholder')" />
        </view>
      </view>

      <view class="field">
        <text class="field-label">{{ t(lang, 'profileEdit.confirmPassword') }}</text>
        <view class="input-wrap">
          <text class="input-icon mat-icon">shield</text>
          <input v-model="confirmPwd" class="text-input" type="password" :placeholder="t(lang, 'profileEdit.confirmPasswordPlaceholder')" />
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
.page { min-height: 100vh; background: var(--c-bg); padding: 24rpx; display: flex; flex-direction: column; gap: 24rpx; }
.card { background: var(--c-bg-card); border-radius: 20rpx; padding: 32rpx; border: 1px solid var(--c-divider); display: flex; flex-direction: column; gap: 0; }
.section-header { margin-bottom: 32rpx; }
.section-title { font-size: 34rpx; font-weight: 700; color: var(--c-text); display: block; margin-bottom: 8rpx; }
.section-desc { font-size: 26rpx; color: var(--c-text-variant); }
.avatar-center { display: flex; flex-direction: column; align-items: center; gap: 24rpx; margin-bottom: 32rpx; }
.avatar-circle-lg { width: 200rpx; height: 200rpx; border-radius: 50%; background: var(--c-primary-light); display: flex; align-items: center; justify-content: center; overflow: hidden; }
.avatar-img { width: 100%; height: 100%; }
.avatar-icon-lg { font-family: 'Material Symbols Outlined'; font-size: 100px; font-weight: normal; font-style: normal; color: var(--c-primary); }
.btn-outline { display: inline-flex; align-items: center; gap: 8rpx; border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 16rpx 32rpx; font-size: 28rpx; color: var(--c-text); background: transparent; }
.mat-icon { font-family: 'Material Symbols Outlined'; font-weight: normal; font-style: normal; }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.msg { border-radius: 8rpx; padding: 12rpx 20rpx; font-size: 24rpx; }
.msg-ok { background: var(--c-secondary-container); color: var(--c-on-secondary-container); }
.msg-err { background: var(--c-error-container); color: var(--c-on-error-container); }
.card-footer { border-top: 1px solid var(--c-divider); padding-top: 24rpx; margin-top: 24rpx; }
.flex-end { display: flex; justify-content: flex-end; }
.btn-primary { display: inline-flex; align-items: center; gap: 8rpx; background: var(--c-primary); color: #fff; border-radius: 12rpx; padding: 16rpx 40rpx; font-size: 30rpx; font-weight: 600; border: none; }
.btn-primary:disabled { opacity: 0.6; }
.field { margin-bottom: 24rpx; }
.field-label { font-size: 28rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 8rpx; }
.input-wrap { position: relative; display: flex; align-items: center; }
.input-icon { position: absolute; left: 20rpx; color: var(--c-text-variant); font-size: 20px; }
.text-input { width: 100%; background: var(--c-bg); border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 20rpx 20rpx 20rpx 72rpx; color: var(--c-text); font-size: 30rpx; box-sizing: border-box; }
.gender-row { display: flex; gap: 16rpx; }
.gender-btn { flex: 1; display: flex; align-items: center; justify-content: center; gap: 8rpx; padding: 24rpx; border-radius: 12rpx; border: 1px solid var(--c-divider); background: var(--c-bg); color: var(--c-text); font-size: 28rpx; transition: all 0.2s; }
.gender-active { border: 2px solid var(--c-primary); background: var(--c-primary-light); color: var(--c-primary); font-weight: 600; }
</style>
