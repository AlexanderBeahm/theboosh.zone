import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'
import NotFoundPage from './NotFoundPage.vue'

describe('NotFoundPage', () => {
  const createMockRouter = () => {
    return createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/', name: 'Home', component: { template: '<div>Home</div>' } },
        { path: '/:pathMatch(.*)*', name: 'NotFound', component: NotFoundPage }
      ]
    })
  }

  it('renders 404 message', async () => {
    const router = createMockRouter()
    await router.push('/nonexistent')
    await router.isReady()

    const wrapper = mount(NotFoundPage, {
      global: { plugins: [router] }
    })

    expect(wrapper.text()).toContain('404')
    expect(wrapper.text()).toMatch(/not found|doesn't exist/i)
  })

  it('provides link back to home', async () => {
    const router = createMockRouter()
    await router.push('/nonexistent')
    await router.isReady()

    const wrapper = mount(NotFoundPage, {
      global: { plugins: [router] }
    })

    const homeLink = wrapper.find('a[href="/"]')
    expect(homeLink.exists()).toBe(true)
  })

  it('has appropriate styling classes', async () => {
    const router = createMockRouter()
    await router.push('/nonexistent')
    await router.isReady()

    const wrapper = mount(NotFoundPage, {
      global: { plugins: [router] }
    })

    expect(wrapper.find('.not-found, .error-page, .content').exists()).toBe(true)
  })
})
