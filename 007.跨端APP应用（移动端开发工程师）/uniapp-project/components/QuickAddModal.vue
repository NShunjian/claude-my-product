<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useBookStore } from '@/stores/book'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { listAccounts } from '@/api/accounts'
import { listCategories } from '@/api/categories'
import { createRecord } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import type { RecordType } from '@/api/records'
import { todayLocal } from '@/utils/date'
import { formatAmount } from '@/utils/finance'

/**
 * 快速记账弹框 —— 对齐 frontend-react-java RecordModal
 * Props: show (v-model:show), kind ('expense' | 'income'), 可选 categories/accounts 传入避免重复请求
 * Emits: update:show, saved
 */
const props = withDefaults(
  defineProps<{
    show: boolean
    kind?: 'expense' | 'income'
    categories?: Category[]
    accounts?: Account[]
  }>(),
  { kind: 'expense', categories: () => [], accounts: () => [] },
)
const emit = defineEmits<{
  (e: 'update:show', v: boolean): void
  (e: 'saved'): void
}>()

const book = useBookStore()
const toast = useToastStore()
const { t } = useLanguage()

const activeTab = ref<RecordType>(props.kind)
const note = ref('')
const categoryId = ref<string>('')
const accountId = ref<string>('')
const recordDate = ref(todayLocal())
const expression = ref('')
const showSuccess = ref(false)
const submitting = ref(false)
const errorMsg = ref<string | null>(null)

// 本地缓存:分类与账户(若父组件没传则自己拉)
const catsLocal = ref<Category[]>([])
const acctsLocal = ref<Account[]>([])
const catsActive = computed<Category[]>(() => props.categories.length ? props.categories : catsLocal.value)
const acctsActive = computed<Account[]>(() => props.accounts.length ? props.accounts : acctsLocal.value)
const visibleCats = computed(() => catsActive.value.filter(c => c.type === activeTab.value))

function pickDefaultAccount(): string {
  const list = acctsActive.value
  const def = list.find(a => a.isDefault)
  return def?.id ?? list[0]?.id ?? ''
}

async function ensureData() {
  if (!book.current) return
  if (!props.categories.length && catsLocal.value.length === 0) {
    const [e, i] = await Promise.all([listCategories('expense'), listCategories('income')])
    catsLocal.value = [...e, ...i]
  }
  if (!props.accounts.length && acctsLocal.value.length === 0) {
    acctsLocal.value = await listAccounts({ bookId: book.current.uuid })
  }
}

function reset() {
  showSuccess.value = false
  submitting.value = false
  errorMsg.value = null
  expression.value = ''
  note.value = ''
  recordDate.value = todayLocal()
  activeTab.value = props.kind
}

watch(
  () => props.show,
  (v) => {
    if (v) {
      reset()
      ensureData().then(() => {
        if (!categoryId.value) {
          categoryId.value = visibleCats.value[0]?.id ?? ''
        }
        if (!accountId.value) {
          accountId.value = pickDefaultAccount()
        }
      })
    }
  },
)

// 切 tab 时把分类重置到该类型的第一个
watch(activeTab, () => {
  categoryId.value = visibleCats.value[0]?.id ?? ''
  errorMsg.value = null
})

function close() {
  if (submitting.value) return
  emit('update:show', false)
}

function pressKey(key: string) {
  if (key === 'back') {
    expression.value = expression.value.slice(0, -1)
    return
  }
  if (key === 'op') {
    if (!expression.value) { expression.value = '0+'; return }
    const last = expression.value.slice(-1)
    if (last === '+' || last === '-') {
      expression.value = expression.value.slice(0, -1) + '+'
    } else {
      expression.value += '+'
    }
    return
  }
  if (key === '.') {
    const seg = expression.value.split(/[+\-]/).pop() ?? ''
    if (seg.includes('.')) return
    expression.value += '.'
    return
  }
  if (key === 'confirm') {
    submit()
    return
  }
  expression.value = (expression.value + key).slice(0, 12)
}

function computeAmount(): number {
  if (!expression.value) return 0
  if (!expression.value.includes('+')) {
    const n = parseFloat(expression.value)
    return Number.isFinite(n) ? n : 0
  }
  return expression.value.split('+').reduce((s, x) => s + (parseFloat(x) || 0), 0)
}

function displayAmount(): string {
  return formatAmount(computeAmount()).replace('¥', '')
}

async function submit() {
  const amount = computeAmount()
  if (amount <= 0) {
    errorMsg.value = '请输入金额'
    return
  }
  if (!categoryId.value) {
    errorMsg.value = t('recordExpense.categoryRequired')
    return
  }
  if (!accountId.value) {
    errorMsg.value = t('recordExpense.accountRequired')
    return
  }
  if (!book.current) {
    errorMsg.value = '未选择账本'
    return
  }
  errorMsg.value = null
  submitting.value = true
  try {
    await createRecord({
      type: activeTab.value as 'expense' | 'income',
      categoryId: categoryId.value,
      accountId: accountId.value,
      amount: Math.round(amount * 100) / 100,
      recordDate: recordDate.value,
      note: note.value.trim() || undefined,
      bookId: book.current.uuid,
    })
    showSuccess.value = true
    setTimeout(() => {
      emit('saved')
      close()
    }, 1200)
  } catch (e: any) {
    errorMsg.value = e?.message ?? '保存失败'
  } finally {
    submitting.value = false
  }
}

// 键盘:4 列 × 4 行
const KEYS: Array<{ label: string; value: string; span?: number; kind?: 'back' | 'op' | 'confirm' }> = [
  { label: '1', value: '1' },
  { label: '2', value: '2' },
  { label: '3', value: '3' },
  { label: '⌫', value: 'back', kind: 'back' },
  { label: '4', value: '4' },
  { label: '5', value: '5' },
  { label: '6', value: '6' },
  { label: '+', value: 'op', kind: 'op' },
  { label: '7', value: '7' },
  { label: '8', value: '8' },
  { label: '9', value: '9' },
  { label: '−', value: 'op', kind: 'op' },
  { label: '0', value: '0', span: 2 },
  { label: '.', value: '.' },
  { label: '✓', value: 'confirm', kind: 'confirm' },
]

function catTint(hex: string): string {
  // 把 #RRGGBB 转成 rgba(r,g,b,0.12) 简单粗暴
  const h = hex.replace('#', '')
  if (h.length !== 6) return hex + '22'
  const r = parseInt(h.slice(0, 2), 16)
  const g = parseInt(h.slice(2, 4), 16)
  const b = parseInt(h.slice(4, 6), 16)
  return `rgba(${r}, ${g}, ${b}, 0.14)`
}

const isExpense = computed(() => activeTab.value === 'expense')
const accentBg = computed(() => isExpense.value ? 'var(--c-primary)' : '#10b981')
</script>

<template>
  <!-- 整页遮罩 + 底部弹出 sheet -->
  <view v-if="show" class="qa-overlay" @tap.self="close">
    <view class="qa-sheet">
      <!-- 成功态 -->
      <view v-if="showSuccess" class="qa-success">
        <view class="qa-success-circle" :style="{ background: isExpense ? 'var(--c-primary-light)' : 'rgba(16,185,129,0.14)', color: accentBg }">
          <text class="qa-success-check">✓</text>
        </view>
        <text class="qa-success-text">
          {{ activeTab === 'expense' ? t('recordExpense.success') : t('recordIncome.success') }}
        </text>
      </view>

      <!-- 表单态 -->
      <template v-else>
        <!-- 顶部:关闭 + tab 切换 -->
        <view class="qa-head">
          <view class="qa-close" @tap="close">✕</view>
          <view class="qa-tabs">
            <view class="qa-tab" :class="{ active: activeTab === 'expense' }" @tap="activeTab = 'expense'">
              {{ t('recordModal.expense') }}
            </view>
            <view class="qa-tab" :class="{ active: activeTab === 'income' }" @tap="activeTab = 'income'">
              {{ t('recordModal.income') }}
            </view>
          </view>
          <view class="qa-head-spacer" />
        </view>

        <!-- 金额显示 -->
        <view class="qa-amount">
          <text class="qa-amount-hint">
            {{ activeTab === 'expense' ? t('recordExpense.amountPrompt') : t('recordIncome.amountPrompt') }}
          </text>
          <view class="qa-amount-row">
            <text class="qa-yen">¥</text>
            <text class="qa-amount-num">{{ displayAmount() }}</text>
            <text class="qa-cursor">|</text>
          </view>
        </view>

        <!-- 分类网格 -->
        <view class="qa-cats">
          <view v-if="visibleCats.length === 0" class="qa-empty">
            {{ t('recordModal.categoryLoading') }}
          </view>
          <view v-else class="qa-cats-grid">
            <view
              v-for="cat in visibleCats"
              :key="cat.id"
              class="qa-cat"
              @tap="categoryId = cat.id"
            >
              <view
                class="qa-cat-circle"
                :style="{
                  background: categoryId === cat.id ? cat.color : catTint(cat.color),
                  borderColor: categoryId === cat.id ? cat.color : 'transparent',
                }"
              >
                <text class="qa-cat-icon" :style="{ color: categoryId === cat.id ? '#fff' : cat.color }">
                  {{ cat.icon }}
                </text>
              </view>
              <text class="qa-cat-name" :style="{ color: categoryId === cat.id ? cat.color : 'var(--c-text)', fontWeight: categoryId === cat.id ? 600 : 400 }">
                {{ cat.name }}
              </text>
            </view>
          </view>
        </view>

        <!-- 账户 chips -->
        <view v-if="acctsActive.length > 0" class="qa-accounts">
          <text class="qa-acct-label">{{ t('recordModal.accountLabel') }}</text>
          <scroll-view scroll-x class="qa-acct-scroll">
            <view class="qa-acct-list">
              <view
                v-for="a in acctsActive"
                :key="a.id"
                class="qa-acct-chip"
                :class="{ active: a.id === accountId }"
                @tap="accountId = a.id"
              >
                <text class="qa-acct-chip-icon">💳</text>
                <text>{{ a.name }}</text>
              </view>
            </view>
          </scroll-view>
        </view>

        <!-- 日期 + 备注 -->
        <view class="qa-meta">
          <picker mode="date" :value="recordDate" @change="(e: any) => recordDate = e.detail.value">
            <view class="qa-date">
              <text>📅</text>
              <text>{{ recordDate }}</text>
            </view>
          </picker>
          <input
            v-model="note"
            :placeholder="t('recordModal.notePlaceholder')"
            class="qa-note"
            :maxlength="50"
          />
        </view>

        <!-- 错误 -->
        <view v-if="errorMsg" class="qa-error">{{ errorMsg }}</view>

        <!-- 数字键盘 -->
        <view class="qa-keypad">
          <view
            v-for="(k, i) in KEYS"
            :key="i"
            class="qa-key"
            :class="[k.kind === 'confirm' ? 'confirm' : '', k.kind === 'back' ? 'back' : '', k.kind === 'op' ? 'op' : '']"
            :style="k.span === 2 ? { gridColumn: 'span 2' } : {}"
            @tap="pressKey(k.value)"
          >
            <text v-if="k.kind === 'confirm' && submitting" class="qa-key-loading">⏳</text>
            <text v-else>{{ k.label }}</text>
          </view>
        </view>
      </template>
    </view>
  </view>
</template>

<style scoped>
.qa-overlay {
  position: fixed;
  inset: 0;
  z-index: 999;
  background: rgba(20, 30, 60, 0.78);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
}
.qa-sheet {
  background: var(--c-bg-card);
  border-top-left-radius: 20rpx;
  border-top-right-radius: 20rpx;
  border: 1px solid var(--c-divider);
  border-bottom: none;
  max-height: 92vh;
  display: flex;
  flex-direction: column;
  padding-bottom: env(safe-area-inset-bottom);
}
.qa-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 24rpx 32rpx;
  border-bottom: 1px solid var(--c-divider);
}
.qa-close {
  width: 56rpx;
  height: 56rpx;
  font-size: 32rpx;
  color: var(--c-text-variant);
  display: flex;
  align-items: center;
  justify-content: center;
}
.qa-head-spacer { width: 56rpx; }
.qa-tabs {
  display: flex;
  background: var(--c-surface);
  border-radius: 12rpx;
  padding: 4rpx;
  gap: 4rpx;
}
.qa-tab {
  padding: 10rpx 32rpx;
  border-radius: 8rpx;
  font-size: 26rpx;
  color: var(--c-text-variant);
}
.qa-tab.active {
  background: var(--c-bg-card);
  color: var(--c-primary);
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}
.qa-amount {
  background: var(--c-bg);
  text-align: center;
  padding: 32rpx 24rpx 24rpx;
}
.qa-amount-hint {
  display: block;
  font-size: 22rpx;
  color: var(--c-text-variant);
  margin-bottom: 8rpx;
}
.qa-amount-row {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: 6rpx;
}
.qa-yen {
  font-size: 32rpx;
  color: var(--c-text-variant);
}
.qa-amount-num {
  font-size: 72rpx;
  font-weight: 700;
  color: var(--c-text);
  border-bottom: 2rpx solid var(--c-primary);
  padding: 0 16rpx 6rpx;
  min-width: 200rpx;
  text-align: center;
  font-variant-numeric: tabular-nums;
}
.qa-cursor {
  font-size: 40rpx;
  color: var(--c-text);
  animation: qa-blink 1s steps(2, end) infinite;
}
@keyframes qa-blink { to { opacity: 0; } }
.qa-cats {
  padding: 24rpx 24rpx 16rpx;
  max-height: 40vh;
  overflow-y: auto;
}
.qa-empty {
  text-align: center;
  padding: 32rpx;
  color: var(--c-text-variant);
  font-size: 26rpx;
}
.qa-cats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  row-gap: 24rpx;
  column-gap: 8rpx;
}
.qa-cat {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
}
.qa-cat-circle {
  width: 88rpx;
  height: 88rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2rpx solid transparent;
  transition: transform 0.1s ease;
}
.qa-cat:active .qa-cat-circle { transform: scale(0.94); }
.qa-cat-icon { font-size: 36rpx; }
.qa-cat-name {
  font-size: 22rpx;
  text-align: center;
}
.qa-accounts {
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 8rpx 24rpx 16rpx;
}
.qa-acct-label {
  font-size: 22rpx;
  color: var(--c-text-variant);
  flex-shrink: 0;
}
.qa-acct-scroll {
  flex: 1;
  overflow-x: auto;
}
.qa-acct-list {
  display: flex;
  flex-wrap: nowrap;
  gap: 12rpx;
  width: max-content;
}
.qa-acct-chip {
  display: inline-flex;
  align-items: center;
  gap: 6rpx;
  padding: 8rpx 20rpx;
  border-radius: 28rpx;
  background: var(--c-surface);
  color: var(--c-text);
  font-size: 22rpx;
  white-space: nowrap;
  flex-shrink: 0;
}
.qa-acct-chip.active {
  background: var(--c-primary);
  color: #fff;
}
.qa-acct-chip-icon { font-size: 22rpx; }
.qa-meta {
  display: flex;
  gap: 16rpx;
  padding: 8rpx 24rpx 16rpx;
}
.qa-date {
  display: flex;
  align-items: center;
  gap: 6rpx;
  padding: 12rpx 20rpx;
  border-radius: 12rpx;
  background: var(--c-surface);
  font-size: 24rpx;
  color: var(--c-text);
  flex-shrink: 0;
}
.qa-note {
  flex: 1;
  padding: 12rpx 20rpx;
  border-radius: 12rpx;
  background: var(--c-surface);
  font-size: 24rpx;
  color: var(--c-text);
}
.qa-error {
  margin: 0 24rpx 12rpx;
  background: rgba(186, 26, 26, 0.12);
  color: var(--c-error);
  border-radius: 8rpx;
  padding: 12rpx 16rpx;
  font-size: 24rpx;
}
.qa-keypad {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  padding: 8rpx 16rpx 16rpx;
  gap: 8rpx;
  background: var(--c-bg-card);
}
.qa-key {
  height: 80rpx;
  border-radius: 12rpx;
  background: var(--c-surface);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 32rpx;
  font-weight: 500;
  color: var(--c-text);
}
.qa-key.back { background: var(--c-surface); color: var(--c-text-variant); }
.qa-key.op { background: var(--c-surface); }
.qa-key.confirm {
  background: v-bind(accentBg);
  color: #fff;
}
.qa-key:active { opacity: 0.7; }
.qa-key-loading { font-size: 28rpx; }
.qa-success {
  padding: 120rpx 24rpx 100rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24rpx;
}
.qa-success-circle {
  width: 112rpx;
  height: 112rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}
.qa-success-check {
  font-size: 56rpx;
  font-weight: 700;
}
.qa-success-text {
  font-size: 32rpx;
  font-weight: 600;
  color: var(--c-text);
}
</style>
