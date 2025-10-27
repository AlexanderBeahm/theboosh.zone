<template>
  <div class="articles-page">
    <div class="page-header">
      <h1>Articles</h1>
      <p class="page-description">
        The articles below are written with my own personal opinions and
        offer no reflection on any other associations I have.
      </p>
    </div>

    <!-- Tag Filter Section -->
    <div
      v-if="popularTags.length > 0"
      class="filter-section"
    >
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
    <div
      v-if="isLoading"
      class="loading-container"
    >
      <div class="loading-spinner" />
      <p>Loading articles...</p>
    </div>

    <!-- Error State -->
    <div
      v-else-if="error"
      class="error-container"
    >
      <h3>Failed to load articles</h3>
      <p>{{ error }}</p>
      <button
        class="retry-button"
        @click="fetchArticles"
      >
        Try Again
      </button>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="articles.length === 0"
      class="empty-container"
    >
      <h3>No articles found</h3>
      <p v-if="selectedTag">
        No articles found with the tag "{{ selectedTag }}".
        <button
          class="link-button"
          @click="clearTagFilter"
        >
          View all articles
        </button>
      </p>
      <p v-else>
        Check back soon for new content!
      </p>
    </div>

    <!-- Articles List -->
    <div
      v-else
      class="articles-container"
    >
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
      <div
        v-if="pagination.total_pages > 1"
        class="pagination"
      >
        <button
          class="pagination-button"
          :disabled="!pagination.has_prev"
          @click="changePage(pagination.current_page - 1)"
        >
          ← Previous
        </button>

        <div class="pagination-info">
          <span class="pagination-current">{{
            pagination.current_page
          }}</span>
          <span class="pagination-separator">of</span>
          <span class="pagination-total">{{
            pagination.total_pages
          }}</span>
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
      <div
        v-if="pagination.total_count > 0"
        class="results-info"
      >
        <p>
          Showing {{ articles.length }} of
          {{ pagination.total_count }} articles
          <span v-if="selectedTag">with tag "{{ selectedTag }}"</span>
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import axios from "axios";
import ArticleCard from "../components/ArticleCard.vue";

const route = useRoute();
const router = useRouter();

// Reactive state
const articles = ref([]);
const popularTags = ref([]);
const isLoading = ref(true);
const error = ref(null);
const pagination = ref({
    current_page: 1,
    total_pages: 1,
    total_count: 0,
    per_page: 20,
    has_next: false,
    has_prev: false,
});

// Computed properties
const selectedTag = computed(() => route.query.tag || null);
const currentPage = computed(() => parseInt(route.query.page) || 1);
const totalCount = computed(() => pagination.value.total_count);

// Methods
async function fetchArticles() {
    isLoading.value = true;
    error.value = null;

    try {
        const params = {
            page: currentPage.value,
            limit: 20,
        };

        if (selectedTag.value) {
            params.tag = selectedTag.value;
        }

        const response = await axios.get("/api/articles", { params });

        if (response.data.success) {
            articles.value = response.data.articles;
            pagination.value = response.data.pagination;
        } else {
            throw new Error(response.data.error || "Failed to fetch articles");
        }
    } catch (err) {
        error.value =
            err.response?.data?.error ||
            err.message ||
            "Failed to load articles";
        articles.value = [];
    } finally {
        isLoading.value = false;
    }
}

async function fetchPopularTags() {
    try {
        const response = await axios.get("/api/tags/popular", {
            params: { limit: 10 },
        });

        if (response.data.success) {
            popularTags.value = response.data.tags || [];
        }
    } catch {
        // Non-critical error, don't show to user
    }
}

function filterByTag(tagSlug) {
    router.push({
        name: "Articles",
        query: { tag: tagSlug, page: 1 },
    });
}

function clearTagFilter() {
    router.push({
        name: "Articles",
        query: {},
    });
}

function changePage(page) {
    const query = { page };
    if (selectedTag.value) {
        query.tag = selectedTag.value;
    }

    router.push({
        name: "Articles",
        query,
    });
}

function navigateToArticle(slug) {
    router.push({
        name: "Article",
        params: { slug },
    });
}

// Watchers
watch(
    [currentPage, selectedTag],
    () => {
        fetchArticles();
    },
    { immediate: false },
);

// Lifecycle
onMounted(async () => {
    await Promise.all([fetchArticles(), fetchPopularTags()]);
});
</script>

<style scoped>
.articles-page {
    max-width: 1200px;
    margin: 0 auto;
    padding: var(--spacing-lg);
    background-color: var(--bg-color);
    min-height: 100vh;
}

.page-header {
    text-align: center;
    margin-bottom: var(--spacing-xl);
    position: relative;
    padding: var(--spacing-xl) 0;
}

.page-header::before {
    content: "";
    position: absolute;
    top: 50%;
    left: 50%;
    width: 200px;
    height: 200px;
    background: radial-gradient(
        circle,
        rgba(255, 105, 180, 0.1) 0%,
        transparent 70%
    );
    transform: translate(-50%, -50%);
    border-radius: 50%;
    animation: float 8s ease-in-out infinite;
}

.page-header h1 {
    font-size: 3.5rem;
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: var(--spacing-sm);
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    position: relative;
    z-index: 1;
    text-shadow: 0 0 30px rgba(184, 188, 200, 0.3);
}

.page-description {
    font-size: 1.125rem;
    color: var(--text-secondary);
    max-width: 600px;
    margin: 0 auto;
    position: relative;
    z-index: 1;
    line-height: 1.6;
}

/* Filter Section - Retro-Futuristic */
.filter-section {
    margin-bottom: var(--spacing-xl);
    padding: var(--spacing-lg);
    background: var(--card-bg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
    position: relative;
    overflow: hidden;
}

.filter-section::before {
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--gradient-retro-primary);
}

.filter-section h3 {
    margin-bottom: var(--spacing-md);
    color: var(--text-primary);
    background: var(--card-bg);
    font-weight: 600;
    font-size: 1.25rem;
}

.tag-filters {
    display: flex;
    flex-wrap: wrap;
    gap: var(--spacing-sm);
    background: var(--card-bg);
}

.tag-filter {
    padding: var(--spacing-xs) var(--spacing-md);
    border: 1px solid var(--border-color);
    background: var(--bg-color);
    color: var(--text-primary);
    border-radius: var(--radius-full);
    cursor: pointer;
    transition: all var(--transition-fast);
    font-size: 0.875rem;
    font-weight: 600;
    position: relative;
    overflow: hidden;
}

.tag-filter::before {
    content: "";
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
        90deg,
        transparent,
        rgba(255, 105, 180, 0.2),
        transparent
    );
    transition: left 0.6s;
}

.tag-filter:hover {
    background: rgba(255, 105, 180, 0.1);
    border-color: var(--primary-color);
    color: var(--primary-color);
    box-shadow: 0 0 10px rgba(255, 105, 180, 0.3);
    transform: translateY(-1px);
}

.tag-filter:hover::before {
    left: 100%;
}

.tag-filter.active {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border-color: var(--primary-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
}

/* Loading, Error, Empty States - Dark Theme */
.loading-container,
.error-container,
.empty-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: var(--spacing-xxl);
    text-align: center;
    background: var(--card-bg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
    margin: var(--spacing-lg) 0;
}

.loading-container h3,
.error-container h3,
.empty-container h3 {
    color: var(--text-primary);
    margin-bottom: var(--spacing-md);
}

.loading-container p,
.error-container p,
.empty-container p {
    color: var(--text-secondary);
}

.loading-spinner {
    width: 40px;
    height: 40px;
    border: 3px solid var(--border-color);
    border-top: 3px solid var(--primary-color);
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: var(--spacing-md);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.3);
}

@keyframes spin {
    0% {
        transform: rotate(0deg);
    }
    100% {
        transform: rotate(360deg);
    }
}

@keyframes float {
    0%,
    100% {
        transform: translate(-50%, -50%) translateY(0px);
    }
    50% {
        transform: translate(-50%, -50%) translateY(-10px);
    }
}

.error-icon,
.empty-icon {
    font-size: 3rem;
    margin-bottom: var(--spacing-md);
    color: var(--accent-orange);
}

.retry-button,
.link-button {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border: 1px solid var(--primary-color);
    padding: var(--spacing-sm) var(--spacing-lg);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 600;
    transition: all var(--transition-fast);
    margin-top: var(--spacing-md);
    position: relative;
    overflow: hidden;
}

.link-button {
    background: transparent;
    color: var(--primary-color);
    border: none;
    padding: 0;
    text-decoration: underline;
}

.retry-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.4);
}

.link-button:hover {
    background: transparent;
    color: var(--chrome-silver);
    text-decoration: none;
}

/* Articles Grid - Enhanced for Dark Theme */
.articles-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
    gap: var(--spacing-xl);
    margin-bottom: var(--spacing-xl);
}

/* Pagination - Retro-Futuristic */
.pagination {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: var(--spacing-lg);
    margin-bottom: var(--spacing-lg);
    padding: var(--spacing-lg);
    background: var(--card-bg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
}

.pagination-button {
    padding: var(--spacing-sm) var(--spacing-lg);
    border: 1px solid var(--border-color);
    background: var(--bg-color);
    color: var(--text-primary);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 600;
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.pagination-button::before {
    content: "";
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
        90deg,
        transparent,
        rgba(255, 105, 180, 0.2),
        transparent
    );
    transition: left 0.6s;
}

.pagination-button:hover:not(:disabled) {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    transform: translateY(-1px);
}

.pagination-button:hover:not(:disabled)::before {
    left: 100%;
}

.pagination-button:disabled {
    opacity: 0.3;
    cursor: not-allowed;
    background: var(--darker-bg);
}

.pagination-info {
    display: flex;
    align-items: center;
    gap: var(--spacing-xs);
    font-weight: 600;
    padding: var(--spacing-sm) var(--spacing-md);
    background: var(--bg-color);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
}

.pagination-current {
    color: var(--chrome-silver);
    font-weight: 700;
    font-size: 1.1em;
}

.pagination-separator {
    color: var(--text-secondary);
}

/* Results Info - Dark Theme */
.results-info {
    text-align: center;
    color: var(--text-secondary);
    font-size: 0.875rem;
    padding: var(--spacing-md);
    background: var(--card-bg);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
}

.results-info p {
    background: var(--card-bg);
}

/* Responsive Design - Retro-Futuristic Theme */
@media (max-width: 768px) {
    .articles-page {
        padding: var(--spacing-md);
    }

    .page-header h1 {
        font-size: 2.5rem;
    }

    .page-header::before {
        width: 150px;
        height: 150px;
    }

    .filter-section {
        padding: var(--spacing-md);
    }

    .articles-grid {
        grid-template-columns: 1fr;
        gap: var(--spacing-lg);
    }

    .tag-filters {
        justify-content: center;
        gap: var(--spacing-xs);
    }

    .tag-filter {
        font-size: 0.8rem;
        padding: calc(var(--spacing-xs) * 0.75) var(--spacing-sm);
    }

    .pagination {
        flex-direction: column;
        gap: var(--spacing-md);
        padding: var(--spacing-md);
    }

    .pagination-info {
        order: -1;
    }

    .pagination-button {
        padding: var(--spacing-xs) var(--spacing-md);
        font-size: 0.875rem;
    }
}

@media (max-width: 480px) {
    .page-header h1 {
        font-size: 2rem;
        letter-spacing: 0.02em;
    }

    .page-description {
        font-size: 1rem;
    }

    .tag-filters {
        gap: calc(var(--spacing-xs) * 0.5);
    }

    .tag-filter {
        font-size: 0.75rem;
        padding: calc(var(--spacing-xs) * 0.6) var(--spacing-xs);
    }

    .articles-grid {
        gap: var(--spacing-md);
    }

    .loading-container,
    .error-container,
    .empty-container {
        padding: var(--spacing-lg);
        margin: var(--spacing-md) 0;
    }
}
</style>
