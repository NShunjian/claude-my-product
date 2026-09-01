<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useAuthStore } from '@/stores/auth'
import { useThemeStore } from '@/stores/theme'
import { useLanguage, LANGS } from '@/i18n/useLanguage'
import { useToastStore } from '@/stores/toast'
import { getSystemVersion } from '@/api/version'
import { listCategories, createCategory, updateCategory, deleteCategory } from '@/api/categories'
import type { Category, CategoryType } from '@/api/categories'
import { t } from '@/i18n/dict'

const auth = useAuthStore()
const theme = useThemeStore()
const { lang, setLang } = useLanguage()
const toast = useToastStore()

// ── version ────────────────────────────────────────────────────────────────
const version = ref('')
const versionState = ref<'loading' | 'ok' | 'error'>('loading')
onMounted(async () => {
  try {
    const r = await getSystemVersion()
    version.value = r.version
    versionState.value = 'ok'
  } catch {
    versionState.value = 'error'
  }
})

// ── helpers ────────────────────────────────────────────────────────────────
const genderText = computed(() => {
  const g = auth.user?.gender
  if (g === 'male') return t(lang, 'settings.userCard.gender.male')
  if (g === 'female') return t(lang, 'settings.userCard.gender.female')
  if (g === 'other') return t(lang, 'settings.userCard.gender.other')
  return t(lang, 'settings.userCard.gender.none')
})
const ageText = computed(() =>
  auth.user?.age != null ? String(auth.user.age) : t(lang, 'settings.userCard.age.none')
)

function navigateToEdit() {
  uni.navigateTo({ url: '/pages/profile/edit' })
}

async function handleLogout() {
  await auth.logout()
  uni.reLaunch({ url: '/pages/login/index' })
}

// ── theme ──────────────────────────────────────────────────────────────────
const themeOptions = [
  { mode: 'system' as const, labelKey: 'settings.prefs.theme.system' },
  { mode: 'light' as const, labelKey: 'settings.prefs.theme.light' },
  { mode: 'dark' as const, labelKey: 'settings.prefs.theme.dark' },
]

// ── language picker ────────────────────────────────────────────────────────
const langIndex = computed(() => LANGS.findIndex(l => l.code === lang))
function onLangChange(e: any) {
  const idx = Number(e.detail.value)
  setLang(LANGS[idx].code)
}

// ── categories ────────────────────────────────────────────────────────────
const expenseCats = ref<Category[]>([])
const incomeCats = ref<Category[]>([])
const catTab = ref<CategoryType>('expense')
const showNew = ref(false)
const newName = ref('')
const newIcon = ref('🏷️')
const newColor = ref('#A0AEC0')
const busy = ref(false)
const editing = ref<Category | null>(null)
const editName = ref('')
const editColor = ref('')

const catItems = computed(() => {
  const src = catTab.value === 'expense' ? expenseCats.value : incomeCats.value
  return Array.isArray(src) ? src.filter((c): c is Category => !!c && !!c.id) : []
})

async function loadCategories() {
  if (!auth.token) return
  try {
    const [exp, inc] = await Promise.all([listCategories('expense'), listCategories('income')])
    expenseCats.value = (exp ?? []).filter((c): c is Category => !!c && !!c.id)
    incomeCats.value = (inc ?? []).filter((c): c is Category => !!c && !!c.id)
  } catch {
    toast.show(t(lang, 'common.error'))
  }
}
watch(() => auth.token, () => { loadCategories() }, { immediate: true })
onShow(() => { loadCategories() })

async function handleCreate() {
  if (!newName.value.trim()) return
  busy.value = true
  try {
    await createCategory({ type: catTab.value, name: newName.value.trim(), icon: newIcon.value || '🏷️', color: newColor.value })
    showNew.value = false
    newName.value = ''
    newIcon.value = '🏷️'
    newColor.value = '#A0AEC0'
    toast.show(t(lang, 'settings.categories.create.success'))
    await loadCategories()
  } catch (err: any) {
    toast.show(t(lang, 'settings.categories.create.failPrefix') + (err?.message ?? ''))
  } finally {
    busy.value = false
  }
}

function openEdit(c: Category) {
  editing.value = c
  editName.value = c.name
  editColor.value = c.color
}

async function handleSaveEdit() {
  if (!editing.value) return
  busy.value = true
  try {
    await updateCategory(editing.value.id, { name: editName.value.trim() || undefined, color: editColor.value || undefined })
    editing.value = null
    toast.show(t(lang, 'settings.categories.edit.success'))
    await loadCategories()
  } catch (err: any) {
    toast.show(t(lang, 'settings.categories.edit.failPrefix') + (err?.message ?? ''))
  } finally {
    busy.value = false
  }
}

async function handleDelete(c: Category) {
  const confirmed = await new Promise<boolean>(resolve => {
    uni.showModal({
      title: t(lang, 'common.confirm'),
      content: t(lang, 'settings.categories.delete.confirm').replace('{name}', c.name),
      success: res => resolve(res.confirm),
    })
  })
  if (!confirmed) return
  busy.value = true
  try {
    await deleteCategory(c.id)
    toast.show(t(lang, 'settings.categories.delete.success'))
    await loadCategories()
  } catch (err: any) {
    toast.show(t(lang, 'settings.categories.delete.failPrefix') + (err?.message ?? ''))
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <scroll-view scroll-y class="page">
    <!-- heading -->
    <view class="section">
      <text class="heading">{{ t(lang, 'settings.heading') }}</text>
    </view>

    <!-- top row: user card + system prefs -->
    <view class="row">
      <!-- user card -->
      <view class="card user-card">
        <!-- avatar ring -->
        <view class="avatar-wrap">
          <view class="avatar-circle">
            <image v-if="auth.user?.avatar" :src="auth.user.avatar" class="avatar-img" mode="aspectFill" />
            <text v-else class="avatar-icon">person</text>
          </view>
        </view>

        <view v-if="auth.user" class="user-info">
          <text class="display-name">{{ auth.user.displayName || auth.user.username }}</text>
          <text class="info-line">{{ t(lang, 'settings.userCard.accountLabel') }}：{{ auth.user.username }}</text>
          <text class="info-line">{{ t(lang, 'settings.userCard.freeVersion') }}</text>
          <text class="info-line">{{ t(lang, 'settings.userCard.genderLabel') }}：{{ genderText }}</text>
          <text class="info-line mb-6">{{ t(lang, 'settings.userCard.ageLabel') }}：{{ ageText }}</text>
          <button class="btn-outline" @tap="navigateToEdit">{{ t(lang, 'settings.userCard.editProfile') }}</button>
        </view>
        <view v-else class="user-info">
          <text class="info-line">{{ t(lang, 'settings.userCard.accountLabel') }}：—</text>
        </view>
      </view>

      <!-- system prefs -->
      <view class="card prefs-card">
        <view class="card-header">
          <view class="icon-circle">
            <text class="mat-icon">tune</text>
          </view>
          <text class="card-title">{{ t(lang, 'settings.prefs.title') }}</text>
        </view>

        <!-- theme segmented -->
        <view class="pref-row">
          <view class="pref-label">
            <text class="pref-title">{{ t(lang, 'settings.prefs.theme.label') }}</text>
            <text class="pref-desc">{{ t(lang, 'settings.prefs.theme.desc') }}</text>
          </view>
          <view class="seg-ctrl">
            <view
              v-for="opt in themeOptions" :key="opt.mode"
              :class="['seg-btn', theme.mode === opt.mode ? 'seg-active' : '']"
              @tap="theme.setMode(opt.mode)"
            >
              <text :class="theme.mode === opt.mode ? 'seg-txt-active' : 'seg-txt'">{{ t(lang, opt.labelKey) }}</text>
            </view>
          </view>
        </view>

        <view class="divider" />

        <!-- language picker -->
        <view class="pref-row">
          <view class="pref-label">
            <text class="pref-title">{{ t(lang, 'settings.prefs.lang.label') }}</text>
            <text class="pref-desc">{{ t(lang, 'settings.prefs.lang.desc') }}</text>
          </view>
          <picker mode="selector" :range="LANGS.map(l => l.label)" :value="langIndex" @change="onLangChange">
            <view class="lang-picker">
              <text>{{ LANGS[langIndex]?.label }}</text>
              <text class="mat-icon" style="font-size:20px">expand_more</text>
            </view>
          </picker>
        </view>
      </view>
    </view>

    <!-- categories section -->
    <view class="card">
      <view class="card-header-row">
        <view class="card-header">
          <view class="icon-circle">
            <text class="mat-icon">category</text>
          </view>
          <text class="card-title">{{ t(lang, 'settings.categories.title') }}</text>
        </view>
        <button class="btn-primary-sm" @tap="showNew = !showNew">
          <text class="mat-icon" style="font-size:16px">add</text>
          {{ t(lang, 'settings.categories.create.toggle') }}
        </button>
      </view>

      <!-- tabs -->
      <view class="cat-tabs">
        <view :class="['cat-tab', catTab === 'expense' ? 'cat-tab-active' : '']" @tap="catTab = 'expense'">
          <text>{{ t(lang, 'settings.categories.tab.expense') }}</text>
        </view>
        <view :class="['cat-tab', catTab === 'income' ? 'cat-tab-active' : '']" @tap="catTab = 'income'">
          <text>{{ t(lang, 'settings.categories.tab.income') }}</text>
        </view>
      </view>

      <!-- new category form -->
      <view v-if="showNew" class="new-form">
        <view class="form-row">
          <view class="form-field">
            <text class="field-label">{{ t(lang, 'settings.categories.field.name') }}</text>
            <input v-model="newName" class="form-input" maxlength="20" placeholder="" />
          </view>
          <view class="form-field" style="max-width:120px">
            <text class="field-label">{{ t(lang, 'settings.categories.field.icon') }}</text>
            <input v-model="newIcon" class="form-input" maxlength="32" placeholder="" />
          </view>
          <view class="form-field" style="max-width:80px">
            <text class="field-label">{{ t(lang, 'settings.categories.field.color') }}</text>
            <input v-model="newColor" class="form-input" type="color" style="height:36px" />
          </view>
        </view>
        <view class="form-actions">
          <button class="btn-outline-sm" @tap="showNew = false">{{ t(lang, 'common.cancel') }}</button>
          <button class="btn-primary-sm" :disabled="busy || !newName.trim()" @tap="handleCreate">{{ t(lang, 'common.save') }}</button>
        </view>
      </view>

      <!-- category list -->
      <view class="cat-list">
        <view v-for="(c, idx) in catItems" :key="c?.id ?? `cat-${catTab}-${idx}`" class="cat-item">
          <view class="cat-dot" :style="{ backgroundColor: c.color + '33' }">
            <text style="font-size:16px">{{ c.icon }}</text>
          </view>
          <view class="cat-info">
            <text class="cat-name">{{ c.name }}</text>
            <text class="cat-color">{{ c.color }}</text>
          </view>
          <view class="cat-actions">
            <view v-if="c.isPreset" class="preset-badge">
              <text>{{ t(lang, 'settings.categories.presetBadge') }}</text>
            </view>
            <template v-else>
              <button class="btn-outline-sm" @tap="openEdit(c)">{{ t(lang, 'common.edit') }}</button>
              <button class="btn-danger-sm" :disabled="busy" @tap="handleDelete(c)">{{ t(lang, 'common.delete') }}</button>
            </template>
          </view>
        </view>
        <view v-if="catItems.length === 0" class="empty">
          <text>{{ t(lang, 'common.empty') }}</text>
        </view>
      </view>
    </view>

    <!-- bottom row: about + account security -->
    <view class="row">
      <!-- about -->
      <view class="card about-card">
        <view class="card-header">
          <text class="mat-icon primary-icon" style="font-size:22px">info</text>
          <text class="card-title">{{ t(lang, 'settings.about.title') }}</text>
        </view>
        <view class="about-logo-row">
          <view class="about-logo">
            <text class="about-logo-text">Q</text>
          </view>
          <view>
            <text class="about-version" :busy="versionState === 'loading'">
              {{ versionState === 'loading' ? 'QingZhang v…' : versionState === 'error' ? 'QingZhang v—' : `QingZhang v${version}` }}
            </text>
            <text class="info-line">
              {{ versionState === 'ok' ? t(lang, 'settings.about.currentVersion') : versionState === 'error' ? t(lang, 'settings.about.versionUnavailable') : t(lang, 'settings.about.fetchingVersion') }}
            </text>
          </view>
        </view>
        <view class="about-links">
          <text class="link">{{ t(lang, 'settings.about.terms') }}</text>
          <text class="link">{{ t(lang, 'settings.about.privacy') }}</text>
        </view>
      </view>

      <!-- account security -->
      <view class="card security-card">
        <view class="card-header">
          <text class="mat-icon danger-icon" style="font-size:22px">shield</text>
          <text class="card-title">{{ t(lang, 'settings.accountSecurity.title') }}</text>
        </view>
        <text class="info-line security-desc">{{ t(lang, 'settings.accountSecurity.desc') }}</text>
        <view class="logout-row">
          <button class="btn-logout" @tap="handleLogout">
            <text class="mat-icon" style="font-size:18px">logout</text>
            {{ t(lang, 'settings.accountSecurity.logout') }}
          </button>
        </view>
      </view>
    </view>
  </scroll-view>

  <!-- edit modal -->
  <view v-if="editing" class="modal-mask" @tap.self="editing = null">
    <view class="modal">
      <text class="modal-title">{{ t(lang, 'settings.categories.edit.title') }}</text>
      <view class="form-field">
        <text class="field-label">{{ t(lang, 'settings.categories.field.name') }}</text>
        <input v-model="editName" class="form-input" maxlength="20" />
      </view>
      <view class="form-field">
        <text class="field-label">{{ t(lang, 'settings.categories.field.color') }}</text>
        <input v-model="editColor" class="form-input" type="color" style="height:40px" />
      </view>
      <view class="modal-actions">
        <button class="btn-outline-sm" @tap="editing = null">{{ t(lang, 'common.cancel') }}</button>
        <button class="btn-primary-sm" :disabled="busy" @tap="handleSaveEdit">{{ t(lang, 'common.save') }}</button>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { height: 100vh; background: var(--c-bg); padding: 24rpx; box-sizing: border-box; }
.section { margin-bottom: 24rpx; }
.heading { font-size: 32rpx; font-weight: 700; color: var(--c-text); }
.row { display: flex; flex-direction: column; gap: 24rpx; margin-bottom: 24rpx; }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 32rpx; }

/* user card */
.user-card { display: flex; flex-direction: column; align-items: center; text-align: center; }
.avatar-wrap { margin-bottom: 16rpx; }
.avatar-circle { width: 160rpx; height: 160rpx; border-radius: 50%; background: var(--c-primary-light); display: flex; align-items: center; justify-content: center; overflow: hidden; }
.avatar-img { width: 100%; height: 100%; }
.avatar-icon { font-size: 80rpx; color: var(--c-primary); }
.user-info { width: 100%; }
.display-name { font-size: 36rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 8rpx; }
.info-line { font-size: 26rpx; color: var(--c-text-variant); display: block; margin-bottom: 4rpx; }
.mb-6 { margin-bottom: 24rpx; }
.btn-outline { border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 16rpx; font-size: 28rpx; color: var(--c-text); background: transparent; width: 100%; }

/* prefs card */
.prefs-card {}
.card-header { display: flex; align-items: center; gap: 16rpx; margin-bottom: 32rpx; }
.icon-circle { width: 72rpx; height: 72rpx; border-radius: 50%; background: var(--c-primary-light); display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.mat-icon { font-family: 'Material Symbols Outlined'; font-size: 20px; font-weight: normal; font-style: normal; }
.card-title { font-size: 30rpx; font-weight: 600; color: var(--c-text); }
.pref-row { display: flex; align-items: center; justify-content: space-between; padding: 24rpx 0; }
.pref-label {}
.pref-title { font-size: 28rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 4rpx; }
.pref-desc { font-size: 24rpx; color: var(--c-text-variant); }
.divider { height: 1px; background: var(--c-divider); }
.seg-ctrl { display: flex; border: 1px solid var(--c-divider); border-radius: 12rpx; overflow: hidden; background: var(--c-surface); }
.seg-btn { padding: 12rpx 20rpx; transition: all 0.2s; }
.seg-txt { font-size: 24rpx; color: var(--c-text-variant); }
.seg-txt-active { font-size: 24rpx; color: var(--c-text); font-weight: 600; }
.seg-active { background: var(--c-bg-card); }
.lang-picker { display: flex; align-items: center; gap: 8rpx; background: var(--c-surface); border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 12rpx 20rpx; }

/* categories */
.card-header-row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 24rpx; }
.cat-tabs { display: flex; gap: 16rpx; margin-bottom: 16rpx; }
.cat-tab { padding: 12rpx 24rpx; border-radius: 12rpx; font-size: 26rpx; color: var(--c-text-variant); transition: all 0.2s; }
.cat-tab-active { background: var(--c-primary-light); color: var(--c-primary); font-weight: 600; }
.new-form { border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 20rpx; margin-bottom: 16rpx; }
.form-row { display: flex; gap: 16rpx; flex-wrap: wrap; margin-bottom: 16rpx; }
.form-field { display: flex; flex-direction: column; gap: 8rpx; flex: 1; min-width: 100rpx; }
.field-label { font-size: 22rpx; color: var(--c-text-variant); }
.form-input { border: 1px solid var(--c-divider); border-radius: 8rpx; padding: 12rpx; background: var(--c-bg); color: var(--c-text); font-size: 26rpx; }
.form-actions { display: flex; gap: 12rpx; justify-content: flex-end; }
.cat-list {}
.cat-item { display: flex; align-items: center; gap: 16rpx; padding: 16rpx 0; border-top: 1px solid var(--c-divider); }
.cat-dot { width: 64rpx; height: 64rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.cat-info { flex: 1; min-width: 0; }
.cat-name { font-size: 26rpx; color: var(--c-text); display: block; }
.cat-color { font-size: 22rpx; color: var(--c-text-variant); }
.cat-actions { display: flex; align-items: center; gap: 8rpx; flex-shrink: 0; }
.preset-badge { padding: 6rpx 16rpx; border-radius: 999rpx; background: var(--c-surface); font-size: 22rpx; color: var(--c-text-variant); }
.empty { padding: 48rpx 0; text-align: center; font-size: 26rpx; color: var(--c-text-variant); }
.btn-primary-sm { background: var(--c-primary); color: #fff; border-radius: 8rpx; padding: 10rpx 20rpx; font-size: 24rpx; border: none; display: inline-flex; align-items: center; gap: 4rpx; }
.btn-outline-sm { border: 1px solid var(--c-divider); border-radius: 8rpx; padding: 10rpx 20rpx; font-size: 24rpx; color: var(--c-text); background: transparent; }
.btn-danger-sm { border: 1px solid var(--c-error); color: var(--c-error); border-radius: 8rpx; padding: 10rpx 20rpx; font-size: 24rpx; background: transparent; }

/* about */
.about-logo-row { display: flex; gap: 16rpx; margin-bottom: 32rpx; }
.about-logo { width: 112rpx; height: 128rpx; border-radius: 12rpx; background: var(--c-primary-light); display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.about-logo-text { font-size: 56rpx; font-weight: 700; color: var(--c-primary); }
.about-version { font-size: 30rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 4rpx; }
.about-links { display: flex; gap: 32rpx; padding-top: 16rpx; border-top: 1px solid var(--c-divider); }
.link { font-size: 26rpx; color: var(--c-primary); }

/* security */
.security-desc { margin-bottom: 32rpx; font-size: 26rpx; color: var(--c-text-variant); line-height: 1.6; }
.logout-row { display: flex; justify-content: flex-end; }
.btn-logout { display: inline-flex; align-items: center; gap: 8rpx; border: 2px solid var(--c-error); color: var(--c-error); border-radius: 12rpx; padding: 16rpx 24rpx; font-size: 28rpx; background: transparent; }
.primary-icon { color: var(--c-primary); }
.danger-icon { color: var(--c-error); }

/* modal */
.modal-mask { position: fixed; inset: 0; background: rgba(0,0,0,0.4); z-index: 999; display: flex; align-items: center; justify-content: center; padding: 32rpx; }
.modal { background: var(--c-bg-card); border-radius: 20rpx; padding: 40rpx; width: 100%; max-width: 600rpx; }
.modal-title { font-size: 32rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 24rpx; }
.modal-actions { display: flex; gap: 16rpx; justify-content: flex-end; margin-top: 24rpx; }
</style>
