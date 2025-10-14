<template>
  <div class="nav-bar">
    <nav class="nav-links" aria-label="Main navigation">
      <router-link to="/" :class="{ active: $route.path === '/' }">Home</router-link>
      <router-link to="/about" :class="{ active: $route.path === '/about' }">About</router-link>
      <router-link to="/articles" :class="{ active: $route.path.startsWith('/articles') }">Articles</router-link>
      <a
        href="/swagger"
        target="_blank"
        aria-label="View API documentation in Swagger UI (opens in new tab)"
        rel="noopener noreferrer"
      >Swagger</a>
    </nav>
    <div class="nav-title" aria-label="Site name">TheBoosh.Zone</div>
    <div class="nav-spacer"></div>

    <!-- Admin Logout Button (only visible when authenticated) -->
    <div v-if="isAuthenticated" class="nav-actions">
      <button @click="handleLogout" class="logout-button" title="Logout">
        🚪 Logout
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'

const router = useRouter()
const isAuthenticated = ref(false)

// Check authentication status
async function checkAuth() {
  try {
    const response = await axios.get('/api/auth/status')
    isAuthenticated.value = response.data.authenticated || false
  } catch (err) {
    isAuthenticated.value = false
  }
}

// Handle logout
async function handleLogout() {
  try {
    await axios.post('/api/auth/logout')
    isAuthenticated.value = false
    router.push('/admin/login')
  } catch (err) {
    console.error('Logout error:', err)
    // Force redirect even if logout fails
    isAuthenticated.value = false
    router.push('/admin/login')
  }
}

// Check auth on mount
onMounted(() => {
  checkAuth()
})
</script>

<style scoped>
.nav-bar {
  display: flex;
  align-items: center;
  padding: var(--spacing-sm) var(--spacing-lg);
  background-color: var(--dark-bg);
  border-bottom: 3px solid var(--primary-color);
  box-shadow: var(--shadow-sm);
}

.nav-links {
  display: flex;
  gap: var(--spacing-md);
}

.nav-links a {
  text-decoration: none;
  color: var(--light-text);
  font-weight: 500;
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-sm);
  transition: all var(--transition-fast);
  cursor: pointer;
}

.nav-links a:hover {
  background-color: var(--darker-bg);
  color: var(--primary-color);
}

.nav-links a.active {
  background-color: var(--primary-color);
  color: #fff;
}

.nav-title {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  font-size: 1.5rem;
  font-weight: bold;
  color: var(--light-text);
  letter-spacing: 0.5px;
}

.nav-spacer {
  flex: 1;
}

.nav-actions {
  display: flex;
  align-items: center;
  gap: var(--spacing-md);
}

.logout-button {
  padding: var(--spacing-xs) var(--spacing-md);
  border: 1px solid rgba(255, 0, 0, 0.3);
  background-color: rgba(255, 0, 0, 0.1);
  color: var(--light-text);
  border-radius: var(--radius-md);
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all var(--transition-fast);
  white-space: nowrap;
}

.logout-button:hover {
  background-color: rgba(255, 0, 0, 0.25);
  border-color: rgba(255, 0, 0, 0.5);
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(255, 0, 0, 0.2);
}

.logout-button:active {
  transform: translateY(0);
}
</style>
