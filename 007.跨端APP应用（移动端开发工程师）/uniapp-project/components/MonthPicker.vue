<script setup lang="ts">
import { computed, ref } from 'vue'
import { formatMonthCN } from '@/utils/date'

const props = defineProps<{ modelValue: string; compact?: boolean }>() // 'YYYY-MM'
const emit = defineEmits<{ (e: 'update:modelValue', v: string): void }>()

const label = computed(() => formatMonthCN(props.modelValue))

function step(delta: number) {
  let m = Number(props.modelValue.slice(5, 7)) + delta
  let y = Number(props.modelValue.slice(0, 4))
  if (m < 1) { m = 12; y -= 1 }
  if (m > 12) { m = 1; y += 1 }
  emit('update:modelValue', `${y}-${String(m).padStart(2, '0')}`)
}

// 弹框选月(对齐 frontend-react-java Home MonthPickerModal):年份下拉 + 4×3 月份网格 + 清除/本月
const openModal = ref(false)
const draftYear = ref(Number(props.modelValue.slice(0, 4)))
const yearOptions = Array.from({ length: 10 }, (_, i) => new Date().getFullYear() - 5 + i)

function open() {
  draftYear.value = Number(props.modelValue.slice(0, 4))
  openModal.value = true
}
function pickMonth(m: number) {
  emit('update:modelValue', `${draftYear.value}-${String(m).padStart(2, '0')}`)
  openModal.value = false
}
function goCurrentMonth() {
  const d = new Date()
  emit('update:modelValue', `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`)
  openModal.value = false
}
function close() { openModal.value = false }
</script>

<template>
  <view :class="['mp', { compact: compact }]" @tap="open">
    <template v-if="!compact">
      <view class="btn" @tap.stop="step(-1)">‹</view>
      <view class="label">{{ label }}</view>
      <view class="btn" @tap.stop="step(1)">›</view>
    </template>
    <view v-else class="compact-label">{{ label }} ▾</view>
  </view>

  <!-- 月份选择弹框:对齐 React MonthPickerModal -->
  <view v-if="openModal" class="modal-mask" @tap="close">
    <view class="modal-card" @tap.stop>
      <view class="modal-year-row">
        <text class="modal-year-label">年份</text>
        <picker mode="selector" :range="yearOptions" :value="yearOptions.indexOf(draftYear)" @change="(e: any) => draftYear = yearOptions[Number(e.detail.value)]">
          <view class="modal-year-select">
            <text>{{ draftYear }}</text>
            <text class="caret">▾</text>
          </view>
        </picker>
      </view>
      <view class="modal-grid">
        <view
          v-for="m in 12"
          :key="m"
          class="modal-month"
          :class="{ active: Number(modelValue.slice(0, 4)) === draftYear && Number(modelValue.slice(5, 7)) === m }"
          @tap="pickMonth(m)"
        >
          {{ m }}月
        </view>
      </view>
      <view class="modal-footer">
        <text class="footer-link" @tap="close">清除</text>
        <text class="footer-link primary" @tap="goCurrentMonth">本月</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
/* 紧凑触发器(原样式,首页用) */
.mp { display: flex; align-items: center; gap: 8rpx; padding: 8rpx 24rpx; border-radius: 32rpx; background: var(--c-bg-card); border: 1px solid var(--c-divider); }
.btn { width: 56rpx; height: 56rpx; display: flex; align-items: center; justify-content: center; font-size: 40rpx; color: var(--c-text-variant); line-height: 1; }
.label { font-size: 30rpx; font-weight: 600; padding: 0 12rpx; }

/* compact 形态(给流水页筛选卡用,与其他 picker 视觉一致:无 ‹ ›、下拉样式) */
.mp.compact {
  box-sizing: border-box;
  padding: 16rpx 20rpx;
  border: 2rpx solid var(--c-divider);
  border-radius: 12rpx;
  background: var(--c-bg-card);
  font-size: 26rpx;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.compact-label { font-size: 26rpx; color: var(--c-text); font-weight: 400; }

/* 月份弹框(对齐 React) */
.modal-mask {
  position: fixed; inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex; align-items: center; justify-content: center;
  z-index: 999;
}
.modal-card {
  width: 560rpx;
  background: var(--c-bg-card);
  border-radius: 16rpx;
  padding: 32rpx;
  display: flex; flex-direction: column; gap: 24rpx;
  box-shadow: 0 8rpx 32rpx rgba(0, 0, 0, 0.18);
}
.modal-year-row { display: flex; align-items: center; gap: 16rpx; }
.modal-year-label { font-size: 28rpx; color: var(--c-text-variant); }
.modal-year-select {
  flex: 1;
  display: flex; align-items: center; justify-content: space-between;
  padding: 16rpx 20rpx;
  border: 2rpx solid var(--c-primary);
  border-radius: 12rpx;
  font-size: 28rpx; color: var(--c-text); font-weight: 600;
}
.caret { color: var(--c-primary); font-size: 24rpx; }
.modal-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16rpx; }
.modal-month {
  height: 80rpx;
  display: flex; align-items: center; justify-content: center;
  border-radius: 12rpx;
  font-size: 28rpx; color: var(--c-text); font-weight: 500;
  background: transparent;
}
.modal-month.active { background: var(--c-primary); color: #fff; font-weight: 600; }
.modal-footer { display: flex; justify-content: space-between; padding-top: 8rpx; border-top: 1px solid var(--c-divider); }
.footer-link { font-size: 28rpx; color: var(--c-primary); padding: 12rpx 24rpx; }
.footer-link.primary { font-weight: 600; }
</style>
