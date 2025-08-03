<template>
  <q-page class="flex flex-center">
    <div class="q-pa-lg" style="max-width: 1200px; width: 100%">
      <div class="text-h3 text-center q-mb-lg">
        <fa-icon icon="star" class="text-primary q-mr-sm" />
        Welcome to Your Quasar Golf Project
      </div>

      <div class="text-h6 text-center text-grey-7 q-mb-xl">
        TypeScript + Composition API + Firebase + Font Awesome
      </div>

      <example-usage />
    </div>
  </q-page>
</template>

<script setup lang="ts">
import ExampleUsage from 'components/ExampleUsage.vue';
</script>
