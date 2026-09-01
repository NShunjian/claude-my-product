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
import { runSilent } from '@/api/http'
import { categoryPresentation } from '@/utils/category-presentation'
import { t } from '@/i18n/dict'
import { exportAll, exportByCategory, exportMonthly } from '@/utils/export'

const auth = useAuthStore()
const theme = useThemeStore()
const { lang, setLang } = useLanguage()
const toast = useToastStore()

// ── version ────────────────────────────────────────────────────────────────
const version = ref('')
const versionState = ref<'loading' | 'ok' | 'error'>('loading')
onMounted(async () => {
  // runSilent:版本探测是「加载信息」,不该触发踢人。token 失效时静默显示 v—
  await runSilent(async () => {
    try {
      const r = await getSystemVersion()
      version.value = r.version
      versionState.value = 'ok'
    } catch {
      versionState.value = 'error'
    }
  })
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
const langIndex = computed(() => LANGS.findIndex(l => l.code === lang.value))
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
const newIcon = ref('')
const newColor = ref('#A0AEC0')

// 图标选择面板:MS Outlined 字形 + 系统 emoji(MS 字体不认识 emoji 时由系统 emoji 字体兜底)
// MS 部分避开预设(餐饮/交通/购物/娱乐/居住/医疗/教育/通讯/工资/兼职/理财/红包等)已用的字形
// 用户不选 → 纯色填充
const iconChoices = [
  'fastfood', 'shopping_cart', 'directions_car', 'local_cafe',
  'cottage', 'fitness_center', 'favorite', 'pets',
  'attach_money', 'savings', 'music_note', 'cake',
  'redeem', 'local_hospital', 'contact_phone', 'volunteer_activism',
  'play_arrow', 'local_movies', 'menu_book', 'spa',
  'self_improvement', 'flight', 'directions_bike', 'thumb_up',
  // emoji 部分(系统字体兜底渲染)
  '🍔', '☕', '🛍️', '🚗', '✈️', '🏠',
  '🎮', '🎵', '💰', '❤️', '🎁', '🐱',
] as const

// 颜色选择面板(12 色 swatch)
const colorChoices = [
  '#ED8936', '#4299E1', '#ED64A6', '#805AD5',
  '#8B6E4E', '#E53E3E', '#319795', '#718096',
  '#A0AEC0', '#38B2AC', '#DD6B20', '#D69E2E',
] as const
const busy = ref(false)
const editing = ref<Category | null>(null)
const editName = ref('')
const editIcon = ref('')
const editColor = ref('')

const catItems = computed(() => {
  const src = catTab.value === 'expense' ? expenseCats.value : incomeCats.value
  return Array.isArray(src) ? src.filter((c): c is Category => !!c && !!c.id).map((c) => {
    const pres = categoryPresentation(c)
    // 自定义分类:用后端存的 icon + color;icon 为空时纯色填充(对齐设计:「没有图片就以给的颜色填充」)
    const disp = c.isPreset
      ? { icon: pres.icon, color: pres.color, solid: false }
      : { icon: c.icon ?? '', color: c.color || pres.color, solid: !(c.icon ?? '') }
    return { ...c, pres, disp }
  }) : []
})

async function loadCategories() {
  if (!auth.token) return
  // runSilent 包住整个调用:H5 刷新后从「资料编辑」返回此页时,onShow/watch immediate 触发
  // loadCategories,如果 token 此时已失效,正常会触发 onInvalid → reLaunch 登录。
  // 这里只是「数据加载」,不是用户主动操作,失败时显示空数据/提示即可,不该把人踢出去。
  await runSilent(async () => {
    try {
      const [exp, inc] = await Promise.all([listCategories('expense'), listCategories('income')])
      expenseCats.value = (exp ?? []).filter((c): c is Category => !!c && !!c.id)
      incomeCats.value = (inc ?? []).filter((c): c is Category => !!c && !!c.id)
    } catch {
      toast.show(t(lang, 'common.error'))
    }
  })
}
watch(() => auth.token, () => { loadCategories() }, { immediate: true })
onShow(() => { loadCategories() })

async function handleCreate() {
  if (!newName.value.trim()) return
  busy.value = true
  try {
    // 没填 icon 时存空 → disp.solid=true 渲染纯色圆(没图片就以颜色填充)
    await createCategory({ type: catTab.value, name: newName.value.trim(), icon: newIcon.value, color: newColor.value })
    showNew.value = false
    newName.value = ''
    newIcon.value = ''
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
  editIcon.value = c.icon ?? ''
  editColor.value = c.color
}

async function handleSaveEdit() {
  if (!editing.value) return
  busy.value = true
  try {
    await updateCategory(editing.value.id, {
      name: editName.value.trim() || undefined,
      // icon 允许显式清空:undefined 跳过 / 空串清空
      icon: editIcon.value,
      color: editColor.value || undefined,
    })
    editing.value = null
    toast.show(t(lang, 'settings.categories.edit.success'))
    await loadCategories()
  } catch (err: any) {
    toast.show(t(lang, 'settings.categories.edit.failPrefix') + (err?.message ?? ''))
  } finally {
    busy.value = false
  }
}

// 编辑弹窗内的删除(取消则保持弹窗打开,删除成功后关闭)
async function onDeleteEditing() {
  if (!editing.value) return
  const target = editing.value
  const confirmed = await new Promise<boolean>(resolve => {
    uni.showModal({
      title: t(lang, 'common.confirm'),
      content: t(lang, 'settings.categories.delete.confirm').replace('{name}', target.name),
      success: res => resolve(res.confirm),
    })
  })
  if (!confirmed) return
  busy.value = true
  try {
    await deleteCategory(target.id)
    toast.show(t(lang, 'settings.categories.delete.success'))
    editing.value = null
    await loadCategories()
  } catch (err: any) {
    toast.show(t(lang, 'settings.categories.delete.failPrefix') + (err?.message ?? ''))
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

// ── data export ─────────────────────────────────────────────────────────────
const exporting = ref<null | 'monthly' | 'category' | 'all'>(null)
const exportErr = ref<string | null>(null)

async function runExport(kind: 'monthly' | 'category' | 'all') {
  exportErr.value = null
  exporting.value = kind
  try {
    if (kind === 'monthly') await exportMonthly()
    else if (kind === 'category') await exportByCategory()
    else await exportAll()
  } catch (err: any) {
    console.error('[export] failed', err)
    exportErr.value = err instanceof Error ? err.message : t(lang, 'settings.data.exportFailPrefix')
  } finally {
    exporting.value = null
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
          <view class="icon-circle icon-circle-lg">
            <text class="mat-icon">category</text>
          </view>
          <text class="card-title">{{ t(lang, 'settings.categories.title') }}</text>
        </view>
        <button class="btn-add" @tap="showNew = !showNew">
          <text class="mat-icon btn-add-icon">add</text>
          <text>{{ t(lang, 'settings.categories.create.toggle') }}</text>
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

      <!-- new category form(改为弹窗,见底部 modal) -->

      <!-- category list -->
      <view class="cat-list">
        <view v-for="(c, idx) in catItems" :key="c?.id ?? `cat-${catTab}-${idx}`" class="cat-item">
          <view
            class="cat-dot"
            :style="c.disp.solid ? { backgroundColor: c.disp.color } : { backgroundColor: c.disp.color + '22' }"
          >
            <text v-if="c.disp.icon" class="cat-icon-glyph" :style="{ color: c.disp.solid ? '#fff' : c.disp.color }">{{ c.disp.icon }}</text>
          </view>
          <view class="cat-info">
            <text class="cat-name">{{ c.name }}</text>
            <text class="cat-color">{{ c.color }}</text>
          </view>
          <view class="cat-actions">
            <view v-if="c.isPreset" class="preset-badge">
              <text>{{ t(lang, 'settings.categories.presetBadge') }}</text>
            </view>
            <view v-else class="preset-badge cat-edit-badge" @tap="openEdit(c)">
              <text>{{ t(lang, 'common.edit') }}</text>
            </view>
          </view>
        </view>
        <view v-if="catItems.length === 0" class="empty">
          <text>{{ t(lang, 'common.empty') }}</text>
        </view>
      </view>
    </view>

    <!-- data management -->
    <view class="card data-card">
      <view class="card-header">
        <view class="icon-circle">
          <text class="mat-icon">database</text>
        </view>
        <text class="card-title">{{ t(lang, 'settings.data.title') }}</text>
      </view>
      <view class="export-grid">
        <view
          :class="['export-btn', exporting ? 'export-disabled' : '']"
          @tap="exporting ? null : runExport('monthly')"
        >
          <text class="mat-icon export-icon">{{ exporting === 'monthly' ? 'progress_activity' : 'calendar_month' }}</text>
          <text class="export-label">{{ exporting === 'monthly' ? t(lang, 'settings.data.exporting') : t(lang, 'settings.data.exportMonthly') }}</text>
        </view>
        <view
          :class="['export-btn', exporting ? 'export-disabled' : '']"
          @tap="exporting ? null : runExport('category')"
        >
          <text class="mat-icon export-icon">{{ exporting === 'category' ? 'progress_activity' : 'category' }}</text>
          <text class="export-label">{{ exporting === 'category' ? t(lang, 'settings.data.exporting') : t(lang, 'settings.data.exportCategory') }}</text>
        </view>
        <view
          :class="['export-btn', exporting ? 'export-disabled' : '']"
          @tap="exporting ? null : runExport('all')"
        >
          <text class="mat-icon export-icon">{{ exporting === 'all' ? 'progress_activity' : 'check_circle' }}</text>
          <text class="export-label">{{ exporting === 'all' ? t(lang, 'settings.data.exporting') : t(lang, 'settings.data.exportAll') }}</text>
        </view>
      </view>
      <text class="export-desc">{{ exportErr ? t(lang, 'settings.data.exportFailPrefix') + exportErr : t(lang, 'settings.data.exportDesc') }}</text>
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
          <text class="mat-icon danger-icon" style="font-size:22px; font-variation-settings:'FILL' 1">shield</text>
          <text class="card-title">{{ t(lang, 'settings.accountSecurity.title') }}</text>
        </view>
        <text class="info-line security-desc">{{ t(lang, 'settings.accountSecurity.desc') }}</text>
        <view class="logout-row">
          <button class="btn-logout" @tap="handleLogout">
            <text class="mat-icon" style="font-size:18px; font-variation-settings:'FILL' 1">logout</text>
            {{ t(lang, 'settings.accountSecurity.logout') }}
          </button>
        </view>
      </view>
    </view>
  </scroll-view>

  <!-- new category modal -->
  <view v-if="showNew" class="modal-mask" @tap.self="showNew = false">
    <view class="modal">
      <text class="modal-title">{{ t(lang, 'settings.categories.create.toggle') }}</text>
      <view class="form-field">
        <text class="field-label">{{ t(lang, 'settings.categories.field.name') }}</text>
        <input v-model="newName" class="form-input" maxlength="20" placeholder="" />
      </view>
      <view class="form-field">
        <text class="field-label">{{ t(lang, 'settings.categories.field.icon') }}</text>
        <view class="icon-picker-grid">
          <view
            v-for="icon in iconChoices" :key="icon"
            :class="['icon-pick', newIcon === icon ? 'icon-pick-active' : '']"
            :style="newIcon === icon ? { color: newColor } : {}"
            @tap="newIcon = icon"
          >
            <text class="mat-icon">{{ icon }}</text>
          </view>
        </view>
        <text class="field-hint">不选图标 = 纯色填充</text>
      </view>
      <view class="form-field">
        <text class="field-label">{{ t(lang, 'settings.categories.field.color') }}</text>
        <view class="color-picker-grid">
          <view
            v-for="color in colorChoices" :key="color"
            :class="['color-pick', newColor === color ? 'color-pick-active' : '']"
            :style="{ backgroundColor: color }"
            @tap="newColor = color"
          >
            <text v-if="newColor === color" class="mat-icon color-check">check</text>
          </view>
        </view>
      </view>
      <view class="modal-actions">
        <button class="btn-outline-sm" @tap="showNew = false">{{ t(lang, 'common.cancel') }}</button>
        <view class="modal-actions-right">
          <button class="btn-primary-sm" :disabled="busy || !newName.trim()" @tap="handleCreate">{{ t(lang, 'common.save') }}</button>
        </view>
      </view>
    </view>
  </view>

  <!-- edit modal -->
  <view v-if="editing" class="modal-mask" @tap.self="editing = null">
    <view class="modal">
      <text class="modal-title">{{ t(lang, 'settings.categories.edit.title') }}</text>
      <view class="form-field">
        <text class="field-label">{{ t(lang, 'settings.categories.field.name') }}</text>
        <input v-model="editName" class="form-input" maxlength="20" />
      </view>
      <view class="form-field">
        <text class="field-label">{{ t(lang, 'settings.categories.field.icon') }}</text>
        <view class="icon-picker-grid">
          <view
            v-for="icon in iconChoices" :key="icon"
            :class="['icon-pick', editIcon === icon ? 'icon-pick-active' : '']"
            :style="editIcon === icon ? { color: editColor } : {}"
            @tap="editIcon = icon"
          >
            <text class="mat-icon">{{ icon }}</text>
          </view>
        </view>
        <text class="field-hint">不选图标 = 纯色填充</text>
      </view>
      <view class="form-field">
        <text class="field-label">{{ t(lang, 'settings.categories.field.color') }}</text>
        <view class="color-picker-grid">
          <view
            v-for="color in colorChoices" :key="color"
            :class="['color-pick', editColor === color ? 'color-pick-active' : '']"
            :style="{ backgroundColor: color }"
            @tap="editColor = color"
          >
            <text v-if="editColor === color" class="mat-icon color-check">check</text>
          </view>
        </view>
      </view>
      <view class="modal-actions">
        <button class="btn-danger-sm" :disabled="busy" @tap="onDeleteEditing">{{ t(lang, 'common.delete') }}</button>
        <view class="modal-actions-right">
          <button class="btn-outline-sm" @tap="editing = null">{{ t(lang, 'common.cancel') }}</button>
          <button class="btn-primary-sm" :disabled="busy" @tap="handleSaveEdit">{{ t(lang, 'common.save') }}</button>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { height: 100vh; background: var(--c-bg); padding: 24rpx; box-sizing: border-box; }
.section { margin-bottom: 24rpx; }
.heading { font-size: 32rpx; font-weight: 700; color: var(--c-text); }
.row { display: flex; flex-direction: column; gap: 24rpx; margin-bottom: 24rpx; }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 32rpx; border: 1px solid var(--c-divider); }

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
/* header 自带的 margin-bottom 会在 flex 行里把按钮和标题错开,这里清零保证垂直对齐 */
.card-header-row .card-header { margin-bottom: 0; }
.cat-tabs { display: flex; gap: 16rpx; margin-bottom: 0; }
.cat-tab { padding: 16rpx 32rpx; border-radius: 12rpx; font-size: 28rpx; color: var(--c-text-variant); transition: all 0.2s; }
.cat-tab-active { background: var(--c-primary-light); color: var(--c-primary); font-weight: 600; }
.new-form { border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 20rpx; margin-bottom: 16rpx; }
.form-row { display: flex; gap: 16rpx; flex-wrap: wrap; margin-bottom: 16rpx; }
.form-field { display: flex; flex-direction: column; gap: 8rpx; flex: 1; min-width: 100rpx; }
.field-label { font-size: 22rpx; color: var(--c-text-variant); }
.form-input { border: 1px solid var(--c-divider); border-radius: 8rpx; padding: 12rpx; background: var(--c-bg); color: var(--c-text); font-size: 26rpx; }
.field-hint { font-size: 22rpx; color: var(--c-text-variant); margin-top: 4rpx; }
.icon-picker-grid { display: flex; flex-wrap: wrap; gap: 12rpx; }
.icon-pick { width: 80rpx; height: 80rpx; border-radius: 12rpx; border: 1px solid var(--c-divider); background: var(--c-bg); display: flex; align-items: center; justify-content: center; color: var(--c-text); transition: all 0.15s; }
.icon-pick-active { border-color: var(--c-primary); border-width: 2rpx; background: var(--c-primary-light); }
.icon-pick .mat-icon { font-size: 40rpx; }
.color-picker-grid { display: flex; flex-wrap: wrap; gap: 12rpx; }
.color-pick { width: 72rpx; height: 72rpx; border-radius: 50%; position: relative; border: 2rpx solid transparent; transition: all 0.15s; }
.color-pick-active { border-color: var(--c-text); }
.color-check { font-size: 36rpx; color: #fff; line-height: 1; }
.form-actions { display: flex; gap: 12rpx; justify-content: flex-end; }
/* 九宫格:4 列居中,左右两侧间距对称 */
.cat-list { display: flex; flex-wrap: wrap; }
.cat-item { width: 16.66%; box-sizing: border-box; display: flex; flex-direction: column; align-items: center; gap: 4rpx; padding: 16rpx 0; }
.cat-dot { width: 64rpx; height: 64rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.cat-icon-glyph { font-size: 32rpx; font-family: 'Material Symbols Outlined', sans-serif; font-weight: normal; font-style: normal; line-height: 1; }
.cat-info { display: flex; flex-direction: column; align-items: center; min-width: 0; max-width: 100%; }
.cat-name { font-size: 24rpx; color: var(--c-text); display: block; text-align: center; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 100%; }
.cat-color { font-size: 20rpx; color: var(--c-text-variant); display: block; margin-top: 2rpx; text-align: center; }
.cat-actions { display: flex; align-items: center; justify-content: center; gap: 8rpx; flex-wrap: wrap; }
.preset-badge { padding: 6rpx 16rpx; border-radius: 999rpx; background: var(--c-surface); font-size: 22rpx; color: var(--c-text-variant); }
.cat-edit-badge { border: 1px solid var(--c-divider); color: var(--c-text); background: transparent; }
.empty { padding: 48rpx 0; text-align: center; font-size: 26rpx; color: var(--c-text-variant); }
.btn-primary-sm { background: var(--c-primary); color: #fff; border-radius: 8rpx; padding: 10rpx 20rpx; font-size: 24rpx; border: none; display: inline-flex; align-items: center; gap: 4rpx; }
/* 自定义分类 header 的新增按钮(对齐设计图:右上深蓝横向圆角矩形,+ 与文字同排) */
/* margin:0 清掉 uni-button 默认的 margin:auto,否则 flex 行里按钮不贴右、与「预设」右边对不齐 */
.btn-add { display: inline-flex; align-items: center; justify-content: center; gap: 12rpx; background: #005394; color: #fff; border: none; border-radius: 12rpx; padding: 22rpx 36rpx; font-size: 28rpx; line-height: 1; margin: 0; }
.btn-add::after { border: none; }
.btn-add-icon { font-size: 32rpx; }
.icon-circle-lg { width: 96rpx; height: 96rpx; }
.icon-circle-lg .mat-icon { font-size: 44rpx; }
.btn-outline-sm { border: 1px solid var(--c-divider); border-radius: 8rpx; padding: 10rpx 20rpx; font-size: 24rpx; color: var(--c-text); background: transparent; }
.btn-danger-sm { border: 1px solid var(--c-error); color: var(--c-error); border-radius: 8rpx; padding: 10rpx 20rpx; font-size: 24rpx; background: transparent; }
/* 编辑弹窗底部全宽删除按钮 */
.btn-danger-full { width: 100%; border: 1px solid var(--c-error); color: var(--c-error); border-radius: 12rpx; padding: 20rpx; font-size: 26rpx; background: transparent; margin-top: 24rpx; }
.btn-danger-full::after { border: none; }

/* data management */
.export-grid { display: flex; flex-direction: row; gap: 16rpx; margin-bottom: 24rpx; }
.export-btn { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 16rpx; padding: 40rpx 16rpx; border: 1px solid var(--c-divider); border-radius: 16rpx; background: var(--c-surface); transition: all 0.2s; }
.export-disabled { opacity: 0.5; }
.export-icon { font-size: 56rpx; color: var(--c-text-variant); font-weight: 300; }
.export-label { font-size: 26rpx; color: var(--c-text); text-align: center; }
.export-desc { display: block; text-align: center; font-size: 24rpx; color: var(--c-text-variant); }

/* about */
.about-logo-row { display: flex; gap: 16rpx; margin-bottom: 32rpx; }
.about-logo { width: 112rpx; height: 128rpx; border-radius: 12rpx; background: var(--c-primary-light); display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.about-logo-text { font-size: 56rpx; font-weight: 700; color: var(--c-primary); }
.about-version { font-size: 30rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 4rpx; }
.about-links { display: flex; gap: 32rpx; padding-top: 16rpx; border-top: 1px solid var(--c-divider); }
.link { font-size: 26rpx; color: var(--c-primary); }

/* security */
.security-card { display: flex; flex-direction: column; }
.security-desc { margin-bottom: 32rpx; font-size: 26rpx; color: var(--c-text-variant); line-height: 1.6; }
.logout-row { display: flex; justify-content: flex-end; margin-top: auto; }
.btn-logout { display: inline-flex; align-items: center; justify-content: center; gap: 8rpx; height: 72rpx; line-height: 1; border: 2px solid var(--c-error); color: var(--c-error); border-radius: 12rpx; padding: 0 24rpx; font-size: 28rpx; background: transparent; margin: 0; }
.btn-logout::after { border: none; }
.primary-icon { color: var(--c-primary); }
.danger-icon { color: var(--c-error); }

/* modal */
.modal-mask { position: fixed; inset: 0; background: rgba(0,0,0,0.4); z-index: 999; display: flex; align-items: center; justify-content: center; padding: 32rpx; }
.modal { background: var(--c-bg-card); border-radius: 20rpx; padding: 40rpx; width: 100%; max-width: 600rpx; max-height: 80vh; overflow-y: auto; }
.modal-title { font-size: 32rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 24rpx; }
.modal-actions { display: flex; gap: 16rpx; justify-content: space-between; align-items: center; margin-top: 24rpx; }
.modal-actions-right { display: flex; gap: 16rpx; }
/* 清掉 uni-button 默认 margin:auto,否则 space-between 下按钮被拉向中间、左右不对称 */
.modal-actions button { margin: 0; }
</style>
