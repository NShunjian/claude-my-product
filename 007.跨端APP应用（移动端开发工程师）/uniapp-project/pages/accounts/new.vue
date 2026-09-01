<script setup lang="ts">
import { ref } from 'vue'
import { useLanguage } from '@/i18n/useLanguage'
import { useToastStore } from '@/stores/toast'
import { createAccount } from '@/api/accounts'
import type { AccountType } from '@/api/accounts'

const { t } = useLanguage()
const toast = useToastStore()

const ACCOUNT_TYPES: { value: AccountType; label: string }[] = [
  { value: 'wallet', label: '微信支付' },
  { value: 'wallet', label: '支付宝' },
  { value: 'cash', label: '现金' },
  { value: 'debit', label: '银行卡' },
  { value: 'credit', label: '信用卡' },
  { value: 'investment', label: '投资账户' },
  { value: 'other', label: '其他' },
]

const ICONS = ['account_balance_wallet', 'credit_card', 'account_balance', 'payments', 'phone_iphone']

const name = ref('')
const type = ref<AccountType>('wallet')
const balance = ref('0.00')
const icon = ref(ICONS[0])
const isDefault = ref(false)
const submitting = ref(false)
const errorMsg = ref<string | null>(null)

async function handleSubmit() {
  if (!name.value.trim() || !type.value) return
  submitting.value = true
  errorMsg.value = null
  try {
    await createAccount({
      name: name.value.trim(),
      type: type.value,
      icon: icon.value,
      initialBalance: Number.parseFloat(balance.value) || 0,
      currency: 'CNY',
      isDefault: isDefault.value,
    })
    uni.navigateBack()
  } catch (err: any) {
    errorMsg.value = err?.message ?? t('accountAdd.saveFailPrefix')
  } finally {
    submitting.value = false
  }
}
</script>

<template>
  <view class="page">
    <view class="card">
      <!-- Account name -->
      <view class="field">
        <text class="field-label">{{ t('accountAdd.name') }}</text>
        <input v-model="name" class="field-input" :placeholder="t('accountAdd.namePlaceholder')" />
      </view>

      <!-- Account type -->
      <view class="field">
        <text class="field-label">{{ t('accountAdd.type') }}</text>
        <picker mode="selector" :range="ACCOUNT_TYPES" range-key="label" :value="0" @change="(e: any) => type = ACCOUNT_TYPES[e.detail.value].value">
          <view class="field-picker">
            <text>{{ ACCOUNT_TYPES.find(t => t.value === type)?.label ?? t('accountAdd.selectType') }}</text>
            <text class="arrow">▼</text>
          </view>
        </picker>
      </view>

      <!-- Initial balance -->
      <view class="field">
        <text class="field-label">{{ t('accountAdd.balance') }}</text>
        <view class="balance-row">
          <text class="currency">¥</text>
          <input v-model="balance" class="field-input" type="digit" placeholder="0.00" />
        </view>
      </view>

      <!-- Icon selector -->
      <view class="field">
        <text class="field-label">{{ t('accountAdd.icon') }}</text>
        <view class="icon-grid">
          <view v-for="ic in ICONS" :key="ic"
            class="icon-btn"
            :class="{ selected: icon === ic }"
            @tap="icon = ic">
            <text class="icon-glyph" :class="{ filled: icon === ic }">{{ ic }}</text>
          </view>
        </view>
      </view>

      <!-- isDefault toggle -->
      <view class="toggle-row">
        <view>
          <text class="field-label">{{ t('accountAdd.isDefault') }}</text>
          <text class="field-hint">{{ t('accountAdd.isDefaultHint') }}</text>
        </view>
        <switch :checked="isDefault" @change="(e: any) => isDefault = e.detail.value" color="var(--c-primary)" />
      </view>

      <!-- Error -->
      <view v-if="errorMsg" class="error-box">{{ errorMsg }}</view>

      <!-- Buttons -->
      <view class="btn-row">
        <view class="btn-cancel" @tap="uni.navigateBack()">{{ t('accountAdd.cancel') }}</view>
        <view class="btn-submit" @tap="handleSubmit" :class="{ disabled: !name.trim() || submitting }">
          <text v-if="submitting">…</text>
          <text v-else>{{ t('accountAdd.submitAccount') }}</text>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { padding: 24rpx; }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 32rpx; display: flex; flex-direction: column; gap: 32rpx; border: 1px solid var(--c-divider); }
.field { display: flex; flex-direction: column; gap: 8rpx; }
.field-label { font-size: 28rpx; font-weight: 600; color: var(--c-text); }
.field-hint { font-size: 22rpx; color: var(--c-text-variant); margin-top: 4rpx; }
.field-input { border-bottom: 2rpx solid var(--c-divider); padding: 12rpx 0; font-size: 28rpx; color: var(--c-text); }
.field-input:focus { border-color: var(--c-primary); }
.field-picker { display: flex; justify-content: space-between; align-items: center; border-bottom: 2rpx solid var(--c-divider); padding: 12rpx 0; font-size: 28rpx; color: var(--c-text); }
.arrow { color: var(--c-text-variant); font-size: 22rpx; }
.balance-row { display: flex; align-items: center; gap: 8rpx; border-bottom: 2rpx solid var(--c-divider); padding: 12rpx 0; }
.currency { font-size: 28rpx; color: var(--c-text-variant); }
.icon-grid { display: flex; flex-wrap: wrap; gap: 16rpx; }
.icon-btn { width: 80rpx; height: 80rpx; border-radius: 50%; border: 2rpx solid var(--c-divider); display: flex; align-items: center; justify-content: center; }
.icon-btn.selected { border-color: var(--c-primary); background: var(--c-primary-light); }
.icon-glyph { font-size: 28rpx; color: var(--c-text-variant); }
.icon-glyph.filled { color: var(--c-primary); }
.toggle-row { display: flex; justify-content: space-between; align-items: center; padding: 16rpx 0; border-top: 1rpx solid var(--c-divider); }
.error-box { background: #FFEBEE; color: #C62828; border-radius: 8rpx; padding: 16rpx; font-size: 26rpx; }
.btn-row { display: flex; gap: 16rpx; margin-top: 16rpx; }
.btn-cancel { flex: 1; text-align: center; padding: 20rpx; border: 2rpx solid var(--c-divider); border-radius: 12rpx; font-size: 28rpx; color: var(--c-text); }
.btn-submit { flex: 1; text-align: center; padding: 20rpx; background: var(--c-primary); color: #fff; border-radius: 12rpx; font-size: 28rpx; font-weight: 600; }
.btn-submit.disabled { opacity: 0.5; }
</style>
