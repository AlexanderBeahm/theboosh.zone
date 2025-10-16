import { ref } from 'vue'
import axios from 'axios'
import { useRouter } from 'vue-router'

// Shared authentication state
const isAuthenticated = ref(false)
const user = ref(null)
const isChecking = ref(false)

export function useAuth() {
  const router = useRouter()

  /**
   * Check current authentication status
   * @returns {Promise<boolean>} Authentication status
   */
  async function checkAuth() {
    if (isChecking.value) {
      // Prevent multiple simultaneous auth checks
      return isAuthenticated.value
    }

    isChecking.value = true

    try {
      const response = await axios.get('/api/auth/status')

      if (response.data.authenticated) {
        isAuthenticated.value = true
        user.value = response.data.user || null
      } else {
        isAuthenticated.value = false
        user.value = null
      }

      return isAuthenticated.value
    } catch (err) {
      console.error('Auth check failed:', err)
      isAuthenticated.value = false
      user.value = null
      return false
    } finally {
      isChecking.value = false
    }
  }

  /**
   * Login with credentials
   * @param {string} username
   * @param {string} password
   * @returns {Promise<Object>} Login result
   */
  async function login(username, password) {
    try {
      const response = await axios.post('/api/auth/login', {
        username,
        password
      })

      if (response.data.success) {
        // Update shared state
        isAuthenticated.value = true
        user.value = response.data.user || { username }

        return { success: true, user: user.value }
      } else {
        throw new Error(response.data.error || 'Login failed')
      }
    } catch (err) {
      console.error('Login error:', err)
      isAuthenticated.value = false
      user.value = null

      throw {
        message: err.response?.data?.error || err.message || 'Login failed. Please try again.'
      }
    }
  }

  /**
   * Logout current user
   * @param {string} redirectPath - Optional path to redirect after logout
   * @returns {Promise<void>}
   */
  async function logout(redirectPath = '/admin/login') {
    try {
      await axios.post('/api/auth/logout')
    } catch (err) {
      console.error('Logout error:', err)
      // Continue with logout even if API call fails
    } finally {
      // Clear shared state
      isAuthenticated.value = false
      user.value = null

      // Redirect to login page
      if (redirectPath) {
        router.push(redirectPath)
      }
    }
  }

  /**
   * Require authentication - redirect if not authenticated
   * @param {string} redirectPath - Where to redirect if not authenticated
   * @returns {Promise<boolean>} Whether user is authenticated
   */
  async function requireAuth(redirectPath = '/admin/login') {
    const authenticated = await checkAuth()

    if (!authenticated) {
      router.push(redirectPath)
      return false
    }

    return true
  }

  return {
    // State
    isAuthenticated,
    user,
    isChecking,

    // Methods
    checkAuth,
    login,
    logout,
    requireAuth
  }
}
