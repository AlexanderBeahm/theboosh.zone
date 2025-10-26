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
    background: radial-gradient(circle at center, rgba(255, 69, 0, 0.05) 0%, transparent 70%);
}

.error-content {
    max-width: 600px;
    text-align: center;
    padding: var(--spacing-xl);
    background: var(--card-bg);
    border: 2px solid var(--accent-orange);
    border-radius: var(--radius-lg);
    box-shadow:
        var(--shadow-xl),
        0 0 40px rgba(255, 69, 0, 0.3);
    position: relative;
    overflow: hidden;
}

.error-content::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: linear-gradient(90deg, var(--accent-orange), #FF8C00, var(--accent-orange));
    animation: errorPulse 2s ease-in-out infinite;
}

@keyframes errorPulse {
    0%, 100% { opacity: 1; transform: scaleX(1); }
    50% { opacity: 0.7; transform: scaleX(0.95); }
}

.error-content::after {
    content: '';
    position: absolute;
    top: -2px;
    left: -2px;
    right: -2px;
    bottom: -2px;
    background: linear-gradient(45deg, var(--accent-orange), transparent, var(--accent-orange));
    border-radius: var(--radius-lg);
    opacity: 0.1;
    z-index: -1;
}

.error-content h2 {
    background: linear-gradient(135deg, var(--accent-orange), #FF8C00);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: var(--spacing-md);
    font-size: 2rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    text-shadow: 0 0 20px rgba(255, 69, 0, 0.3);
    position: relative;
    z-index: 1;
}

.error-message {
    color: var(--text-primary);
    margin-bottom: var(--spacing-lg);
    font-size: 1.125rem;
    line-height: 1.6;
    background: rgba(255, 69, 0, 0.05);
    padding: var(--spacing-md);
    border-radius: var(--radius-md);
    border: 1px solid rgba(255, 69, 0, 0.2);
    position: relative;
    z-index: 1;
}

.error-details {
    text-align: left;
    margin: var(--spacing-lg) 0;
    padding: var(--spacing-md);
    background: var(--darker-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    position: relative;
    z-index: 1;
}

.error-details summary {
    cursor: pointer;
    font-weight: 700;
    color: var(--accent-cyan);
    margin-bottom: var(--spacing-sm);
    font-size: 1rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: color var(--transition-fast);
}

.error-details summary:hover {
    color: var(--accent-yellow);
}

.error-details pre {
    overflow-x: auto;
    padding: var(--spacing-sm);
    background: var(--bg-color);
    border: 1px solid rgba(255, 69, 0, 0.3);
    border-radius: var(--radius-sm);
    font-size: 0.875rem;
    color: var(--accent-orange);
    font-family: 'SF Mono', 'Menlo', 'Monaco', 'Inconsolata', 'Roboto Mono', 'Consolas', monospace;
    line-height: 1.4;
    max-height: 200px;
}

.error-details p {
    color: var(--text-secondary);
    margin-top: var(--spacing-sm);
    font-size: 0.875rem;
}

.error-details strong {
    color: var(--accent-cyan);
}

.retry-button {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border: 1px solid var(--primary-color);
    padding: var(--spacing-md) var(--spacing-xl);
    font-size: 1rem;
    font-weight: 700;
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: all var(--transition-fast);
    text-transform: uppercase;
    letter-spacing: 0.8px;
    position: relative;
    overflow: hidden;
    z-index: 1;
}

.retry-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.6s;
}

.retry-button:hover {
    transform: translateY(-2px);
    box-shadow:
        var(--shadow-lg),
        0 0 30px rgba(255, 105, 180, 0.4);
}

.retry-button:hover::before {
    left: 100%;
}
</style>
