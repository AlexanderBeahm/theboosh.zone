import { createRouter, createWebHistory } from 'vue-router'
import axios from 'axios'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: () => import('../views/HomePage.vue')
  },
  {
    path: '/about',
    name: 'About',
    component: () => import('../views/AboutPage.vue')
  },
  {
    path: '/articles',
    name: 'Articles',
    component: () => import('../views/ArticlesPage.vue')
  },
  {
    path: '/articles/:slug',
    name: 'Article',
    component: () => import('../views/ArticlePage.vue'),
    props: true
  },
  {
    path: '/admin/login',
    name: 'AdminLogin',
    component: () => import('../views/AdminLogin.vue')
  },
  {
    path: '/admin',
    name: 'AdminDashboard',
    component: () => import('../views/AdminDashboard.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('../views/NotFoundPage.vue')
  }
]

const router = createRouter({
  history: createWebHistory('/'),
  routes
})

// Navigation guard for protected routes
router.beforeEach(async (to, from, next) => {
  // Check if route requires authentication
  if (to.meta.requiresAuth) {
    try {
      // Check authentication status
      const response = await axios.get('/api/auth/status')

      if (response.data.authenticated) {
        // User is authenticated, proceed to route
        next()
      } else {
        // User is not authenticated, redirect to login
        next({
          name: 'AdminLogin',
          query: { redirect: to.fullPath }
        })
      }
    } catch (error) {
      console.error('Auth check failed:', error)
      // On auth check failure, redirect to login
      next({
        name: 'AdminLogin',
        query: { redirect: to.fullPath }
      })
    }
  } else {
    // Route doesn't require authentication, proceed normally
    next()
  }
})

export default router
