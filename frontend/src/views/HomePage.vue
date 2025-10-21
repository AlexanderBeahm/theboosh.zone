<template>
  <div class="home-page">
    <!-- Hero Header -->
    <div class="hero-header">
      <h1>TheBoosh.Zone</h1>
    </div>

    <!-- Articles Feed -->
    <div class="articles-feed">
      <!-- Loading State (Initial) -->
      <div v-if="isInitialLoading" class="loading-container">
        <div class="loading-spinner"></div>
        <p>Loading articles...</p>
      </div>

      <!-- Error State -->
      <div v-else-if="error" class="error-container">
        <h3>Failed to load articles</h3>
        <p>{{ error }}</p>
        <button @click="fetchInitialArticles" class="retry-button">Try Again</button>
      </div>

      <!-- Empty State -->
      <div v-else-if="articles.length === 0" class="empty-container">
        <h3>No articles yet</h3>
        <p>Check back soon for new content!</p>
      </div>

      <!-- Articles List -->
      <div v-else class="articles-list">
        <ArticleCard
          v-for="article in articles"
          :key="article.id"
          :article="article"
          @click="navigateToArticle(article.slug)"
          @tag-click="navigateToTag"
        />

        <!-- Loading More Indicator -->
        <div v-if="isLoadingMore" class="loading-more">
          <div class="loading-spinner"></div>
          <p>Loading more articles...</p>
        </div>

        <!-- End of Articles -->
        <div v-else-if="!hasMore && articles.length > 0" class="end-message">
          <p>You've reached the end of the articles</p>
          <router-link to="/articles" class="view-all-link">
            View all articles →
          </router-link>
        </div>

        <!-- Intersection Observer Sentinel -->
        <div ref="sentinel" class="sentinel"></div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import axios from 'axios'
import ArticleCard from '../components/ArticleCard.vue'

const router = useRouter()

// Reactive state
const articles = ref([])
const isInitialLoading = ref(true)
const isLoadingMore = ref(false)
const error = ref(null)
const currentPage = ref(1)
const hasMore = ref(true)
const sentinel = ref(null)
let observer = null

// Constants
const ARTICLES_PER_PAGE = 5

// Methods
async function fetchArticles(page) {
  try {
    const response = await axios.get('/api/articles', {
      params: {
        page,
        limit: ARTICLES_PER_PAGE
      }
    })

    if (response.data.success) {
      return {
        articles: response.data.articles || [],
        pagination: response.data.pagination
      }
    } else {
      throw new Error(response.data.error || 'Failed to fetch articles')
    }
  } catch (err) {
    console.error('Error fetching articles:', err)
    throw err
  }
}

async function fetchInitialArticles() {
  isInitialLoading.value = true
  error.value = null
  articles.value = []
  currentPage.value = 1

  try {
    const { articles: fetchedArticles, pagination } = await fetchArticles(1)
    articles.value = fetchedArticles
    hasMore.value = pagination.has_next || false
  } catch (err) {
    error.value = err.response?.data?.error || err.message || 'Failed to load articles'
  } finally {
    isInitialLoading.value = false
  }
}

async function loadMoreArticles() {
  if (isLoadingMore.value || !hasMore.value) return

  isLoadingMore.value = true

  try {
    currentPage.value++
    const { articles: fetchedArticles, pagination } = await fetchArticles(currentPage.value)

    articles.value.push(...fetchedArticles)
    hasMore.value = pagination.has_next || false
  } catch (err) {
    console.error('Error loading more articles:', err)
    currentPage.value-- // Revert page increment on error
  } finally {
    isLoadingMore.value = false
  }
}

function navigateToArticle(slug) {
  router.push({
    name: 'Article',
    params: { slug }
  })
}

function navigateToTag(tagSlug) {
  router.push({
    name: 'Articles',
    query: { tag: tagSlug }
  })
}

function setupIntersectionObserver() {
  if (!sentinel.value) return

  const options = {
    root: null,
    rootMargin: '100px', // Trigger 100px before reaching the sentinel
    threshold: 0
  }

  observer = new IntersectionObserver((entries) => {
    const entry = entries[0]
    if (entry.isIntersecting && hasMore.value && !isLoadingMore.value) {
      loadMoreArticles()
    }
  }, options)

  observer.observe(sentinel.value)
}

function cleanup() {
  if (observer && sentinel.value) {
    observer.unobserve(sentinel.value)
    observer.disconnect()
  }
}

// Lifecycle
onMounted(async () => {
  await fetchInitialArticles()
  setupIntersectionObserver()
})

onUnmounted(() => {
  cleanup()
})
</script>

<style scoped>
.home-page {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

/* Hero Header */
.hero-header {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 40vh;
  padding: var(--spacing-xl);
  background: linear-gradient(135deg, var(--bg-color) 0%, var(--light-bg) 100%);
}

.hero-header h1 {
  color: var(--text-primary);
  font-size: 4rem;
  font-weight: bold;
  margin: 0;
  text-align: center;
}

/* Articles Feed */
.articles-feed {
  flex: 1;
  max-width: 800px;
  margin: 0 auto;
  width: 100%;
  padding: var(--spacing-xl) var(--spacing-lg);
}

.articles-list {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-xl);
}

/* Loading, Error, Empty States */
.loading-container,
.error-container,
.empty-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-xxl);
  text-align: center;
  min-height: 200px;
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

.retry-button {
  background-color: var(--primary-color);
  color: white;
  border: none;
  padding: var(--spacing-sm) var(--spacing-lg);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-weight: 500;
  transition: background-color var(--transition-fast);
  margin-top: var(--spacing-md);
}

.retry-button:hover {
  background-color: var(--primary-color-dark);
}

/* Loading More */
.loading-more {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-lg);
}

.loading-more p {
  margin: 0;
  color: var(--text-secondary);
}

/* End Message */
.end-message {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-xl);
  text-align: center;
}

.end-message p {
  margin: 0 0 var(--spacing-md) 0;
  color: var(--text-secondary);
}

.view-all-link {
  color: var(--primary-color);
  text-decoration: none;
  font-weight: 500;
  padding: var(--spacing-sm) var(--spacing-lg);
  border: 1px solid var(--primary-color);
  border-radius: var(--radius-md);
  transition: all var(--transition-fast);
}

.view-all-link:hover {
  background-color: var(--primary-color);
  color: white;
}

/* Sentinel (Invisible Intersection Observer Target) */
.sentinel {
  height: 1px;
  visibility: hidden;
}

/* Responsive Design */
@media (max-width: 768px) {
  .hero-header h1 {
    font-size: 3rem;
  }

  .articles-feed {
    padding: var(--spacing-lg) var(--spacing-md);
  }
}

@media (max-width: 480px) {
  .hero-header {
    min-height: 30vh;
  }

  .hero-header h1 {
    font-size: 2.5rem;
  }

  .articles-list {
    gap: var(--spacing-lg);
  }
}
</style>
