<script setup lang="ts">
import RecordForm from '@/components/RecordForm.vue'

function back() {
  uni.navigateBack()
}
</script>

<template>
  <RecordForm type="expense" @saved="back" />
</template>
