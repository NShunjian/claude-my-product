<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useLanguage } from '@/i18n/useLanguage'
import { useToastStore } from '@/stores/toast'
import { useBookStore } from '@/stores/book'
import { getBook, listMembers, addMember, updateMemberRole, removeMember } from '@/api/books'
import type { Book, BookMember, BookRole } from '@/api/books'
import AppHeader from '@/components/AppHeader.vue'
import { goBack } from '@/utils/back'

const { t } = useLanguage()
const toast = useToastStore()
const bookStore = useBookStore()

type InvitableRole = Exclude<BookRole, 'owner'>
const ROLES: InvitableRole[] = ['admin', 'editor', 'viewer']

const bookUuid = ref<string>('')
const book = ref<Book | null>(null)
const members = ref<BookMember[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const busy = ref(false)

const showInvite = ref(false)
const inviteUsername = ref('')
const inviteRole = ref<InvitableRole>('editor')

// Current user uuid from auth store — use bookStore current as fallback
const currentUserUuid = ref<string>('')

onMounted(async () => {
  const pages = getCurrentPages()
  const current = pages[pages.length - 1] as any
  const id = current?.options?.id ?? current?.data?.id ?? ''
  if (!id) { error.value = 'Missing book id'; return }
  bookUuid.value = id
  // get current user uuid from stored auth
  try {
    const userInfo = uni.getStorageInfoSync() ? {} : {}
    const stored = uni.getStorageSync('qz_user')
    if (stored) {
      const u = JSON.parse(stored)
      currentUserUuid.value = u.uuid ?? ''
    }
  } catch {}
  await load()
})

async function load() {
  if (!bookUuid.value) return
  loading.value = true
  error.value = null
  try {
    const [b, ms] = await Promise.all([
      getBook(bookUuid.value),
      listMembers(bookUuid.value),
    ])
    book.value = b
    members.value = ms
  } catch (e: any) {
    error.value = e?.message ?? ''
  } finally {
    loading.value = false
  }
}

const isOwner = computed(() => book.value?.role === 'owner')

async function handleInvite() {
  if (!inviteUsername.value.trim()) return
  busy.value = true
  try {
    await addMember(bookUuid.value, { username: inviteUsername.value.trim(), role: inviteRole.value })
    showInvite.value = false
    inviteUsername.value = ''
    inviteRole.value = 'editor'
    toast.show(t('bookMembers.invite.success'))
    await load()
  } catch (e: any) {
    toast.show(t('bookMembers.invite.failPrefix') + (e?.message ?? ''))
  } finally {
    busy.value = false
  }
}

async function handleRoleChange(m: BookMember, role: InvitableRole) {
  busy.value = true
  try {
    await updateMemberRole(bookUuid.value, m.userUuid, { role })
    toast.show(t('bookMembers.role.success'))
    await load()
  } catch (e: any) {
    toast.show(t('bookMembers.role.failPrefix') + (e?.message ?? ''))
  } finally {
    busy.value = false
  }
}

async function handleRemove(m: BookMember) {
  uni.showModal({
    title: t('common.confirm'),
    content: t('bookMembers.remove.confirm', { name: m.displayName || m.username }),
    success: async (res) => {
      if (!res.confirm) return
      busy.value = true
      try {
        await removeMember(bookUuid.value, m.userUuid)
        toast.show(t('bookMembers.remove.success'))
        await load()
        await bookStore.reload()
      } catch (e: any) {
        toast.show(t('bookMembers.remove.failPrefix') + (e?.message ?? ''))
      } finally {
        busy.value = false
      }
    },
  })
}
</script>

<template>
  <AppHeader :title="t('bookMembers.heading', { name: book?.name ?? '…' })" back @back="goBack" />
  <view class="page">

    <!-- Count + invite -->
    <view class="meta-row">
      <text class="count-text">{{ t('bookMembers.count', { count: members.length }) }}</text>
      <view v-if="book?.role === 'owner'" class="invite-btn" @tap="showInvite = !showInvite">
        <text>+ {{ t('bookMembers.invite.toggle') }}</text>
      </view>
    </view>

    <!-- Invite form -->
    <view v-if="showInvite" class="card">
      <text class="card-title">{{ t('bookMembers.invite.title') }}</text>
      <view class="form-grid">
        <view class="field full">
          <text class="field-label">{{ t('bookMembers.invite.username') }}</text>
          <input v-model="inviteUsername" class="field-input" :placeholder="t('bookMembers.invite.usernamePlaceholder')" />
        </view>
        <view class="field">
          <text class="field-label">{{ t('bookMembers.invite.role') }}</text>
          <picker mode="selector" :range="ROLES" :value="ROLES.indexOf(inviteRole)" @change="(e: any) => inviteRole = ROLES[e.detail.value]">
            <view class="field-picker">
              <text>{{ t(`books.role.${inviteRole}`) }}</text>
              <text class="arrow">▼</text>
            </view>
          </picker>
        </view>
      </view>
      <view class="btn-row">
        <view class="btn-cancel" @tap="showInvite = false" :class="{ disabled: busy }">{{ t('common.cancel') }}</view>
        <view class="btn-confirm" @tap="handleInvite" :class="{ disabled: busy || !inviteUsername.trim() }">
          {{ t('bookMembers.invite.submit') }}
        </view>
      </view>
    </view>

    <!-- Error -->
    <view v-if="error" class="error-box">{{ t('common.error') }}: {{ error }}</view>

    <!-- Loading -->
    <view v-if="loading" class="empty">{{ t('common.loading') }}</view>

    <!-- Members list -->
    <view v-else class="member-list">
      <view v-for="m in members" :key="m.userUuid" class="member-row">
        <view class="avatar">
          <text class="avatar-icon">👤</text>
        </view>
        <view class="member-info">
          <text class="member-name">{{ m.displayName || m.username }}</text>
          <text class="member-user">@{{ m.username }}</text>
        </view>
        <view class="member-actions">
          <view v-if="book?.role === 'owner' && m.role !== 'owner'">
            <picker mode="selector" :range="ROLES" :value="ROLES.indexOf(m.role as InvitableRole)" @change="(e: any) => handleRoleChange(m, ROLES[e.detail.value])">
              <view class="role-select">
                <text>{{ t(`books.role.${m.role}`) }}</text>
                <text class="arrow">▼</text>
              </view>
            </picker>
          </view>
          <view v-else class="role-badge">{{ t(`books.role.${m.role}`) }}</view>
          <view v-if="book?.role === 'owner' && m.role !== 'owner'" class="remove-btn" @tap="handleRemove(m)">
            {{ t('bookMembers.remove.button') }}
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.meta-row { display: flex; justify-content: space-between; align-items: center; }
.count-text { font-size: 26rpx; color: var(--c-text-variant); }
.invite-btn { background: var(--c-primary); color: #fff; border-radius: 12rpx; padding: 12rpx 20rpx; font-size: 26rpx; font-weight: 600; }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; border: 1px solid var(--c-divider); }
.card-title { font-size: 28rpx; font-weight: 600; color: var(--c-text); }
.form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; }
.field { display: flex; flex-direction: column; gap: 6rpx; }
.field.full { grid-column: 1 / -1; }
.field-label { font-size: 24rpx; color: var(--c-text-variant); }
.field-input { border: 1rpx solid var(--c-divider); border-radius: 8rpx; padding: 12rpx 16rpx; font-size: 26rpx; color: var(--c-text); background: var(--c-surface); }
.field-picker { border: 1rpx solid var(--c-divider); border-radius: 8rpx; padding: 12rpx 16rpx; display: flex; justify-content: space-between; font-size: 26rpx; color: var(--c-text); }
.arrow { color: var(--c-text-variant); font-size: 20rpx; }
.btn-row { display: flex; gap: 12rpx; }
.btn-cancel { flex: 1; text-align: center; padding: 16rpx; border: 1rpx solid var(--c-divider); border-radius: 8rpx; font-size: 26rpx; color: var(--c-text); }
.btn-confirm { flex: 1; text-align: center; padding: 16rpx; background: var(--c-primary); color: #fff; border-radius: 8rpx; font-size: 26rpx; }
.btn-cancel.disabled, .btn-confirm.disabled { opacity: 0.5; }
.error-box { background: #FFEBEE; color: #C62828; border-radius: 12rpx; padding: 20rpx; font-size: 26rpx; }
.empty { text-align: center; padding: 80rpx; color: var(--c-text-variant); font-size: 28rpx; }
.member-list { background: var(--c-bg-card); border-radius: 16rpx; overflow: hidden; border: 1px solid var(--c-divider); }
.member-row { display: flex; align-items: center; gap: 16rpx; padding: 20rpx 24rpx; border-bottom: 1rpx solid var(--c-divider); }
.member-row:last-child { border-bottom: none; }
.avatar { width: 72rpx; height: 72rpx; border-radius: 50%; background: var(--c-primary-light); display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.avatar-icon { font-size: 32rpx; }
.member-info { flex: 1; display: flex; flex-direction: column; gap: 4rpx; overflow: hidden; }
.member-name { font-size: 28rpx; font-weight: 600; color: var(--c-text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.member-user { font-size: 22rpx; color: var(--c-text-variant); }
.member-actions { display: flex; align-items: center; gap: 12rpx; flex-shrink: 0; }
.role-select { display: flex; align-items: center; gap: 4rpx; border: 1rpx solid var(--c-divider); border-radius: 8rpx; padding: 8rpx 16rpx; font-size: 22rpx; color: var(--c-text); }
.role-badge { border: 1rpx solid var(--c-divider); border-radius: 8rpx; padding: 8rpx 16rpx; font-size: 22rpx; color: var(--c-text); background: var(--c-surface); }
.remove-btn { border: 1rpx solid var(--c-error); color: var(--c-error); border-radius: 8rpx; padding: 8rpx 16rpx; font-size: 22rpx; }
</style>
