<template>
  <div class="home-page">
    <!-- Page Header -->
    <div class="page-header">
      <HeroBurst size="medium" />
      <h1>TheBoosh.Zone</h1>
      <h2 class="page-description">
        Welcome to my zone.
      </h2>
    </div>

    <!-- Articles Feed -->
    <div class="articles-feed">
      <!-- Loading State (Initial) -->
      <div
        v-if="isInitialLoading"
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
          @click="fetchInitialArticles"
        >
          Try Again
        </button>
      </div>

      <!-- Empty State -->
      <div
        v-else-if="articles.length === 0"
        class="empty-container"
      >
        <h3>No articles yet</h3>
        <p>Check back soon for new content!</p>
      </div>

      <!-- Articles List -->
      <div
        v-else
        class="articles-list"
      >
        <ArticleCard
          v-for="article in articles"
          :key="article.id"
          :article="article"
          @click="navigateToArticle(article.slug)"
          @tag-click="navigateToTag"
        />

        <!-- Loading More Indicator -->
        <div
          v-if="isLoadingMore"
          class="loading-more"
        >
          <div class="loading-spinner" />
          <p>Loading more articles...</p>
        </div>

        <!-- End of Articles -->
        <div
          v-else-if="!hasMore && articles.length > 0"
          class="end-message"
        >
          <p>You've reached the end of the articles</p>
          <router-link
            to="/articles"
            class="view-all-link"
          >
            View all articles →
          </router-link>
        </div>

        <!-- Intersection Observer Sentinel -->
        <div
          ref="sentinel"
          class="sentinel"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import axios from "axios";
import ArticleCard from "../components/ArticleCard.vue";
import HeroBurst from "../components/HeroBurst.vue";

const router = useRouter();

// Reactive state
const articles = ref([]);
const isInitialLoading = ref(true);
const isLoadingMore = ref(false);
const error = ref(null);
const currentPage = ref(1);
const hasMore = ref(true);
const sentinel = ref(null);
let observer = null;

// Constants
const ARTICLES_PER_PAGE = 5;

// Methods
async function fetchArticles(page) {
    const response = await axios.get("/api/articles", {
        params: {
            page,
            limit: ARTICLES_PER_PAGE,
        },
    });

    if (response.data.success) {
        return {
            articles: response.data.articles || [],
            pagination: response.data.pagination,
        };
    } else {
        throw new Error(response.data.error || "Failed to fetch articles");
    }
}

async function fetchInitialArticles() {
    isInitialLoading.value = true;
    error.value = null;
    articles.value = [];
    currentPage.value = 1;

    try {
        const { articles: fetchedArticles, pagination } =
            await fetchArticles(1);
        articles.value = fetchedArticles;
        hasMore.value = pagination.has_next || false;
    } catch (err) {
        error.value =
            err.response?.data?.error ||
            err.message ||
            "Failed to load articles";
    } finally {
        isInitialLoading.value = false;
    }
}

async function loadMoreArticles() {
    if (isLoadingMore.value || !hasMore.value) return;

    isLoadingMore.value = true;

    try {
        currentPage.value++;
        const { articles: fetchedArticles, pagination } = await fetchArticles(
            currentPage.value,
        );

        articles.value.push(...fetchedArticles);
        hasMore.value = pagination.has_next || false;
    } catch {
        currentPage.value--; // Revert page increment on error
    } finally {
        isLoadingMore.value = false;
    }
}

function navigateToArticle(slug) {
    router.push({
        name: "Article",
        params: { slug },
    });
}

function navigateToTag(tagSlug) {
    router.push({
        name: "Articles",
        query: { tag: tagSlug },
    });
}

function setupIntersectionObserver() {
    if (!sentinel.value) return;

    const options = {
        root: null,
        rootMargin: "100px", // Trigger 100px before reaching the sentinel
        threshold: 0,
    };

    observer = new IntersectionObserver((entries) => {
        const entry = entries[0];
        if (entry.isIntersecting && hasMore.value && !isLoadingMore.value) {
            loadMoreArticles();
        }
    }, options);

    observer.observe(sentinel.value);
}

function cleanup() {
    if (observer && sentinel.value) {
        observer.unobserve(sentinel.value);
        observer.disconnect();
    }
}

// Lifecycle
onMounted(async () => {
    await fetchInitialArticles();
    setupIntersectionObserver();
});

onUnmounted(() => {
    cleanup();
});
</script>

<style scoped>
.home-page {
    max-width: 1200px;
    margin: 0 auto;
    padding: var(--spacing-lg);
    background-color: var(--bg-color);
    min-height: 100vh;
}

/* Page Header - Standardized Design */
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
    font-size: clamp(2rem, 4vw + 1rem, 3.5rem);
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: var(--spacing-sm);
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: clamp(0.02em, 0.05em, 0.08em);
    position: relative;
    z-index: 2;
    text-shadow: 0 0 clamp(20px, 2vw, 30px) rgba(184, 188, 200, 0.3);
    -webkit-text-stroke: clamp(1px, 0.15vw, 2px) black; /* width and color */
}

.page-description {
    font-size: clamp(1rem, 2vw + 0.5rem, 1.125rem);
    color: var(--text-secondary);
    max-width: 600px;
    margin: 0 auto;
    position: relative;
    z-index: 2;
    line-height: 1.6;
    text-shadow:
        1px 1px 0 #000,
        -1px 1px 0 #000,
        1px -1px 0 #000,
        -1px -1px 0 #000,
        0px 1px 0 #000,
        0px -1px 0 #000,
        -1px 0px 0 #000,
        1px 0px 0 #000,
        2px 2px 0 #000,
        -2px 2px 0 #000,
        2px -2px 0 #000,
        -2px -2px 0 #000,
        0px 2px 0 #000,
        0px -2px 0 #000,
        -2px 0px 0 #000,
        2px 0px 0 #000,
        1px 2px 0 #000,
        -1px 2px 0 #000,
        1px -2px 0 #000,
        -1px -2px 0 #000,
        2px 1px 0 #000,
        -2px 1px 0 #000,
        2px -1px 0 #000,
        -2px -1px 0 #000;
}

/* Animation for floating background */
@keyframes float {
    0%,
    100% {
        transform: translate(-50%, -50%) translateY(0px);
    }
    50% {
        transform: translate(-50%, -50%) translateY(-10px);
    }
}

/* Articles Feed - Dark Theme */
.articles-feed {
    flex: 1;
    max-width: 800px;
    margin: 0 auto;
    width: 100%;
    padding: var(--spacing-xl) var(--spacing-lg);
    background-color: var(--bg-color);
}

.articles-list {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xl);
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
    min-height: 200px;
    background-color: var(--card-bg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
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
    box-shadow: 0 0 10px rgba(255, 105, 180, 0.3);
}

@keyframes spin {
    0% {
        transform: rotate(0deg);
    }
    100% {
        transform: rotate(360deg);
    }
}

.retry-button {
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

.retry-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.4);
}

.retry-button:active {
    transform: translateY(0);
}

/* Loading More - Dark Theme */
.loading-more {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: var(--spacing-lg);
    background-color: var(--card-bg);
    border-radius: var(--radius-md);
    margin-top: var(--spacing-lg);
}

.loading-more p {
    margin: 0;
    color: var(--text-secondary);
}

/* End Message - Dark Theme */
.end-message {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: var(--spacing-xl);
    text-align: center;
    background-color: var(--card-bg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
    margin-top: var(--spacing-lg);
}

.end-message p {
    margin: 0 0 var(--spacing-md) 0;
    color: var(--text-secondary);
    background-color: var(--card-bg);
}

.view-all-link {
    color: var(--primary-color);
    text-decoration: none;
    font-weight: 600;
    padding: var(--spacing-sm) var(--spacing-lg);
    border: 1px solid var(--primary-color);
    border-radius: var(--radius-md);
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.view-all-link:hover {
    background-color: var(--primary-color);
    color: var(--bg-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    transform: translateY(-1px);
}

/* Sentinel (Invisible Intersection Observer Target) */
.sentinel {
    height: 1px;
    visibility: hidden;
}

/* Responsive Design - Retro-Futuristic Theme */
@media (max-width: 768px) {
    .hero-header {
        min-height: 50vh;
        padding: var(--spacing-lg);
    }

    .hero-header h1 {
        letter-spacing: 0.05em;
    }

    .articles-feed {
        padding: var(--spacing-lg) var(--spacing-md);
    }

    .loading-container,
    .error-container,
    .empty-container {
        padding: var(--spacing-lg);
        margin: var(--spacing-md);
    }
}

@media (max-width: 480px) {
    .hero-header {
        min-height: 40vh;
        padding: var(--spacing-md);
    }

    .hero-header h1 {
        letter-spacing: 0.05em;
        line-height: 1.2;
    }

    .articles-list {
        gap: var(--spacing-lg);
    }

    .articles-feed {
        padding: var(--spacing-md);
    }

    .retry-button,
    .view-all-link {
        padding: var(--spacing-xs) var(--spacing-md);
        font-size: 0.875rem;
    }
}
</style>
