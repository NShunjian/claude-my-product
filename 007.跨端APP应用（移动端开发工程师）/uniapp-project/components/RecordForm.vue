<script setup lang="ts">
import { ref, watch } from 'vue'
import { useBookStore } from '@/stores/book'
import * as accountsApi from '@/api/accounts'
import * as recordsApi from '@/api/records'
import * as categoriesApi from '@/api/categories'
import type { RecordType } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import { useToastStore } from '@/stores/toast'
import { todayLocal } from '@/utils/date'

const props = defineProps<{ type: RecordType }>()
const emit = defineEmits<{ (e: 'saved'): void }>()

const book = useBookStore()
const toast = useToastStore()

const accounts = ref<Account[]>([])
const cats = ref<Category[]>([])
const accountId = ref<string>('')
const toAccountId = ref<string>('')
const categoryId = ref<string>('')
const date = ref<string>(todayLocal())
const amount = ref<string>('')
const note = ref<string>('')
const busy = ref(false)

async function load() {
  if (!book.current) return
  accounts.value = await accountsApi.listAccounts({ bookId: book.current.uuid })
  cats.value = await categoriesApi.listCategories(props.type === 'transfer' ? 'expense' : props.type as 'expense' | 'income')
  if (accounts.value.length && !accountId.value) accountId.value = accounts.value[0].id
  if (accounts.value.length > 1 && !toAccountId.value) toAccountId.value = accounts.value[1]?.id ?? accounts.value[0].id
}

watch(() => book.current?.uuid, load, { immediate: true })

async function save() {
  if (!book.current) return
  if (!amount.value || Number(amount.value) <= 0) {
    toast.show('请输入金额')
    return
  }
  if (!accountId.value) {
    toast.show('请选择账户')
    return
  }
  if (props.type === 'transfer') {
    if (!toAccountId.value) {
      toast.show('请选择目标账户')
      return
    }
    if (toAccountId.value === accountId.value) {
      toast.show('转出账户和转入账户不能相同')
      return
    }
  }
  if (props.type !== 'transfer' && !categoryId.value) {
    toast.show('请选择分类')
    return
  }
  busy.value = true
  try {
    await recordsApi.createRecord({
      bookId: book.current.uuid,
      accountId: accountId.value,
      toAccountId: props.type === 'transfer' ? toAccountId.value : undefined,
      categoryId: props.type === 'transfer' ? undefined : categoryId.value,
      type: props.type,
      amount: Number(amount.value),
      recordDate: date.value,
      note: note.value || undefined,
    } as any)
    toast.show('已保存')
    emit('saved')
  } catch (e: any) {
    toast.show(e?.message ?? '保存失败')
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <view class="form">
    <view class="field">
      <text class="label">类型</text>
      <text class="value">{{ type === 'expense' ? '支出' : type === 'income' ? '收入' : '转账' }}</text>
    </view>
    <view class="field">
      <text class="label">金额</text>
      <input v-model="amount" type="digit" placeholder="0.00" class="input" />
    </view>
    <view class="field">
      <text class="label">账户</text>
      <picker mode="selector" :range="accounts" range-key="name" :value="accounts.findIndex(a => a.id === accountId)" @change="(e: any) => accountId = accounts[Number(e.detail.value)].id">
        <view class="picker">{{ accounts.find(a => a.id === accountId)?.name ?? '选择账户' }}</view>
      </picker>
    </view>
    <view class="field" v-if="type === 'transfer'">
      <text class="label">目标账户</text>
      <picker mode="selector" :range="accounts" range-key="name" :value="accounts.findIndex(a => a.id === toAccountId)" @change="(e: any) => toAccountId = accounts[Number(e.detail.value)].id">
        <view class="picker">{{ accounts.find(a => a.id === toAccountId)?.name ?? '选择目标账户' }}</view>
      </picker>
    </view>
    <view class="field" v-if="type !== 'transfer'">
      <text class="label">分类</text>
      <view class="cats">
        <view v-for="c in cats" :key="c.id" class="cat-item" :class="{ active: c.id === categoryId }" @tap="categoryId = c.id">
          <text class="cat-icon">{{ c.icon }}</text>
          <text class="cat-name">{{ c.name }}</text>
        </view>
      </view>
    </view>
    <view class="field">
      <text class="label">日期</text>
      <picker mode="date" :value="date" @change="(e: any) => date = e.detail.value">
        <view class="picker">{{ date }}</view>
      </picker>
    </view>
    <view class="field">
      <text class="label">备注</text>
      <input v-model="note" placeholder="可选" class="input" />
    </view>
    <view class="actions">
      <button class="btn-primary" :disabled="busy" @tap="save">保存</button>
    </view>
  </view>
</template>

<style scoped>
.form { display: flex; flex-direction: column; gap: 24rpx; padding: 24rpx; }
.field { display: flex; flex-direction: column; gap: 8rpx; }
.label { font-size: 26rpx; color: var(--c-text-variant); }
.input, .picker { border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 16rpx; background: var(--c-bg-card); color: var(--c-text); }
.cats { display: flex; flex-wrap: wrap; gap: 12rpx; }
.cat-item { display: flex; align-items: center; gap: 8rpx; padding: 8rpx 16rpx; border: 1px solid var(--c-divider); border-radius: 24rpx; }
.cat-item.active { border-color: var(--c-primary); background: var(--c-primary-light); }
.cat-icon { font-size: 28rpx; } .cat-name { font-size: 24rpx; }
.actions { margin-top: 24rpx; }
.btn-primary { background: var(--c-primary); color: #fff; border-radius: 12rpx; padding: 24rpx; text-align: center; font-size: 32rpx; }
</style>
