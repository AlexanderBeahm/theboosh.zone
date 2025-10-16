import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { createRouter, createMemoryHistory } from 'vue-router'
import NavBar from './NavBar.vue'

describe('NavBar', () => {
  const createRouterInstance = () => {
    return createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/', name: 'home', component: { template: '<div>Home</div>' } },
        { path: '/about', name: 'about', component: { template: '<div>About</div>' } }
      ]
    })
  }

  it('renders navigation links', async () => {
    const router = createRouterInstance()
    await router.push('/')
    await router.isReady()

    const wrapper = mount(NavBar, {
      global: {
        plugins: [router]
      }
    })

    expect(wrapper.text()).toContain('Home')
    expect(wrapper.text()).toContain('About')
    expect(wrapper.text()).toContain('Swagger')
    expect(wrapper.text()).toContain('TheBoosh.Zone')
  })

  it('highlights active route', async () => {
    const router = createRouterInstance()
    await router.push('/')
    await router.isReady()

    const wrapper = mount(NavBar, {
      global: {
        plugins: [router]
      }
    })

    const homeLink = wrapper.find('a[href="/"]')
    expect(homeLink.classes()).toContain('active')
  })

  it('external Swagger link has correct attributes', async () => {
    const router = createRouterInstance()
    await router.push('/')
    await router.isReady()

    const wrapper = mount(NavBar, {
      global: {
        plugins: [router]
      }
    })

    const swaggerLink = wrapper.find('a[href="/swagger"]')
    expect(swaggerLink.attributes('target')).toBe('_blank')
    expect(swaggerLink.attributes('rel')).toBe('noopener noreferrer')
  })
})
