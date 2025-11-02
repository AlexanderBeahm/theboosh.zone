<template>
  <component
    :is="iconComponent"
    :class="['base-icon', sizeClass, customClass]"
    :style="iconStyle"
  />
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  icon: {
    type: Object,
    required: true
  },
  size: {
    type: String,
    default: 'md', // xs, sm, md, lg, xl
    validator: (value) => ['xs', 'sm', 'md', 'lg', 'xl'].includes(value)
  },
  color: {
    type: String,
    default: 'currentColor'
  },
  customClass: {
    type: String,
    default: ''
  }
});

const iconComponent = computed(() => props.icon);

const sizeClass = computed(() => `icon-${props.size}`);

const iconStyle = computed(() => ({
  color: props.color
}));
</script>

<style scoped>
.base-icon {
  display: inline-block;
  vertical-align: middle;
  flex-shrink: 0;
}

/* Size variants */
.icon-xs {
  width: 0.75rem;
  height: 0.75rem;
}

.icon-sm {
  width: 1rem;
  height: 1rem;
}

.icon-md {
  width: 1.25rem;
  height: 1.25rem;
}

.icon-lg {
  width: 1.5rem;
  height: 1.5rem;
}

.icon-xl {
  width: 2rem;
  height: 2rem;
}
</style>