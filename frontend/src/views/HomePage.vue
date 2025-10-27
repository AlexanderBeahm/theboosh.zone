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
                <div class="loading-spinner" />
                <p>Loading articles...</p>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="error-container">
                <h3>Failed to load articles</h3>
                <p>{{ error }}</p>
                <button class="retry-button" @click="fetchInitialArticles">
                    Try Again
                </button>
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
                    <div class="loading-spinner" />
                    <p>Loading more articles...</p>
                </div>

                <!-- End of Articles -->
                <div
                    v-else-if="!hasMore && articles.length > 0"
                    class="end-message"
                >
                    <p>You've reached the end of the articles</p>
                    <router-link to="/articles" class="view-all-link">
                        View all articles →
                    </router-link>
                </div>

                <!-- Intersection Observer Sentinel -->
                <div ref="sentinel" class="sentinel" />
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import axios from "axios";
import ArticleCard from "../components/ArticleCard.vue";

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
    min-height: 100vh;
    display: flex;
    flex-direction: column;
}

/* Hero Header - Retro-Futuristic Design */
.hero-header {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 60vh;
    padding: var(--spacing-xl);
    background: var(--bg-color);
    background-size:
        40px 40px,
        40px 40px,
        100% 100%;
    position: relative;
    overflow: hidden;
}

/* Animated background elements */
.hero-header::before {
    content: "";
    position: absolute;
    top: -50%;
    left: -50%;
    right: -50%;
    bottom: -50%;
    background: var(--bg-color);
    z-index: 0;
}

.hero-header::after {
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: var(--bg-color);
    background-size: 60px 60px;
    animation: slidePattern 30s linear infinite;
    z-index: 0;
}

.hero-header h1 {
    color: var(--light-text);
    font-size: 5rem;
    font-weight: 700;
    margin: 0;
    text-align: center;
    position: relative;
    z-index: 2;

    /* Retro-futuristic gradient text effect */
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;

    /* Glowing text shadow */
    text-shadow:
        0 0 20px rgba(184, 188, 200, 0.3),
        0 0 40px rgba(255, 105, 180, 0.2),
        0 0 60px rgba(255, 105, 180, 0.1);

    /* Text animation */
    animation: textGlow 4s ease-in-out infinite alternate;

    /* Letter spacing for retro effect */
    letter-spacing: 0.1em;
    text-transform: uppercase;

    /* Ensure fallback for browsers without clip support */
    background-size: 200% 200%;
    animation:
        textGlow 4s ease-in-out infinite alternate,
        gradientShift 8s ease infinite;
}

/* Animations */
@keyframes float {
    0%,
    100% {
        transform: translate(0, 0) rotate(0deg);
    }
    25% {
        transform: translate(10px, -10px) rotate(1deg);
    }
    50% {
        transform: translate(-5px, 5px) rotate(-1deg);
    }
    75% {
        transform: translate(-10px, -5px) rotate(1deg);
    }
}

@keyframes slidePattern {
    0% {
        transform: translate(0, 0);
    }
    100% {
        transform: translate(60px, 60px);
    }
}

@keyframes textGlow {
    0% {
        text-shadow:
            0 0 20px rgba(184, 188, 200, 0.3),
            0 0 40px rgba(255, 105, 180, 0.2),
            0 0 60px rgba(255, 105, 180, 0.1);
    }
    100% {
        text-shadow:
            0 0 30px rgba(184, 188, 200, 0.5),
            0 0 60px rgba(255, 105, 180, 0.3),
            0 0 80px rgba(255, 105, 180, 0.2);
    }
}

@keyframes gradientShift {
    0% {
        background-position: 0% 50%;
    }
    50% {
        background-position: 100% 50%;
    }
    100% {
        background-position: 0% 50%;
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
        font-size: 3.5rem;
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
        font-size: 2.5rem;
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
