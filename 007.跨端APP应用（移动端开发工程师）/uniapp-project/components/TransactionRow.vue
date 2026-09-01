<script setup lang="ts">
import { computed } from 'vue'
import type { Record } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import { formatAmount } from '@/utils/finance'
import { formatLocalHHMM, formatLocalYMD } from '@/utils/date'
import { useLanguage } from '@/i18n/useLanguage'
import { categoryPresentation } from '@/utils/category-presentation'

const props = defineProps<{
  record: Record
  category?: Category
  account?: Account | null
}>()
const emit = defineEmits<{ (e: 'tap', r: Record): void }>()
const { t } = useLanguage()

const date = computed(() => formatLocalYMD(props.record.createdAt))
const time = computed(() => formatLocalHHMM(props.record.createdAt))
// 顶部标题:有备注用备注,否则用分类名(对齐 React)
const title = computed(() => props.record.note?.trim() || props.category?.name || '未分类')
// 副标题:分类名 · 账户名(无账户时只显示分类)
const subtitle = computed(() => {
  const catName = props.category?.name
  const acctName = props.account?.name
  if (catName && acctName) return `${catName} · ${acctName}`
  return catName ?? acctName ?? ''
})
// 分类图标 + 语义色(对齐 React Material Symbols + colorToken)
const pres = computed(() => props.category ? categoryPresentation(props.category) : null)

function catTint(hex?: string): string {
  if (!hex) return 'var(--c-surface)'
  const h = hex.replace('#', '')
  if (h.length !== 6) return hex + '22'
  const r = parseInt(h.slice(0, 2), 16)
  const g = parseInt(h.slice(2, 4), 16)
  const b = parseInt(h.slice(4, 6), 16)
  return `rgba(${r}, ${g}, ${b}, 0.14)`
}
</script>

<template>
  <view class="row" @tap="emit('tap', record)">
    <!-- 圆形图标:MS Outlined 字形 + 浅色背景 + 语义色 -->
    <view
      class="icon-circle"
      :style="{
        background: catTint(pres?.color),
        color: pres?.color ?? 'var(--c-text-variant)',
      }"
    >
      <text class="icon-glyph">{{ pres?.icon ?? 'more_horiz' }}</text>
    </view>

    <!-- 中间:标题 + 副标题 -->
    <view class="mid">
      <text class="title">{{ title }}</text>
      <text v-if="subtitle && subtitle !== title" class="subtitle">{{ subtitle }}</text>
    </view>

    <!-- 右:金额 + 记账时间 -->
    <view class="right">
      <text :class="['amt', record.type === 'income' ? 'income' : 'expense']">
        {{ record.type === 'income' ? '+' : '-' }}{{ formatAmount(Math.abs(record.amount), true) }}
      </text>
      <text class="meta">
        <text class="meta-label">{{ t('transactions.recordTime') }}: </text>
        <text>{{ date }}{{ time ? ' ' + time : '' }}</text>
      </text>
    </view>
  </view>
</template>

<style scoped>
.row {
  display: flex;
  align-items: center;
  padding: 24rpx 24rpx;
  gap: 20rpx;
}
.icon-circle {
  width: 80rpx;
  height: 80rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}
.icon-glyph {
  font-family: 'Material Symbols Outlined', sans-serif;
  font-size: 40rpx;
  line-height: 1;
  font-weight: normal;
  font-style: normal;
}
.mid {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 6rpx;
  min-width: 0;
}
.title {
  font-size: 30rpx;
  font-weight: 600;
  color: var(--c-text);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.subtitle {
  font-size: 22rpx;
  color: var(--c-text-variant);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.right {
  text-align: right;
  display: flex;
  flex-direction: column;
  gap: 10rpx;
  flex-shrink: 0;
}
.amt {
  font-size: 32rpx;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  line-height: 1.1;
}
.amt.income { color: #006d40; }
.amt.expense { color: var(--c-error); }
.meta {
  font-size: 22rpx;
  color: var(--c-text-variant);
}
.meta-label { color: var(--c-text-variant); }
</style>
