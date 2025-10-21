import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import ArticleCard from './ArticleCard.vue'

const mockArticle = {
  id: 1,
  title: 'Test Article',
  slug: 'test-article',
  excerpt: 'This is a test article excerpt',
  author: 'Test Author',
  published_at: '2025-01-15T12:00:00Z',
  tags: [
    { id: 1, name: 'JavaScript', slug: 'javascript' },
    { id: 2, name: 'Vue', slug: 'vue' }
  ]
}

describe('ArticleCard', () => {
  it('renders article title', () => {
    const wrapper = mount(ArticleCard, {
      props: { article: mockArticle }
    })

    expect(wrapper.text()).toContain('Test Article')
  })

  it('renders article excerpt', () => {
    const wrapper = mount(ArticleCard, {
      props: { article: mockArticle }
    })

    expect(wrapper.text()).toContain('This is a test article excerpt')
  })

  it('renders article author', () => {
    const wrapper = mount(ArticleCard, {
      props: { article: mockArticle }
    })

    expect(wrapper.text()).toContain('Test Author')
  })

  it('renders article tags', () => {
    const wrapper = mount(ArticleCard, {
      props: { article: mockArticle }
    })

    expect(wrapper.text()).toContain('JavaScript')
    expect(wrapper.text()).toContain('Vue')
  })

  it('emits click event when article is clicked', async () => {
    const wrapper = mount(ArticleCard, {
      props: { article: mockArticle }
    })

    await wrapper.trigger('click')

    expect(wrapper.emitted('click')).toBeTruthy()
  })

  it('emits tag-click event when tag is clicked', async () => {
    const wrapper = mount(ArticleCard, {
      props: { article: mockArticle }
    })

    const tags = wrapper.findAll('.article-tag')
    await tags[0].trigger('click')

    expect(wrapper.emitted('tag-click')).toBeTruthy()
    expect(wrapper.emitted('tag-click')[0][0]).toBe('javascript')
  })

  it('formats published date correctly', () => {
    const wrapper = mount(ArticleCard, {
      props: { article: mockArticle }
    })

    expect(wrapper.text()).toMatch(/Jan(uary)?\s+15,?\s+2025/)
  })

  it('handles article without excerpt', () => {
    const articleWithoutExcerpt = { ...mockArticle, excerpt: null }
    const wrapper = mount(ArticleCard, {
      props: { article: articleWithoutExcerpt }
    })

    expect(wrapper.find('.article-excerpt').exists()).toBe(false)
  })

  it('handles article without tags', () => {
    const articleWithoutTags = { ...mockArticle, tags: [] }
    const wrapper = mount(ArticleCard, {
      props: { article: articleWithoutTags }
    })

    expect(wrapper.find('.article-tags').exists()).toBe(false)
  })
})
