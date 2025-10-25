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
    <div v-if="error" class="error-boundary">
        <div class="error-content">
            <h2>Something went wrong</h2>
            <p class="error-message">
                {{ error.message }}
            </p>
            <details v-if="isDev" class="error-details">
                <summary>Error Details</summary>
                <pre>{{ error.stack }}</pre>
                <p><strong>Component info:</strong> {{ errorInfo }}</p>
            </details>
            <button class="retry-button" @click="reset">Try Again</button>
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
    padding: var(--spacing-lg);
}

.error-content {
    max-width: 600px;
    text-align: center;
    padding: var(--spacing-lg);
    background-color: var(--card-bg);
    border: 2px solid var(--error-color);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
}

.error-content h2 {
    color: var(--error-color);
    margin-bottom: var(--spacing-sm);
    font-size: 24px;
}

.error-message {
    color: var(--text-primary);
    margin-bottom: var(--spacing-sm);
    font-size: 16px;
}

.error-details {
    text-align: left;
    margin: var(--spacing-sm) 0;
    padding: var(--spacing-sm);
    background-color: var(--light-bg);
    border-radius: var(--radius-sm);
}

.error-details summary {
    cursor: pointer;
    font-weight: bold;
    color: var(--dark-bg);
    margin-bottom: var(--spacing-xs);
}

.error-details pre {
    overflow-x: auto;
    padding: var(--spacing-xs);
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-sm);
    font-size: 12px;
    color: var(--error-color);
}

.retry-button {
    background-color: var(--primary-color);
    color: white;
    border: none;
    padding: var(--spacing-sm) var(--spacing-md);
    font-size: 16px;
    border-radius: var(--radius-sm);
    cursor: pointer;
    transition: background-color var(--transition-fast);
}

.retry-button:hover {
    background-color: var(--primary-dark);
}
</style>
