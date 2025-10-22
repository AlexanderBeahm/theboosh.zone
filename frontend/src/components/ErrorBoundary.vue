<script setup>
import { ref, onErrorCaptured } from "vue";

const error = ref(null);
const errorInfo = ref(null);
const isDev = import.meta.env.DEV;

onErrorCaptured((err, instance, info) => {
    error.value = err;
    errorInfo.value = info;

    // Log error to console in development
    /* eslint-disable no-console */
    if (isDev) {
        console.error("Error caught by boundary:", err);
        console.error("Component:", instance);
        console.error("Info:", info);
    }
    /* eslint-enable no-console */

    // Prevent error from propagating
    return false;
});

const reset = () => {
    error.value = null;
    errorInfo.value = null;
};
</script>

<template>
  <div
    v-if="error"
    class="error-boundary"
  >
    <div class="error-content">
      <h2>Something went wrong</h2>
      <p class="error-message">
        {{ error.message }}
      </p>
      <details
        v-if="isDev"
        class="error-details"
      >
        <summary>Error Details</summary>
        <pre>{{ error.stack }}</pre>
        <p><strong>Component info:</strong> {{ errorInfo }}</p>
      </details>
      <button
        class="retry-button"
        @click="reset"
      >
        Try Again
      </button>
    </div>
  </div>
  <slot v-else />
</template>

<style scoped>
.error-boundary {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 400px;
    padding: 2rem;
}

.error-content {
    max-width: 600px;
    text-align: center;
    padding: 2rem;
    background-color: #fff;
    border: 2px solid #e74c3c;
    border-radius: 8px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.error-content h2 {
    color: #e74c3c;
    margin-bottom: 1rem;
    font-size: 24px;
}

.error-message {
    color: #333;
    margin-bottom: 1rem;
    font-size: 16px;
}

.error-details {
    text-align: left;
    margin: 1rem 0;
    padding: 1rem;
    background-color: #f8f9fa;
    border-radius: 4px;
}

.error-details summary {
    cursor: pointer;
    font-weight: bold;
    color: #2c3e50;
    margin-bottom: 0.5rem;
}

.error-details pre {
    overflow-x: auto;
    padding: 0.5rem;
    background-color: #fff;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 12px;
    color: #e74c3c;
}

.retry-button {
    background-color: #3498db;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    font-size: 16px;
    border-radius: 4px;
    cursor: pointer;
    transition: background-color 0.2s;
}

.retry-button:hover {
    background-color: #2980b9;
}
</style>
