import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import axios from 'axios'
import ArticleEditor from './ArticleEditor.vue'
import MarkdownRenderer from './MarkdownRenderer.vue'
import MediaLibrary from './MediaLibrary.vue'
import ImageUploader from './ImageUploader.vue'

vi.mock('axios')

describe('ArticleEditor', () => {
  const mockTags = [
    { id: 1, name: 'JavaScript', slug: 'javascript', usage_count: 5 },
    { id: 2, name: 'Vue', slug: 'vue', usage_count: 3 }
  ]

  beforeEach(() => {
    vi.clearAllMocks()
    axios.get.mockResolvedValue({
      data: { success: true, tags: mockTags }
    })
  })

  describe('Rendering', () => {
    it('renders create mode when no article provided', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      expect(wrapper.text()).toContain('Create New Article')
      expect(wrapper.find('button[type="submit"]').text()).toContain('Create Article')
    })

    it('renders edit mode with article data', async () => {
      const article = {
        id: 1,
        title: 'Test Article',
        slug: 'test-article',
        content: '# Test',
        excerpt: 'Excerpt',
        author: 'John',
        featured_image: '/test.jpg',
        meta_description: 'Meta',
        is_published: true,
        tags: [mockTags[0]]
      }

      const wrapper = mount(ArticleEditor, {
        props: { article, isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      expect(wrapper.text()).toContain('Edit Article')
      expect(wrapper.find('#title').element.value).toBe('Test Article')
      expect(wrapper.find('#slug').element.value).toBe('test-article')
      expect(wrapper.find('button[type="submit"]').text()).toContain('Update Article')
    })

    it('does not render when isVisible is false', () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: false },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      expect(wrapper.find('.modal-overlay').exists()).toBe(false)
    })
  })

  describe('Form Validation', () => {
    it('requires title, slug, and content', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      const submitButton = wrapper.find('button[type="submit"]')
      expect(submitButton.attributes('disabled')).toBeDefined()

      await wrapper.find('#title').setValue('Test Title')
      await wrapper.find('#slug').setValue('test-slug')
      await wrapper.find('#content').setValue('Content here')

      expect(submitButton.attributes('disabled')).toBeUndefined()
    })
  })

  describe('Slug Generation', () => {
    it('auto-generates slug from title in create mode', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()
      await wrapper.find('#title').setValue('Hello World Test!')
      await wrapper.find('#title').trigger('input')

      expect(wrapper.find('#slug').element.value).toBe('hello-world-test')
    })

    it('does not auto-generate slug in edit mode', async () => {
      const article = { id: 1, title: 'Original', slug: 'original', content: 'test' }
      const wrapper = mount(ArticleEditor, {
        props: { article, isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()
      const originalSlug = wrapper.find('#slug').element.value

      await wrapper.find('#title').setValue('New Title')
      await wrapper.find('#title').trigger('input')

      expect(wrapper.find('#slug').element.value).toBe(originalSlug)
    })
  })

  describe('Tab Switching', () => {
    it('switches between Write and Preview tabs', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      const buttons = wrapper.findAll('.tab-button')
      expect(buttons[0].classes()).toContain('active')

      await buttons[1].trigger('click')
      expect(buttons[1].classes()).toContain('active')
      expect(buttons[0].classes()).not.toContain('active')
    })
  })

  describe('Tag Management', () => {
    it('loads available tags on mount', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      expect(axios.get).toHaveBeenCalledWith('/api/tags')
    })

    it('shows tag suggestions when typing', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()
      await wrapper.find('.tag-input').setValue('Java')
      await wrapper.find('.tag-input').trigger('input')

      expect(wrapper.find('.tag-suggestions').exists()).toBe(true)
      expect(wrapper.text()).toContain('JavaScript')
    })

    it('adds tag from suggestions', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()
      await wrapper.find('.tag-input').setValue('Java')
      await wrapper.find('.tag-input').trigger('input')
      await wrapper.find('.tag-suggestion').trigger('click')

      expect(wrapper.find('.selected-tag').text()).toContain('JavaScript')
      expect(wrapper.find('.tag-input').element.value).toBe('')
    })

    it('removes selected tag', async () => {
      const article = { id: 1, title: 'Test', slug: 'test', content: 'test', tags: [mockTags[0]] }
      const wrapper = mount(ArticleEditor, {
        props: { article, isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      expect(wrapper.find('.selected-tag').exists()).toBe(true)
      await wrapper.find('.remove-tag-button').trigger('click')
      expect(wrapper.find('.selected-tag').exists()).toBe(false)
    })
  })

  describe('Saving Article', () => {
    it('creates new article successfully', async () => {
      const mockArticle = { id: 1, title: 'New Article', slug: 'new-article' }
      axios.post.mockResolvedValueOnce({
        data: { success: true, article: mockArticle }
      })

      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      await wrapper.find('#title').setValue('New Article')
      await wrapper.find('#slug').setValue('new-article')
      await wrapper.find('#content').setValue('# Content')
      await wrapper.find('form').trigger('submit.prevent')

      await flushPromises()

      expect(axios.post).toHaveBeenCalledWith('/api/admin/articles', expect.objectContaining({
        title: 'New Article',
        slug: 'new-article',
        content: '# Content'
      }))
      expect(wrapper.emitted('saved')).toBeTruthy()
      expect(wrapper.emitted('saved')[0][0]).toEqual(mockArticle)
    })

    it('updates existing article successfully', async () => {
      const article = { id: 1, title: 'Original', slug: 'original', content: 'test' }
      const updated = { ...article, title: 'Updated' }

      axios.put.mockResolvedValueOnce({
        data: { success: true, article: updated }
      })

      const wrapper = mount(ArticleEditor, {
        props: { article, isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      await wrapper.find('#title').setValue('Updated')
      await wrapper.find('form').trigger('submit.prevent')

      await flushPromises()

      expect(axios.put).toHaveBeenCalledWith(`/api/admin/articles/${article.id}`, expect.any(Object))
      expect(wrapper.emitted('saved')).toBeTruthy()
    })

    it('displays error on save failure', async () => {
      axios.post.mockRejectedValueOnce({
        response: { data: { error: 'Slug already exists' } }
      })

      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      await wrapper.find('#title').setValue('Test')
      await wrapper.find('#slug').setValue('test')
      await wrapper.find('#content').setValue('Content')
      await wrapper.find('form').trigger('submit.prevent')

      await flushPromises()

      expect(wrapper.find('.error-message').text()).toContain('Slug already exists')
    })

    it('disables form during save', async () => {
      axios.post.mockImplementation(() => new Promise(() => {}))

      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()

      await wrapper.find('#title').setValue('Test')
      await wrapper.find('#slug').setValue('test')
      await wrapper.find('#content').setValue('Content')

      wrapper.find('form').trigger('submit.prevent')
      await flushPromises()

      expect(wrapper.find('#title').attributes('disabled')).toBeDefined()
      expect(wrapper.find('button[type="submit"]').attributes('disabled')).toBeDefined()
    })
  })

  describe('Modal Controls', () => {
    it('emits close event when close button clicked', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()
      await wrapper.findAll('.close-button')[0].trigger('click')

      expect(wrapper.emitted('close')).toBeTruthy()
    })

    it('emits close when cancel button clicked', async () => {
      const wrapper = mount(ArticleEditor, {
        props: { isVisible: true },
        global: { components: { MarkdownRenderer, MediaLibrary, ImageUploader } }
      })

      await flushPromises()
      await wrapper.find('.cancel-button').trigger('click')

      expect(wrapper.emitted('close')).toBeTruthy()
    })
  })
})
