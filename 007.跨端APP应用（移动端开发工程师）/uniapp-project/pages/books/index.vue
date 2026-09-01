<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useBookStore } from '@/stores/book'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { listBooks, createBook, updateBook, deleteBook } from '@/api/books'
import type { Book, BookType } from '@/api/books'

const bookStore = useBookStore()
const toast = useToastStore()
const { t } = useLanguage()

const books = ref<Book[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const busy = ref(false)

const showCreate = ref(false)
const newName = ref('')
const newType = ref<BookType>('personal')
const newDesc = ref('')

const editing = ref<Book | null>(null)
const editDesc = ref('')

const typeOptions: { value: BookType; label: string }[] = [
  { value: 'personal', label: '个人' },
  { value: 'shared', label: '共享' },
  { value: 'business', label: '生意' },
]

async function load() {
  loading.value = true
  error.value = null
  try {
    books.value = await listBooks()
  } catch (e: any) {
    error.value = e?.message ?? ''
  } finally {
    loading.value = false
  }
}

async function handleCreate() {
  if (!newName.value.trim()) return
  busy.value = true
  try {
    await createBook({ name: newName.value.trim(), type: newType.value, description: newDesc.value.trim() || undefined })
    showCreate.value = false
    newName.value = ''
    newDesc.value = ''
    newType.value = 'personal'
    toast.show(t('books.create.success'))
    await load()
  } catch (e: any) {
    toast.show(t('books.create.failPrefix') + (e?.message ?? ''))
  } finally {
    busy.value = false
  }
}

async function handleSwitch(uuid: string) {
  try {
    await bookStore.setCurrent(uuid)
    toast.show(t('books.action.switch') + ' OK')
  } catch (e: any) {
    toast.show(t('books.switch.failPrefix') + (e?.message ?? ''))
  }
}

function openEdit(b: Book) {
  editing.value = b
  editDesc.value = b.description ?? ''
}

async function handleSaveEdit() {
  if (!editing.value) return
  busy.value = true
  try {
    await updateBook(editing.value.uuid, { description: editDesc.value.trim() || null })
    editing.value = null
    toast.show(t('books.edit.success'))
    await load()
  } catch (e: any) {
    toast.show(t('books.edit.failPrefix') + (e?.message ?? ''))
  } finally {
    busy.value = false
  }
}

async function handleDelete(b: Book) {
  uni.showModal({
    title: t('common.confirm'),
    content: t('books.delete.confirm', { name: b.name }),
    success: async (res) => {
      if (!res.confirm) return
      busy.value = true
      try {
        await deleteBook(b.uuid)
        toast.show(t('books.delete.success'))
        await load()
      } catch (e: any) {
        toast.show(t('books.delete.failPrefix') + (e?.message ?? ''))
      } finally {
        busy.value = false
      }
    },
  })
}

function typeIcon(t: BookType): string {
  return t === 'shared' ? 'group' : t === 'business' ? 'business_center' : 'person'
}

onMounted(load)
</script>

<template>
  <view class="page">
    <!-- Header -->
    <view class="header-row">
      <text class="page-title">{{ t('books.heading') }}</text>
      <view class="add-btn" @tap="showCreate = !showCreate">
        <text>+ {{ t('books.create.toggle') }}</text>
      </view>
    </view>

    <!-- Create form -->
    <view v-if="showCreate" class="card">
      <text class="card-title">{{ t('books.create.title') }}</text>
      <view class="form-grid">
        <view class="field">
          <text class="field-label">{{ t('books.create.name') }}</text>
          <input v-model="newName" class="field-input" :placeholder="t('books.create.namePlaceholder')" maxlength="50" />
        </view>
        <view class="field">
          <text class="field-label">{{ t('books.create.type') }}</text>
          <picker mode="selector" :range="typeOptions" range-key="label" :value="0" @change="(e: any) => newType = typeOptions[e.detail.value].value">
            <view class="field-picker">
              <text>{{ typeOptions.find(o => o.value === newType)?.label }}</text>
              <text class="arrow">▼</text>
            </view>
          </picker>
        </view>
        <view class="field full">
          <text class="field-label">{{ t('books.create.description') }}</text>
          <input v-model="newDesc" class="field-input" :placeholder="t('books.create.descPlaceholder')" maxlength="200" />
        </view>
      </view>
      <view class="btn-row">
        <view class="btn-cancel" @tap="showCreate = false" :class="{ disabled: busy }">{{ t('common.cancel') }}</view>
        <view class="btn-confirm" @tap="handleCreate" :class="{ disabled: busy || !newName.trim() }">
          {{ busy ? t('common.loading') : t('common.save') }}
        </view>
      </view>
    </view>

    <!-- Error -->
    <view v-if="error" class="error-box">{{ t('common.error') }}: {{ error }}</view>

    <!-- Loading -->
    <view v-if="loading && !books.length" class="empty">{{ t('common.loading') }}</view>

    <!-- Empty -->
    <view v-if="!loading && books.length === 0" class="empty">{{ t('books.empty') }}</view>

    <!-- Books grid -->
    <view v-if="books.length" class="grid">
      <view v-for="b in books" :key="b.uuid" class="book-card" :class="{ current: bookStore.currentId === b.uuid }">
        <view class="book-top">
          <view class="book-info">
            <text class="book-name">{{ b.name }}</text>
            <text class="book-desc">{{ b.description || t('books.noDesc') }}</text>
          </view>
          <view v-if="b.isDefault" class="badge">{{ t('books.badge.default') }}</view>
        </view>
        <view class="book-meta">
          <text class="meta-icon">{{ typeIcon(b.type) }}</text>
          <text>{{ t(`books.type.${b.type}`) }}</text>
          <text class="sep">·</text>
          <text>{{ t(`books.role.${b.role}`) }}</text>
        </view>
        <view class="book-actions">
          <view v-if="bookStore.currentId !== b.uuid" class="action-btn" @tap="handleSwitch(b.uuid)">
            {{ t('books.action.switch') }}
          </view>
          <view v-else class="action-btn current-btn">{{ t('books.badge.current') }}</view>
          <view class="action-btn" @tap="uni.navigateTo({ url: `/pages/books/members?id=${b.uuid}` })">
            {{ t('books.action.members') }}
          </view>
          <view v-if="b.role === 'owner'" class="action-btn" @tap="openEdit(b)">{{ t('common.edit') }}</view>
          <view v-if="b.role === 'owner' && !b.isDefault" class="action-btn danger" @tap="handleDelete(b)">
            {{ t('common.delete') }}
          </view>
        </view>
      </view>
    </view>

    <!-- Edit modal -->
    <view v-if="editing" class="modal-mask" @tap.self="editing = null">
      <view class="modal-card">
        <text class="modal-title">{{ t('books.edit.title', { name: editing.name }) }}</text>
        <view class="field">
          <text class="field-label">{{ t('books.create.description') }}</text>
          <input v-model="editDesc" class="field-input" maxlength="200" />
        </view>
        <view class="btn-row">
          <view class="btn-cancel" @tap="editing = null">{{ t('common.cancel') }}</view>
          <view class="btn-confirm" @tap="handleSaveEdit" :class="{ disabled: busy }">{{ t('common.save') }}</view>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.header-row { display: flex; justify-content: space-between; align-items: center; }
.page-title { font-size: 36rpx; font-weight: 700; color: var(--c-text); }
.add-btn { display: flex; align-items: center; gap: 8rpx; background: var(--c-primary); color: #fff; border-radius: 12rpx; padding: 12rpx 20rpx; font-size: 26rpx; font-weight: 600; }
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
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; }
.book-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 20rpx; border: 2rpx solid transparent; display: flex; flex-direction: column; gap: 12rpx; }
.book-card.current { border-color: var(--c-primary); }
.book-top { display: flex; justify-content: space-between; align-items: flex-start; gap: 8rpx; }
.book-info { display: flex; flex-direction: column; gap: 4rpx; flex: 1; }
.book-name { font-size: 28rpx; font-weight: 600; color: var(--c-text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.book-desc { font-size: 22rpx; color: var(--c-text-variant); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.badge { background: var(--c-primary-light); color: var(--c-primary); border-radius: 8rpx; padding: 4rpx 10rpx; font-size: 20rpx; font-weight: 600; flex-shrink: 0; }
.book-meta { display: flex; align-items: center; gap: 6rpx; font-size: 22rpx; color: var(--c-text-variant); }
.meta-icon { font-size: 20rpx; }
.sep { color: var(--c-divider); }
.book-actions { display: flex; flex-wrap: wrap; gap: 8rpx; }
.action-btn { padding: 8rpx 16rpx; border: 1rpx solid var(--c-primary); color: var(--c-primary); border-radius: 8rpx; font-size: 22rpx; }
.action-btn.current-btn { background: var(--c-primary-light); font-weight: 600; }
.action-btn.danger { border-color: var(--c-error); color: var(--c-error); }
.modal-mask { position: fixed; inset: 0; background: rgba(0,0,0,0.4); display: flex; align-items: center; justify-content: center; z-index: 100; padding: 32rpx; }
.modal-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 32rpx; width: 100%; max-width: 600rpx; display: flex; flex-direction: column; gap: 20rpx; }
.modal-title { font-size: 32rpx; font-weight: 600; color: var(--c-text); }
</style>
