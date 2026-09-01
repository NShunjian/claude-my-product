<script setup lang="ts">
import RecordForm from '@/components/RecordForm.vue'
import AppHeader from '@/components/AppHeader.vue'
import { useLanguage } from '@/i18n/useLanguage'
import { goBack } from '@/utils/back'

const { t } = useLanguage()
</script>

<template>
  <AppHeader :title="t('pageTitle.recordIncome')" back @back="goBack" />
  <RecordForm type="income" @saved="goBack" />
</template>
