<template>
    <div class="article-page">
        <!-- Loading State -->
        <div v-if="isLoading" class="loading-container">
            <div class="loading-spinner" />
            <p>Loading article...</p>
        </div>

        <!-- Error State -->
        <div v-else-if="error" class="error-container">
            <h2>Article not found</h2>
            <p>{{ error }}</p>
            <div class="error-actions">
                <button class="back-button" @click="$router.push('/articles')">
                    ← Back to Articles
                </button>
                <button class="retry-button" @click="fetchArticle">
                    Try Again
                </button>
            </div>
        </div>

        <!-- Article Content -->
        <article v-else class="article-container">
            <!-- Article Header -->
            <header class="article-header">
                <div class="breadcrumb">
                    <router-link to="/articles" class="breadcrumb-link">
                        Articles
                    </router-link>
                    <span class="breadcrumb-separator">→</span>
                    <span class="breadcrumb-current">{{ article.title }}</span>
                </div>

                <h1 class="article-title">
                    {{ article.title }}
                </h1>

                <div class="article-meta">
                    <div class="meta-item">
                        <span class="meta-label">Published:</span>
                        <time
                            :datetime="
                                article.published_at || article.date_added
                            "
                        >
                            {{
                                formatDate(
                                    article.published_at || article.date_added,
                                )
                            }}
                        </time>
                    </div>

                    <div class="meta-item">
                        <span class="meta-label">Author:</span>
                        <span class="meta-value">{{ article.author }}</span>
                    </div>

                    <div
                        v-if="article.date_updated !== article.date_added"
                        class="meta-item"
                    >
                        <span class="meta-label">Updated:</span>
                        <time :datetime="article.date_updated">
                            {{ formatDate(article.date_updated) }}
                        </time>
                    </div>
                </div>

                <div
                    v-if="article.tags && article.tags.length > 0"
                    class="article-tags"
                >
                    <router-link
                        v-for="tag in article.tags"
                        :key="tag.id"
                        :to="{ path: '/articles', query: { tag: tag.slug } }"
                        class="article-tag"
                    >
                        #{{ tag.name }}
                    </router-link>
                </div>

                <div v-if="article.excerpt" class="article-excerpt">
                    <p>{{ article.excerpt }}</p>
                </div>
            </header>

            <!-- Featured Image -->
            <div v-if="article.featured_image" class="featured-image">
                <img
                    :src="article.featured_image"
                    :alt="article.title"
                    loading="eager"
                />
            </div>

            <!-- Article Content -->
            <div class="article-body">
                <MarkdownRenderer :content="article.content" :sanitize="true" />
            </div>

            <!-- Article Footer -->
            <footer class="article-footer">
                <div class="article-actions">
                    <button
                        class="share-button"
                        title="Share article"
                        @click="shareArticle"
                    >
                        Share
                    </button>

                    <button
                        class="scroll-top-button"
                        title="Scroll to top"
                        @click="scrollToTop"
                    >
                        ↑ Top
                    </button>
                </div>

                <div class="article-navigation">
                    <router-link to="/articles" class="back-to-articles">
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
import { ref, onMounted, onUnmounted, watch } from "vue";
import { useRoute, onBeforeRouteLeave } from "vue-router";
import axios from "axios";
import MarkdownRenderer from "../components/MarkdownRenderer.vue";

const route = useRoute();

// Reactive state
const article = ref({});
const isLoading = ref(true);
const error = ref(null);
// const relatedArticles = ref([]) // For future implementation

// Methods
async function fetchArticle() {
    isLoading.value = true;
    error.value = null;

    try {
        const slug = route.params.slug;
        if (!slug) {
            throw new Error("Article slug is required");
        }

        const response = await axios.get(`/api/articles/${slug}`);

        if (response.data.success) {
            article.value = response.data.article;

            // Update page title and meta description
            document.title = `${article.value.title} - TheBoosh.Zone`;

            if (article.value.meta_description) {
                updateMetaDescription(article.value.meta_description);
            }
        } else {
            throw new Error(response.data.error || "Article not found");
        }
    } catch (err) {
        error.value =
            err.response?.data?.error ||
            err.message ||
            "Failed to load article";

        // Update page title for error state
        document.title = "Article Not Found - TheBoosh.Zone";

        // If 404, show a more user-friendly message
        if (err.response?.status === 404) {
            error.value =
                "This article could not be found. It may have been moved or deleted.";
        }
    } finally {
        isLoading.value = false;
    }
}

function formatDate(dateString) {
    if (!dateString) return "";

    const date = new Date(dateString);
    return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
        day: "numeric",
    });
}

function shareArticle() {
    if (navigator.share) {
        // Use native Web Share API if available
        navigator
            .share({
                title: article.value.title,
                text: article.value.excerpt || article.value.title,
                url: window.location.href,
            })
            .catch(() => {
                fallbackShare();
            });
    } else {
        fallbackShare();
    }
}

function fallbackShare() {
    // Copy URL to clipboard as fallback
    navigator.clipboard
        .writeText(window.location.href)
        .then(() => {
            // Could show a toast notification here
            alert("Article URL copied to clipboard!");
        })
        .catch(() => {
            // Fallback for older browsers
            const textArea = document.createElement("textarea");
            textArea.value = window.location.href;
            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();
            try {
                document.execCommand("copy");
                alert("Article URL copied to clipboard!");
            } catch {
                // Clipboard copy failed
            }
            document.body.removeChild(textArea);
        });
}

function scrollToTop() {
    window.scrollTo({
        top: 0,
        behavior: "smooth",
    });
}

function updateMetaDescription(description) {
    // Update or create meta description tag
    let metaDescription = document.querySelector('meta[name="description"]');

    if (metaDescription) {
        metaDescription.setAttribute("content", description);
    } else {
        metaDescription = document.createElement("meta");
        metaDescription.name = "description";
        metaDescription.content = description;
        document.head.appendChild(metaDescription);
    }
}

function resetPageMeta() {
    // Reset page title
    document.title = "TheBoosh.Zone";

    // Reset meta description
    const metaDescription = document.querySelector('meta[name="description"]');
    if (metaDescription) {
        metaDescription.setAttribute(
            "content",
            "Alex Beahm's personal portfolio and blog website",
        );
    }
}

// Watch for route changes to fetch new article
watch(
    () => route.params.slug,
    () => {
        if (route.name === "Article") {
            fetchArticle();
        }
    },
    { immediate: false },
);

// Lifecycle
onMounted(() => {
    fetchArticle();
});

// Cleanup when leaving the page
onBeforeRouteLeave((to, from, next) => {
    resetPageMeta();
    next();
});

// Also cleanup when component is unmounted
onUnmounted(() => {
    resetPageMeta();
});
</script>

<style scoped>
.article-page {
    max-width: 800px;
    margin: 0 auto;
    padding: var(--spacing-lg);
    background-color: var(--bg-color);
    min-height: 100vh;
}

/* Loading and Error States - Dark Theme */
.loading-container,
.error-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: var(--spacing-xxl);
    text-align: center;
    min-height: 50vh;
    background: var(--card-bg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
    margin: var(--spacing-lg) 0;
}

.loading-container h2,
.error-container h2 {
    color: var(--text-primary);
    margin-bottom: var(--spacing-md);
}

.loading-container p,
.error-container p {
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

.error-icon {
    font-size: 3rem;
    margin-bottom: var(--spacing-md);
    color: var(--accent-orange);
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
    background: var(--bg-color);
    color: var(--text-primary);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 600;
    transition: all var(--transition-fast);
    text-decoration: none;
    position: relative;
    overflow: hidden;
}

.retry-button {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border-color: var(--primary-color);
}

.back-button:hover {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    transform: translateY(-1px);
}

.retry-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.4);
}

/* Article Container - Retro-Futuristic */
.article-container {
    background: var(--card-bg);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-lg);
    overflow: hidden;
    border: 1px solid var(--border-color);
    position: relative;
}

.article-container::before {
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: var(--gradient-retro-secondary);
    z-index: 1;
}

/* Article Header - Enhanced */
.article-header {
    padding: var(--spacing-xl);
    border-bottom: 1px solid var(--border-color);
    position: relative;
}

.breadcrumb {
    display: flex;
    align-items: center;
    font-size: 0.875rem;
    color: var(--text-secondary);
    margin-bottom: var(--spacing-lg);
    font-weight: 500;
}

.breadcrumb-link {
    color: var(--primary-color);
    text-decoration: none;
    font-weight: 600;
    transition: all var(--transition-fast);
}

.breadcrumb-link:hover {
    color: var(--chrome-silver);
    text-shadow: 0 0 5px rgba(184, 188, 200, 0.3);
}

.breadcrumb-separator {
    margin: 0 var(--spacing-sm);
    color: var(--border-color);
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
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    background-size: 200% 200%;
    animation: gradientShift 8s ease infinite;
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
    padding: var(--spacing-xs) var(--spacing-sm);
    background: var(--bg-color);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-color);
}

.meta-label {
    color: var(--text-secondary);
    font-weight: 500;
}

.meta-value,
.meta-item time {
    color: var(--primary-color);
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
    background: rgba(255, 105, 180, 0.1);
    border: 1px solid rgba(255, 105, 180, 0.3);
    padding: var(--spacing-xs) var(--spacing-md);
    border-radius: var(--radius-full);
    text-decoration: none;
    font-weight: 600;
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.article-tag::before {
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

.article-tag:hover {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 10px rgba(255, 105, 180, 0.4);
    transform: translateY(-1px);
}

.article-tag:hover::before {
    left: 100%;
}

.article-excerpt {
    padding: var(--spacing-lg);
    background: linear-gradient(
        135deg,
        var(--card-bg) 0%,
        var(--light-bg) 100%
    );
    border-radius: var(--radius-md);
    border-left: 4px solid var(--chrome-silver);
    margin-bottom: var(--spacing-lg);
    position: relative;
    overflow: hidden;
}

.article-excerpt::before {
    content: "";
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    width: 2px;
    background: var(--gradient-retro-primary);
}

.article-excerpt p {
    font-size: 1.125rem;
    line-height: 1.6;
    color: var(--text-primary);
    margin: 0;
    font-style: italic;
    position: relative;
    z-index: 1;
    background: transparent;
}

/* Featured Image - Retro Enhancement */
.featured-image {
    width: 100%;
    max-height: 400px;
    overflow: hidden;
    position: relative;
}

.featured-image::after {
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(
        135deg,
        rgba(255, 105, 180, 0.05) 0%,
        transparent 30%,
        transparent 70%,
        rgba(255, 105, 180, 0.05) 100%
    );
    pointer-events: none;
}

.featured-image img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
    transition: transform 0.3s ease;
}

.article-container:hover .featured-image img {
    transform: scale(1.02);
}

/* Article Body - Enhanced Typography */
.article-body {
    padding: var(--spacing-xl);
    line-height: 1.8;
    font-size: 1.125rem;
    color: var(--text-primary);
    background: var(--card-bg);
}

.article-body * {
    background: transparent;
}

/* Article Footer - Retro-Futuristic */
.article-footer {
    padding: var(--spacing-xl);
    border-top: 1px solid var(--border-color);
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: var(--spacing-lg);
    background: linear-gradient(
        135deg,
        var(--card-bg) 0%,
        var(--light-bg) 100%
    );
    position: relative;
}

.article-footer::before {
    content: "";
    position: absolute;
    top: 0;
    left: var(--spacing-lg);
    right: var(--spacing-lg);
    height: 1px;
    background: var(--gradient-retro-secondary);
}

.article-actions {
    display: flex;
    gap: var(--spacing-md);
    background: transparent;
}

.share-button,
.scroll-top-button {
    padding: var(--spacing-sm) var(--spacing-md);
    border: 1px solid var(--border-color);
    background: var(--bg-color);
    color: var(--text-primary);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-size: 0.875rem;
    font-weight: 600;
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.share-button::before,
.scroll-top-button::before {
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

.share-button:hover,
.scroll-top-button:hover {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    transform: translateY(-1px);
}

.share-button:hover::before,
.scroll-top-button:hover::before {
    left: 100%;
}

.back-to-articles {
    text-decoration: none;
    font-weight: 600;
    padding: var(--spacing-sm) var(--spacing-md);
    border-radius: var(--radius-md);
    border: 1px solid var(--primary-color);
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
    color: var(--text-primary);
}

.back-to-articles::before {
    content: "";
    position: absolute;
    top: 0;
    width: 100%;
    height: 100%;
    transition: left 0.6s;
}

.back-to-articles:hover {
    background: var(--primary-color);
    color: var(--bg-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    transform: translateY(-1px);
}

/* Related Articles - Retro-Futuristic (for future use) */
.related-articles {
    margin-top: var(--spacing-xxl);
    padding: var(--spacing-xl);
    background: var(--card-bg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
    position: relative;
}

.related-articles::before {
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--gradient-retro-primary);
}

.related-articles h3 {
    margin-bottom: var(--spacing-lg);
    color: var(--text-primary);
    font-weight: 600;
    font-size: 1.5rem;
}

.related-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
    gap: var(--spacing-lg);
}

.related-article {
    padding: var(--spacing-lg);
    background: var(--bg-color);
    border-radius: var(--radius-md);
    text-decoration: none;
    color: var(--text-primary);
    transition: all var(--transition-fast);
    border: 1px solid var(--border-color);
    position: relative;
    overflow: hidden;
}

.related-article::before {
    content: "";
    position: absolute;
    top: -1px;
    left: -1px;
    right: -1px;
    bottom: -1px;
    background: var(--gradient-retro-secondary);
    border-radius: var(--radius-md);
    opacity: 0;
    transition: opacity var(--transition-fast);
    z-index: -1;
}

.related-article:hover {
    transform: translateY(-4px);
    box-shadow: var(--shadow-lg);
}

.related-article:hover::before {
    opacity: 0.3;
}

.related-article h4 {
    margin-bottom: var(--spacing-sm);
    color: var(--primary-color);
    font-weight: 600;
    transition: color var(--transition-fast);
}

.related-article:hover h4 {
    color: var(--chrome-silver);
}

.related-article p {
    color: var(--text-secondary);
    font-size: 0.875rem;
    line-height: 1.5;
}

/* Responsive Design - Retro-Futuristic Theme */
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
        background-size: 100% 100%;
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
        background: var(--card-bg);
    }

    .breadcrumb-current {
        max-width: 200px;
    }

    .error-actions {
        flex-direction: column;
        align-items: center;
    }

    .featured-image {
        max-height: 300px;
    }
}

@media (max-width: 480px) {
    .article-title {
        font-size: 1.75rem;
        letter-spacing: 0.02em;
    }

    .article-body {
        font-size: 1rem;
        line-height: 1.7;
        padding: var(--spacing-md);
    }

    .article-header {
        padding: var(--spacing-md);
    }

    .article-footer {
        padding: var(--spacing-md);
    }

    .article-actions {
        flex-direction: column;
    }

    .meta-item {
        font-size: 0.8rem;
        padding: calc(var(--spacing-xs) * 0.75) var(--spacing-xs);
    }

    .article-tags {
        gap: var(--spacing-xs);
    }

    .article-tag {
        font-size: 0.8rem;
        padding: calc(var(--spacing-xs) * 0.75) var(--spacing-sm);
    }
}
</style>
