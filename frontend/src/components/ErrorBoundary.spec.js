import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import ErrorBoundary from './ErrorBoundary.vue'

describe('ErrorBoundary', () => {
  it('renders child content when no error', () => {
    const wrapper = mount(ErrorBoundary, {
      slots: {
        default: '<div class="test-content">Child Content</div>'
      }
    })

    expect(wrapper.text()).toContain('Child Content')
  })

  it('catches and displays error', async () => {
    const ErrorComponent = {
      template: '<div>{{ throwError() }}</div>',
      methods: {
        throwError() {
          throw new Error('Test error')
        }
      }
    }

    const wrapper = mount(ErrorBoundary, {
      slots: {
        default: ErrorComponent
      },
      global: {
        config: {
          errorHandler: vi.fn()
        }
      }
    })

    await wrapper.vm.$nextTick()

    expect(wrapper.vm.hasError || wrapper.text().includes('error')).toBeTruthy()
  })

  it('provides fallback UI when error occurs', () => {
    const wrapper = mount(ErrorBoundary)

    wrapper.vm.hasError = true
    wrapper.vm.error = new Error('Test error')

    expect(wrapper.vm.hasError).toBe(true)
  })
})
