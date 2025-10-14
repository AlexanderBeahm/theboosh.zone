<template>
  <div class="admin-login-page">
    <div class="login-container">
      <div class="login-card">
        <div class="login-header">
          <h1>Admin Login</h1>
          <p>Access the TheBoosh.Zone admin panel</p>
        </div>

        <form @submit.prevent="handleLogin" class="login-form">
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
            />
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
            />
          </div>

          <div class="form-actions">
            <button
              type="submit"
              :disabled="isLoading || !loginForm.username || !loginForm.password"
              class="login-button"
            >
              <span v-if="isLoading">Logging in...</span>
              <span v-else>Login</span>
            </button>
          </div>

          <div v-if="error" class="error-message">
            <span class="error-icon">⚠️</span>
            {{ error }}
          </div>
        </form>

        <div class="login-footer">
          <router-link to="/" class="back-link">← Back to Home</router-link>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import axios from 'axios'

const router = useRouter()
const route = useRoute()

// Reactive state
const isLoading = ref(false)
const error = ref('')
const loginForm = ref({
  username: '',
  password: ''
})

// Methods
async function handleLogin() {
  if (isLoading.value) return

  isLoading.value = true
  error.value = ''

  try {
    const response = await axios.post('/api/auth/login', {
      username: loginForm.value.username,
      password: loginForm.value.password
    })

    if (response.data.success) {
      // Login successful, redirect to intended page or dashboard
      const redirectPath = route.query.redirect || '/admin'
      router.push(redirectPath)
    } else {
      throw new Error(response.data.error || 'Login failed')
    }
  } catch (err) {
    console.error('Login error:', err)
    error.value = err.response?.data?.error || err.message || 'Login failed. Please try again.'
  } finally {
    isLoading.value = false
  }
}

// Check if already authenticated on mount
onMounted(async () => {
  try {
    const response = await axios.get('/api/auth/status')
    if (response.data.authenticated) {
      // Already logged in, redirect to dashboard
      const redirectPath = route.query.redirect || '/admin'
      router.push(redirectPath)
    }
  } catch (err) {
    // Not authenticated, stay on login page
    console.log('Not authenticated, showing login form')
  }
})
</script>

<style scoped>
.admin-login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: var(--bg-color);
  padding: var(--spacing-lg);
}

.login-container {
  width: 100%;
  max-width: 400px;
}

.login-card {
  background-color: var(--card-bg);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-lg);
  padding: var(--spacing-xxl);
  border: 1px solid var(--border-color);
}

.login-header {
  text-align: center;
  margin-bottom: var(--spacing-xl);
}

.login-header h1 {
  color: var(--primary-color);
  font-size: 2rem;
  font-weight: 700;
  margin-bottom: var(--spacing-sm);
}

.login-header p {
  color: var(--text-secondary);
  font-size: 0.875rem;
}

.login-form {
  margin-bottom: var(--spacing-lg);
}

.form-group {
  margin-bottom: var(--spacing-lg);
}

.form-group label {
  display: block;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: var(--spacing-xs);
  font-size: 0.875rem;
}

.form-input {
  width: 100%;
  padding: var(--spacing-md);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  font-size: 1rem;
  background-color: var(--bg-color);
  color: var(--text-primary);
  transition: all var(--transition-fast);
}

.form-input:focus {
  outline: none;
  border-color: var(--primary-color);
  box-shadow: 0 0 0 3px var(--primary-color-light);
}

.form-input:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.form-actions {
  margin-bottom: var(--spacing-lg);
}

.login-button {
  width: 100%;
  padding: var(--spacing-md);
  background-color: var(--primary-color);
  color: white;
  border: none;
  border-radius: var(--radius-md);
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.login-button:hover:not(:disabled) {
  background-color: var(--primary-color-dark);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.login-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

.error-message {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  padding: var(--spacing-md);
  background-color: var(--error-bg);
  color: var(--error-text);
  border: 1px solid var(--error-border);
  border-radius: var(--radius-md);
  font-size: 0.875rem;
  margin-bottom: var(--spacing-lg);
}

.error-icon {
  font-size: 1rem;
}

.login-footer {
  text-align: center;
}

.back-link {
  color: var(--primary-color);
  text-decoration: none;
  font-size: 0.875rem;
  font-weight: 500;
  transition: color var(--transition-fast);
}

.back-link:hover {
  color: var(--primary-color-dark);
  text-decoration: underline;
}

/* Responsive design */
@media (max-width: 480px) {
  .admin-login-page {
    padding: var(--spacing-md);
  }

  .login-card {
    padding: var(--spacing-xl);
  }

  .login-header h1 {
    font-size: 1.75rem;
  }
}
</style>