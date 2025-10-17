import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { nextTick } from 'vue'
import { createRouter, createMemoryHistory } from 'vue-router'
import axios from 'axios'

// Mock axios and vue-router
vi.mock('axios')

// We need to test the composable in isolation
// Import it after mocking dependencies
let useAuth
let router

describe('useAuth Composable', () => {
  beforeEach(async () => {
    // Create a fresh router for each test
    router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/', name: 'Home', component: { template: '<div>Home</div>' } },
        { path: '/admin/login', name: 'AdminLogin', component: { template: '<div>Login</div>' } },
        { path: '/admin', name: 'Admin', component: { template: '<div>Admin</div>' } }
      ]
    })

    // Clear the module cache and re-import to get fresh state
    vi.resetModules()

    // Mock useRouter to return our test router
    vi.doMock('vue-router', () => ({
      useRouter: () => router,
      createRouter,
      createMemoryHistory
    }))

    // Re-import useAuth with fresh state
    const authModule = await import('../composables/useAuth.js')
    useAuth = authModule.useAuth

    vi.clearAllMocks()
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  describe('Initial State', () => {
    it('starts with unauthenticated state', () => {
      const auth = useAuth()

      expect(auth.isAuthenticated.value).toBe(false)
      expect(auth.user.value).toBeNull()
      expect(auth.isChecking.value).toBe(false)
    })

    it('provides all required methods', () => {
      const auth = useAuth()

      expect(auth.checkAuth).toBeDefined()
      expect(auth.login).toBeDefined()
      expect(auth.logout).toBeDefined()
      expect(auth.requireAuth).toBeDefined()
      expect(typeof auth.checkAuth).toBe('function')
      expect(typeof auth.login).toBe('function')
      expect(typeof auth.logout).toBe('function')
      expect(typeof auth.requireAuth).toBe('function')
    })

    it('provides reactive state references', () => {
      const auth = useAuth()

      expect(auth.isAuthenticated).toHaveProperty('value')
      expect(auth.user).toHaveProperty('value')
      expect(auth.isChecking).toHaveProperty('value')
    })
  })

  describe('checkAuth()', () => {
    it('sets isChecking to true during auth check', async () => {
      axios.get.mockImplementation(() => new Promise(resolve => setTimeout(resolve, 100)))

      const auth = useAuth()
      const checkPromise = auth.checkAuth()

      expect(auth.isChecking.value).toBe(true)

      await checkPromise
    })

    it('returns true and sets state when authenticated', async () => {
      const mockUser = { username: 'testuser', email: 'test@example.com' }
      axios.get.mockResolvedValueOnce({
        data: {
          authenticated: true,
          user: mockUser
        }
      })

      const auth = useAuth()
      const result = await auth.checkAuth()

      expect(result).toBe(true)
      expect(auth.isAuthenticated.value).toBe(true)
      expect(auth.user.value).toEqual(mockUser)
      expect(auth.isChecking.value).toBe(false)
      expect(axios.get).toHaveBeenCalledWith('/api/auth/status')
    })

    it('returns false and clears state when not authenticated', async () => {
      axios.get.mockResolvedValueOnce({
        data: {
          authenticated: false
        }
      })

      const auth = useAuth()
      const result = await auth.checkAuth()

      expect(result).toBe(false)
      expect(auth.isAuthenticated.value).toBe(false)
      expect(auth.user.value).toBeNull()
      expect(auth.isChecking.value).toBe(false)
    })

    it('returns false and clears state on error', async () => {
      axios.get.mockRejectedValueOnce(new Error('Network error'))

      const auth = useAuth()
      const result = await auth.checkAuth()

      expect(result).toBe(false)
      expect(auth.isAuthenticated.value).toBe(false)
      expect(auth.user.value).toBeNull()
      expect(auth.isChecking.value).toBe(false)
    })

    it('prevents multiple simultaneous auth checks', async () => {
      axios.get.mockImplementation(() => new Promise(resolve =>
        setTimeout(() => resolve({ data: { authenticated: true } }), 50)
      ))

      const auth = useAuth()

      const check1 = auth.checkAuth()
      const check2 = auth.checkAuth()

      await Promise.all([check1, check2])

      // Should only call API once
      expect(axios.get).toHaveBeenCalledTimes(1)
    })

    it('sets isChecking to false even after error', async () => {
      axios.get.mockRejectedValueOnce(new Error('Network error'))

      const auth = useAuth()

      await auth.checkAuth()

      expect(auth.isChecking.value).toBe(false)
    })
  })

  describe('login()', () => {
    it('successfully logs in with valid credentials', async () => {
      const mockUser = { username: 'admin' }
      axios.post.mockResolvedValueOnce({
        data: {
          success: true,
          user: mockUser
        }
      })

      const auth = useAuth()
      const result = await auth.login('admin', 'password123')

      expect(result.success).toBe(true)
      expect(result.user).toEqual(mockUser)
      expect(auth.isAuthenticated.value).toBe(true)
      expect(auth.user.value).toEqual(mockUser)
      expect(axios.post).toHaveBeenCalledWith('/api/auth/login', {
        username: 'admin',
        password: 'password123'
      })
    })

    it('uses username if no user object returned', async () => {
      axios.post.mockResolvedValueOnce({
        data: {
          success: true
        }
      })

      const auth = useAuth()
      const result = await auth.login('admin', 'password123')

      expect(result.success).toBe(true)
      expect(result.user).toEqual({ username: 'admin' })
      expect(auth.user.value).toEqual({ username: 'admin' })
    })

    it('throws error with message on login failure', async () => {
      axios.post.mockResolvedValueOnce({
        data: {
          success: false,
          error: 'Invalid credentials'
        }
      })

      const auth = useAuth()

      await expect(auth.login('admin', 'wrong')).rejects.toThrow()
    })

    it('clears state on login error', async () => {
      axios.post.mockRejectedValueOnce({
        response: {
          data: {
            error: 'Invalid credentials'
          }
        }
      })

      const auth = useAuth()

      try {
        await auth.login('admin', 'wrong')
      } catch (err) {
        expect(auth.isAuthenticated.value).toBe(false)
        expect(auth.user.value).toBeNull()
      }
    })

    it('handles network errors gracefully', async () => {
      axios.post.mockRejectedValueOnce(new Error('Network error'))

      const auth = useAuth()

      await expect(auth.login('admin', 'password')).rejects.toMatchObject({
        message: expect.stringContaining('Login failed')
      })
    })

    it('extracts error message from response data', async () => {
      axios.post.mockRejectedValueOnce({
        response: {
          data: {
            error: 'Account locked'
          }
        }
      })

      const auth = useAuth()

      try {
        await auth.login('admin', 'password')
      } catch (err) {
        expect(err.message).toBe('Account locked')
      }
    })
  })

  describe('logout()', () => {
    it('calls logout API and clears state', async () => {
      axios.post.mockResolvedValueOnce({ data: { success: true } })

      // Set up authenticated state first
      const auth = useAuth()
      auth.isAuthenticated.value = true
      auth.user.value = { username: 'admin' }

      await router.push('/')
      await router.isReady()

      await auth.logout('/admin/login')

      expect(axios.post).toHaveBeenCalledWith('/api/auth/logout')
      expect(auth.isAuthenticated.value).toBe(false)
      expect(auth.user.value).toBeNull()
    })

    it('redirects to login page after logout', async () => {
      axios.post.mockResolvedValueOnce({ data: { success: true } })

      const auth = useAuth()
      auth.isAuthenticated.value = true

      await router.push('/')
      await router.isReady()

      await auth.logout('/admin/login')
      await nextTick()

      expect(router.currentRoute.value.path).toBe('/admin/login')
    })

    it('clears state even if API call fails', async () => {
      axios.post.mockRejectedValueOnce(new Error('Network error'))

      const auth = useAuth()
      auth.isAuthenticated.value = true
      auth.user.value = { username: 'admin' }

      await router.push('/')
      await router.isReady()

      await auth.logout('/admin/login')

      expect(auth.isAuthenticated.value).toBe(false)
      expect(auth.user.value).toBeNull()
    })

    it('supports custom redirect path', async () => {
      axios.post.mockResolvedValueOnce({ data: { success: true } })

      const auth = useAuth()
      auth.isAuthenticated.value = true

      await router.push('/admin')
      await router.isReady()

      await auth.logout('/')
      await nextTick()

      expect(router.currentRoute.value.path).toBe('/')
    })

    it('skips redirect if redirectPath is null', async () => {
      axios.post.mockResolvedValueOnce({ data: { success: true } })

      const auth = useAuth()
      auth.isAuthenticated.value = true

      await router.push('/admin')
      await router.isReady()

      const currentPath = router.currentRoute.value.path

      await auth.logout(null)
      await nextTick()

      // Should not redirect
      expect(router.currentRoute.value.path).toBe(currentPath)
    })
  })

  describe('requireAuth()', () => {
    it('returns true and does not redirect when authenticated', async () => {
      axios.get.mockResolvedValueOnce({
        data: {
          authenticated: true,
          user: { username: 'admin' }
        }
      })

      const auth = useAuth()
      await router.push('/')
      await router.isReady()

      const result = await auth.requireAuth()

      expect(result).toBe(true)
      expect(router.currentRoute.value.path).toBe('/')
    })

    it('returns false and redirects to login when not authenticated', async () => {
      axios.get.mockResolvedValueOnce({
        data: {
          authenticated: false
        }
      })

      const auth = useAuth()
      await router.push('/')
      await router.isReady()

      const result = await auth.requireAuth('/admin/login')
      await nextTick()

      expect(result).toBe(false)
      expect(router.currentRoute.value.path).toBe('/admin/login')
    })

    it('supports custom redirect path', async () => {
      axios.get.mockResolvedValueOnce({
        data: {
          authenticated: false
        }
      })

      const auth = useAuth()
      await router.push('/admin')
      await router.isReady()

      await auth.requireAuth('/')
      await nextTick()

      expect(router.currentRoute.value.path).toBe('/')
    })
  })

  describe('Shared State', () => {
    it('shares authentication state across multiple instances', async () => {
      axios.get.mockResolvedValueOnce({
        data: {
          authenticated: true,
          user: { username: 'admin' }
        }
      })

      const auth1 = useAuth()
      const auth2 = useAuth()

      await auth1.checkAuth()

      // Both instances should reflect the same state
      expect(auth1.isAuthenticated.value).toBe(true)
      expect(auth2.isAuthenticated.value).toBe(true)
      expect(auth1.user.value).toEqual({ username: 'admin' })
      expect(auth2.user.value).toEqual({ username: 'admin' })
    })

    it('updates all instances when one logs out', async () => {
      axios.post.mockResolvedValueOnce({ data: { success: true } })

      const auth1 = useAuth()
      const auth2 = useAuth()

      auth1.isAuthenticated.value = true
      auth1.user.value = { username: 'admin' }

      await router.push('/')
      await router.isReady()

      await auth1.logout('/admin/login')

      expect(auth1.isAuthenticated.value).toBe(false)
      expect(auth2.isAuthenticated.value).toBe(false)
      expect(auth1.user.value).toBeNull()
      expect(auth2.user.value).toBeNull()
    })
  })
})
