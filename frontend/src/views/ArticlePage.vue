<template>
  <div class="article-page">
    <!-- Loading State -->
    <div v-if="isLoading" class="loading-container">
      <div class="loading-spinner"></div>
      <p>Loading article...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="error-container">
      <h2>Article not found</h2>
      <p>{{ error }}</p>
      <div class="error-actions">
        <button @click="$router.push('/articles')" class="back-button">
          ← Back to Articles
        </button>
        <button @click="fetchArticle" class="retry-button">Try Again</button>
      </div>
    </div>

    <!-- Article Content -->
    <article v-else class="article-container">
      <!-- Article Header -->
      <header class="article-header">
        <div class="breadcrumb">
          <router-link to="/articles" class="breadcrumb-link">Articles</router-link>
          <span class="breadcrumb-separator">→</span>
          <span class="breadcrumb-current">{{ article.title }}</span>
        </div>

        <h1 class="article-title">{{ article.title }}</h1>

        <div class="article-meta">
          <div class="meta-item">
            <span class="meta-label">Published:</span>
            <time :datetime="article.published_at || article.date_added">
              {{ formatDate(article.published_at || article.date_added) }}
            </time>
          </div>

          <div class="meta-item">
            <span class="meta-label">Author:</span>
            <span class="meta-value">{{ article.author }}</span>
          </div>

          <div class="meta-item" v-if="article.date_updated !== article.date_added">
            <span class="meta-label">Updated:</span>
            <time :datetime="article.date_updated">
              {{ formatDate(article.date_updated) }}
            </time>
          </div>
        </div>

        <div class="article-tags" v-if="article.tags && article.tags.length > 0">
          <router-link
            v-for="tag in article.tags"
            :key="tag.id"
            :to="{ path: '/articles', query: { tag: tag.slug } }"
            class="article-tag"
          >
            #{{ tag.name }}
          </router-link>
        </div>

        <div class="article-excerpt" v-if="article.excerpt">
          <p>{{ article.excerpt }}</p>
        </div>
      </header>

      <!-- Featured Image -->
      <div class="featured-image" v-if="article.featured_image">
        <img
          :src="article.featured_image"
          :alt="article.title"
          loading="eager"
        />
      </div>

      <!-- Article Content -->
      <div class="article-body">
        <MarkdownRenderer
          :content="article.content"
          :sanitize="true"
        />
      </div>

      <!-- Article Footer -->
      <footer class="article-footer">
        <div class="article-actions">
          <button @click="shareArticle" class="share-button" title="Share article">
            Share
          </button>

          <button @click="scrollToTop" class="scroll-top-button" title="Scroll to top">
            ↑ Top
          </button>
        </div>

        <div class="article-navigation">
          <router-link
            to="/articles"
            class="back-to-articles"
          >
            ← Back to Articles
          </router-link>
        </div>
      </footer>
    </article>

    <!-- Related Articles (if we implement it later) -->
    <!-- <aside class="related-articles" v-if="relatedArticles.length > 0">
      <h3>Related Articles</h3>
      <div class="related-grid">
        <router-link
          v-for="related in relatedArticles"
          :key="related.id"
          :to="{ name: 'Article', params: { slug: related.slug } }"
          class="related-article"
        >
          <h4>{{ related.title }}</h4>
          <p v-if="related.excerpt">{{ related.excerpt }}</p>
        </router-link>
      </div>
    </aside> -->
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router'
import axios from 'axios'
import MarkdownRenderer from '../components/MarkdownRenderer.vue'

const route = useRoute()
const router = useRouter()

// Reactive state
const article = ref({})
const isLoading = ref(true)
const error = ref(null)
// const relatedArticles = ref([]) // For future implementation

// Methods
async function fetchArticle() {
  isLoading.value = true
  error.value = null

  try {
    const slug = route.params.slug
    if (!slug) {
      throw new Error('Article slug is required')
    }

    const response = await axios.get(`/api/articles/${slug}`)

    if (response.data.success) {
      article.value = response.data.article

      // Update page title and meta description
      document.title = `${article.value.title} - TheBoosh.Zone`

      if (article.value.meta_description) {
        updateMetaDescription(article.value.meta_description)
      }

    } else {
      throw new Error(response.data.error || 'Article not found')
    }
  } catch (err) {
    console.error('Error fetching article:', err)
    error.value = err.response?.data?.error || err.message || 'Failed to load article'

    // Update page title for error state
    document.title = 'Article Not Found - TheBoosh.Zone'

    // If 404, show a more user-friendly message
    if (err.response?.status === 404) {
      error.value = 'This article could not be found. It may have been moved or deleted.'
    }
  } finally {
    isLoading.value = false
  }
}

function formatDate(dateString) {
  if (!dateString) return ''

  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

function shareArticle() {
  if (navigator.share) {
    // Use native Web Share API if available
    navigator.share({
      title: article.value.title,
      text: article.value.excerpt || article.value.title,
      url: window.location.href
    }).catch(err => {
      console.log('Error sharing:', err)
      fallbackShare()
    })
  } else {
    fallbackShare()
  }
}

function fallbackShare() {
  // Copy URL to clipboard as fallback
  navigator.clipboard.writeText(window.location.href).then(() => {
    // Could show a toast notification here
    alert('Article URL copied to clipboard!')
  }).catch(() => {
    // Fallback for older browsers
    const textArea = document.createElement('textarea')
    textArea.value = window.location.href
    document.body.appendChild(textArea)
    textArea.focus()
    textArea.select()
    try {
      document.execCommand('copy')
      alert('Article URL copied to clipboard!')
    } catch (err) {
      console.error('Could not copy URL:', err)
    }
    document.body.removeChild(textArea)
  })
}

function scrollToTop() {
  window.scrollTo({
    top: 0,
    behavior: 'smooth'
  })
}

function updateMetaDescription(description) {
  // Update or create meta description tag
  let metaDescription = document.querySelector('meta[name="description"]')

  if (metaDescription) {
    metaDescription.setAttribute('content', description)
  } else {
    metaDescription = document.createElement('meta')
    metaDescription.name = 'description'
    metaDescription.content = description
    document.head.appendChild(metaDescription)
  }
}

function resetPageMeta() {
  // Reset page title
  document.title = 'TheBoosh.Zone'

  // Reset meta description
  const metaDescription = document.querySelector('meta[name="description"]')
  if (metaDescription) {
    metaDescription.setAttribute('content', 'Alex Beahm\'s personal portfolio and blog website')
  }
}

// Watch for route changes to fetch new article
watch(() => route.params.slug, () => {
  if (route.name === 'Article') {
    fetchArticle()
  }
}, { immediate: false })

// Lifecycle
onMounted(() => {
  fetchArticle()
})

// Cleanup when leaving the page
onBeforeRouteLeave((to, from, next) => {
  resetPageMeta()
  next()
})

// Also cleanup when component is unmounted
onUnmounted(() => {
  resetPageMeta()
})
</script>

<style scoped>
.article-page {
  max-width: 800px;
  margin: 0 auto;
  padding: var(--spacing-lg);
}

/* Loading and Error States */
.loading-container,
.error-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-xxl);
  text-align: center;
  min-height: 50vh;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--border-color);
  border-top: 3px solid var(--primary-color);
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: var(--spacing-md);
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.error-icon {
  font-size: 3rem;
  margin-bottom: var(--spacing-md);
}

.error-actions {
  display: flex;
  gap: var(--spacing-md);
  margin-top: var(--spacing-lg);
}

.back-button,
.retry-button {
  padding: var(--spacing-sm) var(--spacing-lg);
  border: 1px solid var(--border-color);
  background-color: var(--bg-color);
  color: var(--text-primary);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-weight: 500;
  transition: all var(--transition-fast);
  text-decoration: none;
}

.retry-button {
  background-color: var(--primary-color);
  color: white;
  border-color: var(--primary-color);
}

.back-button:hover,
.retry-button:hover {
  background-color: var(--primary-color);
  color: white;
  border-color: var(--primary-color);
}

.retry-button:hover {
  background-color: var(--primary-color-dark);
  border-color: var(--primary-color-dark);
}

/* Article Container */
.article-container {
  background-color: var(--card-bg);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
  overflow: hidden;
}

/* Article Header */
.article-header {
  padding: var(--spacing-xl);
  border-bottom: 1px solid var(--border-color);
}

.breadcrumb {
  display: flex;
  align-items: center;
  font-size: 0.875rem;
  color: var(--text-secondary);
  margin-bottom: var(--spacing-lg);
}

.breadcrumb-link {
  color: var(--primary-color);
  text-decoration: none;
  font-weight: 500;
}

.breadcrumb-link:hover {
  text-decoration: underline;
}

.breadcrumb-separator {
  margin: 0 var(--spacing-sm);
}

.breadcrumb-current {
  color: var(--text-secondary);
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 300px;
}

.article-title {
  font-size: 2.5rem;
  font-weight: 700;
  color: var(--text-primary);
  line-height: 1.2;
  margin-bottom: var(--spacing-lg);
}

.article-meta {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-lg);
  margin-bottom: var(--spacing-lg);
  font-size: 0.875rem;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
}

.meta-label {
  color: var(--text-secondary);
  font-weight: 500;
}

.meta-value {
  color: var(--text-primary);
  font-weight: 600;
}

.article-tags {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing-lg);
}

.article-tag {
  font-size: 0.875rem;
  color: var(--primary-color);
  background-color: var(--primary-color-light);
  padding: var(--spacing-xs) var(--spacing-md);
  border-radius: var(--radius-full);
  text-decoration: none;
  font-weight: 500;
  transition: all var(--transition-fast);
}

.article-tag:hover {
  background-color: var(--primary-color);
  color: white;
}

.article-excerpt {
  padding: var(--spacing-lg);
  background-color: var(--light-bg);
  border-radius: var(--radius-md);
  border-left: 4px solid var(--primary-color);
  margin-bottom: var(--spacing-lg);
}

.article-excerpt p {
  font-size: 1.125rem;
  line-height: 1.6;
  color: var(--text-primary);
  margin: 0;
  font-style: italic;
}

/* Featured Image */
.featured-image {
  width: 100%;
  max-height: 400px;
  overflow: hidden;
}

.featured-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

/* Article Body */
.article-body {
  padding: var(--spacing-xl);
  line-height: 1.8;
  font-size: 1.125rem;
}

/* Article Footer */
.article-footer {
  padding: var(--spacing-xl);
  border-top: 1px solid var(--border-color);
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--spacing-lg);
}

.article-actions {
  display: flex;
  gap: var(--spacing-md);
}

.share-button,
.scroll-top-button {
  padding: var(--spacing-sm) var(--spacing-md);
  border: 1px solid var(--border-color);
  background-color: var(--bg-color);
  color: var(--text-primary);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  transition: all var(--transition-fast);
}

.share-button:hover,
.scroll-top-button:hover {
  background-color: var(--primary-color);
  color: white;
  border-color: var(--primary-color);
}

.back-to-articles {
  color: var(--primary-color);
  text-decoration: none;
  font-weight: 500;
  padding: var(--spacing-sm) var(--spacing-md);
  border-radius: var(--radius-md);
  transition: all var(--transition-fast);
}

.back-to-articles:hover {
  background-color: var(--primary-color-light);
}

/* Related Articles (for future use) */
.related-articles {
  margin-top: var(--spacing-xxl);
  padding: var(--spacing-xl);
  background-color: var(--light-bg);
  border-radius: var(--radius-lg);
}

.related-articles h3 {
  margin-bottom: var(--spacing-lg);
  color: var(--text-primary);
  font-weight: 600;
}

.related-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: var(--spacing-lg);
}

.related-article {
  padding: var(--spacing-lg);
  background-color: var(--card-bg);
  border-radius: var(--radius-md);
  text-decoration: none;
  color: var(--text-primary);
  transition: all var(--transition-fast);
  border: 1px solid var(--border-color);
}

.related-article:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-sm);
  border-color: var(--primary-color-light);
}

.related-article h4 {
  margin-bottom: var(--spacing-sm);
  color: var(--primary-color);
  font-weight: 600;
}

.related-article p {
  color: var(--text-secondary);
  font-size: 0.875rem;
  line-height: 1.5;
}

/* Responsive Design */
@media (max-width: 768px) {
  .article-page {
    padding: var(--spacing-md);
  }

  .article-header,
  .article-body,
  .article-footer {
    padding: var(--spacing-lg);
  }

  .article-title {
    font-size: 2rem;
  }

  .article-meta {
    flex-direction: column;
    gap: var(--spacing-sm);
  }

  .article-footer {
    flex-direction: column;
    align-items: stretch;
  }

  .article-actions {
    justify-content: center;
  }

  .breadcrumb-current {
    max-width: 200px;
  }

  .error-actions {
    flex-direction: column;
    align-items: center;
  }
}

@media (max-width: 480px) {
  .article-title {
    font-size: 1.75rem;
  }

  .article-body {
    font-size: 1rem;
    line-height: 1.7;
  }

  .article-actions {
    flex-direction: column;
  }
}
</style>