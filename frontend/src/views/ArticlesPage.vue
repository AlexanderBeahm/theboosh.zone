<template>
  <div class="articles-page">
    <div class="page-header">
      <h1>Articles</h1>
      <p class="page-description">
        The articles below are written with my own personal opinions and offer no reflection on any other associations I have.
      </p>
    </div>

    <!-- Tag Filter Section -->
    <div class="filter-section" v-if="popularTags.length > 0">
      <h3>Filter by Tag</h3>
      <div class="tag-filters">
        <button
          class="tag-filter"
          :class="{ active: !selectedTag }"
          @click="clearTagFilter"
        >
          All Articles ({{ totalCount }})
        </button>
        <button
          v-for="tag in popularTags"
          :key="tag.id"
          class="tag-filter"
          :class="{ active: selectedTag === tag.slug }"
          @click="filterByTag(tag.slug)"
        >
          {{ tag.name }} ({{ tag.usage_count }})
        </button>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-container">
      <div class="loading-spinner"></div>
      <p>Loading articles...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="error-container">
      <h3>Failed to load articles</h3>
      <p>{{ error }}</p>
      <button @click="fetchArticles" class="retry-button">Try Again</button>
    </div>

    <!-- Empty State -->
    <div v-else-if="articles.length === 0" class="empty-container">
      <h3>No articles found</h3>
      <p v-if="selectedTag">
        No articles found with the tag "{{ selectedTag }}".
        <button @click="clearTagFilter" class="link-button">View all articles</button>
      </p>
      <p v-else>
        Check back soon for new content!
      </p>
    </div>

    <!-- Articles List -->
    <div v-else class="articles-container">
      <div class="articles-grid">
        <ArticleCard
          v-for="article in articles"
          :key="article.id"
          :article="article"
          @click="navigateToArticle(article.slug)"
          @tag-click="filterByTag"
        />
      </div>

      <!-- Pagination -->
      <div class="pagination" v-if="pagination.total_pages > 1">
        <button
          class="pagination-button"
          :disabled="!pagination.has_prev"
          @click="changePage(pagination.current_page - 1)"
        >
          ← Previous
        </button>

        <div class="pagination-info">
          <span class="pagination-current">{{ pagination.current_page }}</span>
          <span class="pagination-separator">of</span>
          <span class="pagination-total">{{ pagination.total_pages }}</span>
        </div>

        <button
          class="pagination-button"
          :disabled="!pagination.has_next"
          @click="changePage(pagination.current_page + 1)"
        >
          Next →
        </button>
      </div>

      <!-- Results Info -->
      <div class="results-info" v-if="pagination.total_count > 0">
        <p>
          Showing {{ articles.length }} of {{ pagination.total_count }} articles
          <span v-if="selectedTag">with tag "{{ selectedTag }}"</span>
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import axios from 'axios'
import ArticleCard from '../components/ArticleCard.vue'

const route = useRoute()
const router = useRouter()

// Reactive state
const articles = ref([])
const popularTags = ref([])
const isLoading = ref(true)
const error = ref(null)
const pagination = ref({
  current_page: 1,
  total_pages: 1,
  total_count: 0,
  per_page: 20,
  has_next: false,
  has_prev: false
})

// Computed properties
const selectedTag = computed(() => route.query.tag || null)
const currentPage = computed(() => parseInt(route.query.page) || 1)
const totalCount = computed(() => pagination.value.total_count)

// Methods
async function fetchArticles() {
  isLoading.value = true
  error.value = null

  try {
    const params = {
      page: currentPage.value,
      limit: 20
    }

    if (selectedTag.value) {
      params.tag = selectedTag.value
    }

    const response = await axios.get('/api/articles', { params })

    if (response.data.success) {
      articles.value = response.data.articles
      pagination.value = response.data.pagination
    } else {
      throw new Error(response.data.error || 'Failed to fetch articles')
    }
  } catch (err) {
    console.error('Error fetching articles:', err)
    error.value = err.response?.data?.error || err.message || 'Failed to load articles'
    articles.value = []
  } finally {
    isLoading.value = false
  }
}

async function fetchPopularTags() {
  try {
    const response = await axios.get('/api/tags/popular', {
      params: { limit: 10 }
    })

    if (response.data.success) {
      popularTags.value = response.data.tags || []
    }
  } catch (err) {
    console.error('Error fetching popular tags:', err)
    // Non-critical error, don't show to user
  }
}

function filterByTag(tagSlug) {
  router.push({
    name: 'Articles',
    query: { tag: tagSlug, page: 1 }
  })
}

function clearTagFilter() {
  router.push({
    name: 'Articles',
    query: {}
  })
}

function changePage(page) {
  const query = { page }
  if (selectedTag.value) {
    query.tag = selectedTag.value
  }

  router.push({
    name: 'Articles',
    query
  })
}

function navigateToArticle(slug) {
  router.push({
    name: 'Article',
    params: { slug }
  })
}

// Watchers
watch([currentPage, selectedTag], () => {
  fetchArticles()
}, { immediate: false })

// Lifecycle
onMounted(async () => {
  await Promise.all([
    fetchArticles(),
    fetchPopularTags()
  ])
})
</script>

<style scoped>
.articles-page {
  max-width: 1200px;
  margin: 0 auto;
  padding: var(--spacing-lg);
}

.page-header {
  text-align: center;
  margin-bottom: var(--spacing-xl);
}

.page-header h1 {
  font-size: 3rem;
  color: var(--primary-color);
  margin-bottom: var(--spacing-sm);
  font-weight: 700;
}

.page-description {
  font-size: 1.25rem;
  color: var(--text-secondary);
  max-width: 600px;
  margin: 0 auto;
}

/* Filter Section */
.filter-section {
  margin-bottom: var(--spacing-xl);
  padding: var(--spacing-lg);
  background-color: var(--light-bg);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-color);
}

.filter-section h3 {
  margin-bottom: var(--spacing-md);
  color: var(--text-primary);
  font-weight: 600;
}

.tag-filters {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
}

.tag-filter {
  padding: var(--spacing-xs) var(--spacing-md);
  border: 1px solid var(--border-color);
  background-color: var(--bg-color);
  color: var(--text-primary);
  border-radius: var(--radius-full);
  cursor: pointer;
  transition: all var(--transition-fast);
  font-size: 0.875rem;
  font-weight: 500;
}

.tag-filter:hover {
  background-color: var(--primary-color-light);
  border-color: var(--primary-color);
}

.tag-filter.active {
  background-color: var(--primary-color);
  color: white;
  border-color: var(--primary-color);
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

.error-icon,
.empty-icon {
  font-size: 3rem;
  margin-bottom: var(--spacing-md);
}

.retry-button,
.link-button {
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

.link-button {
  background-color: transparent;
  color: var(--primary-color);
  padding: 0;
  text-decoration: underline;
}

.retry-button:hover,
.link-button:hover {
  background-color: var(--primary-color-dark);
}

.link-button:hover {
  background-color: transparent;
  text-decoration: none;
}

/* Articles Grid */
.articles-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: var(--spacing-xl);
  margin-bottom: var(--spacing-xl);
}

/* Pagination */
.pagination {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: var(--spacing-lg);
  margin-bottom: var(--spacing-lg);
}

.pagination-button {
  padding: var(--spacing-sm) var(--spacing-lg);
  border: 1px solid var(--border-color);
  background-color: var(--bg-color);
  color: var(--text-primary);
  border-radius: var(--radius-md);
  cursor: pointer;
  font-weight: 500;
  transition: all var(--transition-fast);
}

.pagination-button:hover:not(:disabled) {
  background-color: var(--primary-color);
  color: white;
  border-color: var(--primary-color);
}

.pagination-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.pagination-info {
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  font-weight: 500;
}

.pagination-current {
  color: var(--primary-color);
  font-weight: 600;
}

.pagination-separator {
  color: var(--text-secondary);
}

/* Results Info */
.results-info {
  text-align: center;
  color: var(--text-secondary);
  font-size: 0.875rem;
}

/* Responsive Design */
@media (max-width: 768px) {
  .articles-page {
    padding: var(--spacing-md);
  }

  .page-header h1 {
    font-size: 2rem;
  }

  .articles-grid {
    grid-template-columns: 1fr;
    gap: var(--spacing-lg);
  }

  .tag-filters {
    justify-content: center;
  }

  .pagination {
    flex-direction: column;
    gap: var(--spacing-md);
  }

  .pagination-info {
    order: -1;
  }
}
</style>