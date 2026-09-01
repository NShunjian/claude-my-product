<script setup lang="ts">
import { computed } from 'vue'
import type { Record } from '@/api/records'
import { formatAmount } from '@/utils/finance'
import { formatLocalHHMM, formatLocalYMD } from '@/utils/date'
import CategoryBadge from './CategoryBadge.vue'
import type { Category } from '@/api/categories'

const props = defineProps<{ record: Record; category?: Category }>()
const emit = defineEmits<{ (e: 'tap', r: Record): void }>()
const date = computed(() => formatLocalYMD(props.record.createdAt))
const time = computed(() => formatLocalHHMM(props.record.createdAt))
</script>
<template>
  <view class="row" @tap="emit('tap', record)">
    <view class="left">
      <CategoryBadge v-if="category" :category="category" size="sm" />
      <text v-else class="cat-name">未分类</text>
      <text class="note" v-if="record.note">{{ record.note }}</text>
    </view>
    <view class="right">
      <text :class="['amt', record.type === 'income' ? 'income' : 'expense']">
        {{ record.type === 'income' ? '+' : '-' }}{{ formatAmount(Math.abs(record.amount), false) }}
      </text>
      <text class="date">
        <text>{{ date }}</text>
        <text v-if="time" class="time"> {{ time }}</text>
      </text>
    </view>
  </view>
</template>
<style scoped>
.row { display: flex; align-items: center; padding: 24rpx 16rpx; border-bottom: 1px solid var(--c-divider); }
.left { flex: 1; display: flex; flex-direction: column; gap: 6rpx; }
.cat-name { font-size: 26rpx; color: var(--c-text-variant); }
.note { font-size: 22rpx; color: var(--c-text-variant); }
.right { text-align: right; display: flex; flex-direction: column; gap: 6rpx; }
.amt.income { color: #2E7DE6; font-weight: 600; }
.amt.expense { color: var(--c-error); font-weight: 600; }
.date { font-size: 22rpx; color: var(--c-text-variant); }
.time { color: var(--c-text-variant); opacity: 0.8; }
</style>
