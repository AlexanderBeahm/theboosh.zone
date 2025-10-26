<template>
  <div class="admin-login-page">
    <div class="login-container">
      <div class="login-card">
        <div class="login-header">
          <h1>Admin Login</h1>
          <p>Access the TheBoosh.Zone admin panel</p>
        </div>

        <form
          class="login-form"
          @submit.prevent="handleLogin"
        >
          <div class="form-group">
            <label for="username">Username</label>
            <input
              id="username"
              v-model="loginForm.username"
              type="text"
              required
              :disabled="isLoading"
              autocomplete="username"
              class="form-input"
            >
          </div>

          <div class="form-group">
            <label for="password">Password</label>
            <input
              id="password"
              v-model="loginForm.password"
              type="password"
              required
              :disabled="isLoading"
              autocomplete="current-password"
              class="form-input"
            >
          </div>

          <div class="form-actions">
            <button
              type="submit"
              :disabled="
                isLoading ||
                  !loginForm.username ||
                  !loginForm.password
              "
              class="login-button"
            >
              <span v-if="isLoading">Logging in...</span>
              <span v-else>Login</span>
            </button>
          </div>

          <div
            v-if="error"
            class="error-message"
          >
            {{ error }}
          </div>
        </form>

        <div class="login-footer">
          <router-link
            to="/"
            class="back-link"
          >
            ← Back to Home
          </router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { useRouter, useRoute } from "vue-router";
import { useAuth } from "../composables/useAuth";

const router = useRouter();
const route = useRoute();
const { login: authLogin, checkAuth } = useAuth();

// Reactive state
const isLoading = ref(false);
const error = ref("");
const loginForm = ref({
    username: "",
    password: "",
});

// Methods
async function handleLogin() {
    if (isLoading.value) return;

    isLoading.value = true;
    error.value = "";

    try {
        await authLogin(loginForm.value.username, loginForm.value.password);

        // Login successful, redirect to intended page or dashboard
        const redirectPath = route.query.redirect || "/admin";
        router.push(redirectPath);
    } catch (err) {
        error.value = err.message || "Login failed. Please try again.";
    } finally {
        isLoading.value = false;
    }
}

// Check if already authenticated on mount
onMounted(async () => {
    const authenticated = await checkAuth();
    if (authenticated) {
        // Already logged in, redirect to dashboard
        const redirectPath = route.query.redirect || "/admin";
        router.push(redirectPath);
    }
});
</script>

<style scoped>
.admin-login-page {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--bg-color);
    padding: var(--spacing-lg);
    position: relative;
    overflow: hidden;
}

/* Animated retro-futuristic background */
.admin-login-page::before {
    content: '';
    position: absolute;
    top: -50%;
    left: -50%;
    right: -50%;
    bottom: -50%;
    background:
        radial-gradient(circle at 25% 25%, rgba(255, 105, 180, 0.1) 0%, transparent 50%),
        radial-gradient(circle at 75% 75%, rgba(0, 206, 209, 0.1) 0%, transparent 50%),
        radial-gradient(circle at 50% 50%, rgba(255, 215, 0, 0.05) 0%, transparent 50%);
    animation: float 20s ease-in-out infinite;
    z-index: 0;
}

.admin-login-page::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background:
        linear-gradient(90deg, rgba(255, 105, 180, 0.02) 1px, transparent 1px),
        linear-gradient(rgba(255, 105, 180, 0.02) 1px, transparent 1px);
    background-size: 50px 50px;
    animation: slidePattern 30s linear infinite;
    z-index: 0;
}

@keyframes float {
    0%, 100% { transform: translate(0, 0) rotate(0deg); }
    25% { transform: translate(20px, -20px) rotate(1deg); }
    50% { transform: translate(-10px, 10px) rotate(-1deg); }
    75% { transform: translate(-20px, -10px) rotate(1deg); }
}

@keyframes slidePattern {
    0% { transform: translate(0, 0); }
    100% { transform: translate(50px, 50px); }
}

.login-container {
    width: 100%;
    max-width: 420px;
    position: relative;
    z-index: 1;
}

.login-card {
    background: var(--card-bg);
    border-radius: var(--radius-lg);
    box-shadow:
        var(--shadow-xl),
        0 0 40px rgba(255, 105, 180, 0.1);
    padding: var(--spacing-xxl);
    border: 1px solid var(--border-color);
    position: relative;
    overflow: hidden;
}

/* Retro-futuristic card accent */
.login-card::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: var(--gradient-retro-secondary);
    z-index: 1;
}

.login-card::after {
    content: '';
    position: absolute;
    top: -2px;
    left: -2px;
    right: -2px;
    bottom: -2px;
    background: var(--gradient-retro-primary);
    border-radius: var(--radius-lg);
    opacity: 0;
    transition: opacity var(--transition-fast);
    z-index: -1;
}

.login-card:hover::after {
    opacity: 0.1;
}

.login-header {
    text-align: center;
    margin-bottom: var(--spacing-xl);
    position: relative;
    z-index: 2;
}

.login-header h1 {
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    font-size: 2.25rem;
    font-weight: 700;
    margin-bottom: var(--spacing-sm);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    text-shadow: 0 0 20px rgba(255, 215, 0, 0.3);
}

.login-header p {
    color: var(--text-secondary);
    font-size: 0.875rem;
    font-weight: 500;
}

.login-form {
    margin-bottom: var(--spacing-lg);
    position: relative;
    z-index: 2;
}

.form-group {
    margin-bottom: var(--spacing-lg);
}

.form-group label {
    display: block;
    font-weight: 600;
    color: var(--accent-cyan);
    margin-bottom: var(--spacing-xs);
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.form-input {
    width: 100%;
    padding: var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    font-size: 1rem;
    background: var(--bg-color);
    color: var(--text-primary);
    transition: all var(--transition-fast);
    position: relative;
}

.form-input:focus {
    outline: none;
    border-color: var(--accent-cyan);
    box-shadow:
        0 0 0 2px rgba(0, 206, 209, 0.2),
        0 0 20px rgba(0, 206, 209, 0.3);
    background: var(--card-bg);
}

.form-input:disabled {
    opacity: 0.4;
    cursor: not-allowed;
    background: var(--darker-bg);
}

.form-actions {
    margin-bottom: var(--spacing-lg);
}

.login-button {
    width: 100%;
    padding: var(--spacing-md) var(--spacing-lg);
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border: 1px solid var(--primary-color);
    border-radius: var(--radius-md);
    font-size: 1rem;
    font-weight: 700;
    cursor: pointer;
    transition: all var(--transition-fast);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    position: relative;
    overflow: hidden;
}

.login-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.6s;
}

.login-button:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow:
        var(--shadow-lg),
        0 0 30px rgba(255, 105, 180, 0.4);
}

.login-button:hover:not(:disabled)::before {
    left: 100%;
}

.login-button:disabled {
    opacity: 0.4;
    cursor: not-allowed;
    transform: none;
    background: var(--darker-bg);
    border-color: var(--border-color);
}

.error-message {
    display: flex;
    align-items: center;
    gap: var(--spacing-sm);
    padding: var(--spacing-md);
    background: var(--error-bg);
    color: var(--error-text);
    border: 1px solid var(--error-border);
    border-radius: var(--radius-md);
    font-size: 0.875rem;
    margin-bottom: var(--spacing-lg);
    position: relative;
    overflow: hidden;
}

.error-message::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 3px;
    background: var(--accent-orange);
    animation: pulse 2s ease-in-out infinite;
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}

.error-icon {
    font-size: 1rem;
    color: var(--accent-orange);
}

.login-footer {
    text-align: center;
    position: relative;
    z-index: 2;
}

.back-link {
    color: var(--accent-cyan);
    text-decoration: none;
    font-size: 0.875rem;
    font-weight: 600;
    transition: all var(--transition-fast);
    padding: var(--spacing-xs) var(--spacing-sm);
    border-radius: var(--radius-sm);
    border: 1px solid transparent;
}

.back-link:hover {
    color: var(--accent-yellow);
    text-shadow: 0 0 10px rgba(255, 215, 0, 0.3);
    border-color: var(--accent-yellow);
    background: rgba(255, 215, 0, 0.05);
}

/* Responsive design - Retro-Futuristic */
@media (max-width: 480px) {
    .admin-login-page {
        padding: var(--spacing-md);
    }

    .admin-login-page::after {
        background-size: 30px 30px;
    }

    .login-card {
        padding: var(--spacing-xl);
    }

    .login-header h1 {
        font-size: 1.75rem;
        letter-spacing: 0.03em;
    }

    .login-header p {
        font-size: 0.8rem;
    }

    .form-input {
        padding: var(--spacing-sm) var(--spacing-md);
    }

    .login-button {
        padding: var(--spacing-sm) var(--spacing-md);
        font-size: 0.875rem;
    }
}
</style>
