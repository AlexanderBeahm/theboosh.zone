<template>
  <div class="admin-dashboard">
    <!-- Header -->
    <div class="dashboard-header">
      <div class="header-content">
        <h1>Admin Dashboard</h1>
        <p class="welcome-message">
          Welcome back, {{ user?.username || "Admin" }}
        </p>
      </div>
    </div>

    <!-- Stats Overview -->
    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-number">
          {{ stats.totalArticles }}
        </div>
        <div class="stat-label">
          Total Articles
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-number">
          {{ stats.publishedArticles }}
        </div>
        <div class="stat-label">
          Published
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-number">
          {{ stats.draftArticles }}
        </div>
        <div class="stat-label">
          Drafts
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-number">
          {{ stats.totalTags }}
        </div>
        <div class="stat-label">
          Tags
        </div>
      </div>
    </div>

    <!-- Filters and Search -->
    <div class="filters-section">
      <div class="search-box">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Search articles..."
          class="search-input"
          @input="debouncedSearch"
        >
      </div>

      <div class="filter-controls">
        <select
          v-model="statusFilter"
          class="filter-select"
          @change="fetchArticles"
        >
          <option value="">
            All Status
          </option>
          <option value="published">
            Published
          </option>
          <option value="draft">
            Drafts
          </option>
        </select>

        <select
          v-model="sortBy"
          class="filter-select"
          @change="fetchArticles"
        >
          <option value="date_updated">
            Recently Updated
          </option>
          <option value="date_added">
            Recently Created
          </option>
          <option value="published_at">
            Recently Published
          </option>
          <option value="title">
            Title A-Z
          </option>
        </select>

        <button
          class="media-library-button"
          @click="$router.push('/admin/media')"
        >
          Media Library
        </button>

        <button
          class="create-article-button"
          @click="showCreateArticle = true"
        >
          New Article
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
      <div class="error-icon">
        ⚠️
      </div>
      <h3>Failed to load articles</h3>
      <p>{{ error }}</p>
      <button
        class="retry-button"
        @click="fetchArticles"
      >
        Try Again
      </button>
    </div>

    <!-- Articles Table -->
    <div
      v-else
      class="articles-section"
    >
      <div class="section-header">
        <h2>Articles ({{ pagination.total_count }})</h2>
      </div>

      <!-- Empty State -->
      <div
        v-if="articles.length === 0"
        class="empty-container"
      >
        <div class="empty-icon">
          📝
        </div>
        <h3>No articles found</h3>
        <p v-if="searchQuery">
          No articles match your search "{{ searchQuery }}".
        </p>
        <p v-else-if="statusFilter">
          No {{ statusFilter }} articles found.
        </p>
        <p v-else>
          Get started by creating your first article!
        </p>
        <button
          class="create-button"
          @click="showCreateArticle = true"
        >
          Create Article
        </button>
      </div>

      <!-- Articles List -->
      <div
        v-else
        class="articles-table"
      >
        <div class="table-header">
          <div class="col-title">
            Title
          </div>
          <div class="col-status">
            Status
          </div>
          <div class="col-updated">
            Updated
          </div>
          <div class="col-actions">
            Actions
          </div>
        </div>

        <div
          v-for="article in articles"
          :key="article.id"
          class="table-row"
        >
          <div class="col-title">
            <div class="article-info">
              <h4 class="article-title">
                {{ article.title }}
              </h4>
              <p
                v-if="article.excerpt"
                class="article-excerpt"
              >
                {{ article.excerpt }}
              </p>
              <div class="article-meta">
                <span class="slug">/{{ article.slug }}</span>
                <div
                  v-if="
                    article.tags && article.tags.length > 0
                  "
                  class="tags"
                >
                  <span
                    v-for="tag in article.tags"
                    :key="tag.id"
                    class="tag"
                  >
                    #{{ tag.name }}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <div class="col-status">
            <span
              class="status-badge"
              :class="{
                published: article.is_published,
                draft: !article.is_published,
              }"
            >
              {{ article.is_published ? "Published" : "Draft" }}
            </span>
            <div
              v-if="article.published_at"
              class="publish-date"
            >
              {{ formatDate(article.published_at) }}
            </div>
          </div>

          <div class="col-updated">
            {{ formatDate(article.date_updated) }}
          </div>

          <div class="col-actions">
            <div class="action-buttons">
              <button
                class="action-button edit-button"
                title="Edit Article"
                aria-label="Edit Article"
                @click="editArticle(article)"
              >
                Edit
              </button>

              <button
                class="action-button view-button"
                title="View Article"
                aria-label="View Article"
                @click="viewArticle(article)"
              >
                View
              </button>

              <button
                class="action-button publish-button"
                :title="
                  article.is_published
                    ? 'Unpublish Article'
                    : 'Publish Article'
                "
                :aria-label="
                  article.is_published
                    ? 'Unpublish Article'
                    : 'Publish Article'
                "
                @click="togglePublish(article)"
              >
                {{
                  article.is_published
                    ? "Unpublish"
                    : "Publish"
                }}
              </button>

              <button
                class="action-button delete-button"
                title="Delete Article"
                aria-label="Delete Article"
                @click="confirmDelete(article)"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
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
    </div>

    <!-- Create/Edit Article Modal -->
    <ArticleEditor
      v-if="showCreateArticle || editingArticle"
      :article="editingArticle"
      :is-visible="showCreateArticle || !!editingArticle"
      @close="closeEditor"
      @saved="handleArticleSaved"
    />

    <!-- Delete Confirmation Modal -->
    <div
      v-if="deleteConfirmation"
      class="modal-overlay"
      @click="cancelDelete"
    >
      <div
        class="modal-content"
        @click.stop
      >
        <h3>Delete Article</h3>
        <p>
          Are you sure you want to delete "<strong>{{
            deleteConfirmation.title
          }}</strong>"? This action cannot be undone.
        </p>
        <div class="modal-actions">
          <button
            class="cancel-button"
            @click="cancelDelete"
          >
            Cancel
          </button>
          <button
            class="delete-button"
            @click="deleteArticle"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import axios from "axios";
import ArticleEditor from "../components/ArticleEditor.vue";
import { useAuth } from "../composables/useAuth";
const { user, requireAuth } = useAuth();

// Reactive state
const articles = ref([]);
const isLoading = ref(true);
const error = ref(null);
const searchQuery = ref("");
const statusFilter = ref("");
const sortBy = ref("date_updated");
const showCreateArticle = ref(false);
const editingArticle = ref(null);
const deleteConfirmation = ref(null);

const pagination = ref({
    current_page: 1,
    total_pages: 1,
    total_count: 0,
    per_page: 20,
    has_next: false,
    has_prev: false,
});

const stats = ref({
    totalArticles: 0,
    publishedArticles: 0,
    draftArticles: 0,
    totalTags: 0,
});

// Computed properties
const currentPage = ref(1);

// Methods
async function checkAuthAndRedirect() {
    const authenticated = await requireAuth("/admin/login");
    if (!authenticated) {
        return false;
    }
    return true;
}

async function fetchArticles() {
    isLoading.value = true;
    error.value = null;

    try {
        const params = {
            page: currentPage.value,
            limit: 20,
        };

        // Add published filter based on status selection using declarative mapping
        const statusMap = {
            published: 1,
            draft: 0,
        };

        if (statusFilter.value in statusMap) {
            params.published = statusMap[statusFilter.value];
        }
        // When statusFilter is "" (all), don't include published param at all

        const response = await axios.get("/api/admin/articles", { params });

        if (response.data.success) {
            articles.value = response.data.articles;
            pagination.value = response.data.pagination;

            // Update stats
            stats.value.totalArticles = response.data.articles.length;
            stats.value.publishedArticles = response.data.articles.filter(
                (a) => a.is_published,
            ).length;
            stats.value.draftArticles = response.data.articles.filter(
                (a) => !a.is_published,
            ).length;
        } else {
            throw new Error(response.data.error || "Failed to fetch articles");
        }
    } catch (err) {
        error.value =
            err.response?.data?.error ||
            err.message ||
            "Failed to load articles";
    } finally {
        isLoading.value = false;
    }
}

async function fetchStats() {
    try {
        // Get basic stats from tags endpoint
        const tagsResponse = await axios.get("/api/tags");
        if (tagsResponse.data.success) {
            stats.value.totalTags =
                tagsResponse.data.pagination?.total_count ||
                tagsResponse.data.tags?.length ||
                0;
        }
    } catch {
        // Failed to fetch stats - non-critical
    }
}

function changePage(page) {
    currentPage.value = page;
    fetchArticles();
}

function editArticle(article) {
    editingArticle.value = article;
}

function viewArticle(article) {
    // Open article in new tab
    const url = `/articles/${article.slug}`;
    window.open(url, "_blank");
}

function closeEditor() {
    showCreateArticle.value = false;
    editingArticle.value = null;
}

function handleArticleSaved() {
    closeEditor();
    fetchArticles(); // Refresh the list
}

async function togglePublish(article) {
    try {
        const response = await axios.put(`/api/admin/articles/${article.id}`, {
            ...article,
            is_published: !article.is_published,
            published_at: !article.is_published
                ? new Date().toISOString()
                : article.published_at,
        });

        if (response.data.success) {
            // Update the article in the list
            const index = articles.value.findIndex((a) => a.id === article.id);
            if (index >= 0) {
                articles.value[index] = response.data.article;
            }
        }
    } catch {
        alert("Failed to update article status");
    }
}

function confirmDelete(article) {
    deleteConfirmation.value = article;
}

function cancelDelete() {
    deleteConfirmation.value = null;
}

async function deleteArticle() {
    if (!deleteConfirmation.value) return;

    try {
        const response = await axios.delete(
            `/api/admin/articles/${deleteConfirmation.value.id}`,
        );

        if (response.data.success) {
            // Remove from list
            articles.value = articles.value.filter(
                (a) => a.id !== deleteConfirmation.value.id,
            );
            deleteConfirmation.value = null;

            // Refresh stats
            fetchArticles();
        }
    } catch {
        alert("Failed to delete article");
    }
}

function formatDate(dateString) {
    if (!dateString) return "";

    const date = new Date(dateString);
    return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
    });
}

// Debounced search function
let searchTimeout;
function debouncedSearch() {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        // For now, we'll just refetch - in a real app you'd implement server-side search
        fetchArticles();
    }, 500);
}

// Lifecycle
onMounted(async () => {
    const authenticated = await checkAuthAndRedirect();
    if (authenticated) {
        await Promise.all([fetchArticles(), fetchStats()]);
    }
});
</script>

<style scoped>
.admin-dashboard {
    max-width: 1400px;
    margin: 0 auto;
    padding: var(--spacing-lg);
    background-color: var(--bg-color);
    min-height: 100vh;
}

/* Header - Retro-Futuristic */
.dashboard-header {
    background: var(--gradient-metallic);
    color: var(--light-text);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    margin-bottom: var(--spacing-xl);
    box-shadow:
        var(--shadow-xl),
        0 0 40px rgba(255, 105, 180, 0.15);
    position: relative;
    overflow: hidden;
}

.dashboard-header::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background:
        linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px),
        linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px);
    background-size: 30px 30px;
    pointer-events: none;
}

.dashboard-header::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: var(--gradient-retro-secondary);
    z-index: 1;
}

.header-content {
    text-align: center;
    position: relative;
    z-index: 2;
}

.dashboard-header h1 {
    font-size: 2.75rem;
    margin: 0 0 var(--spacing-xs) 0;
    font-weight: 700;
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    text-shadow: 0 0 30px rgba(184, 188, 200, 0.3);
}

.welcome-message {
    margin: 0;
    color: var(--light-text);
    font-size: 1.125rem;
    font-weight: 500;
}

/* Stats Grid - Retro-Futuristic */
.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: var(--spacing-lg);
    margin-bottom: var(--spacing-xl);
}

.stat-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-lg);
    text-align: center;
    box-shadow: var(--shadow-md);
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.stat-card::before {
    content: '';
    position: absolute;
    top: -2px;
    left: -2px;
    right: -2px;
    bottom: -2px;
    background: var(--gradient-retro-primary);
    border-radius: var(--radius-lg);
    opacity: 0;
    transition: opacity var(--transition-fast);
    z-index: -1;
}

.stat-card:hover {
    transform: translateY(-4px);
    box-shadow:
        var(--shadow-lg),
        0 0 25px rgba(255, 105, 180, 0.2);
}

.stat-card:hover::before {
    opacity: 0.15;
}

.stat-number {
    font-size: 2.75rem;
    font-weight: 700;
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: var(--spacing-xs);
    position: relative;
    z-index: 1;
}

.stat-label {
    color: var(--text-secondary);
    font-weight: 600;
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    position: relative;
    z-index: 1;
}

/* Filters - Retro-Futuristic */
.filters-section {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--spacing-xl);
    gap: var(--spacing-lg);
    flex-wrap: wrap;
    background: var(--card-bg);
    padding: var(--spacing-lg);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
    position: relative;
}

.filters-section::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--gradient-retro-primary);
}

.search-box {
    flex: 1;
    max-width: 400px;
}

.search-input {
    width: 100%;
    padding: var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    font-size: 1rem;
    background: var(--bg-color);
    color: var(--text-primary);
    transition: all var(--transition-fast);
}

.search-input:focus {
    outline: none;
    border-color: var(--primary-color);
    box-shadow:
        0 0 0 2px rgba(255, 105, 180, 0.2),
        0 0 20px rgba(255, 105, 180, 0.3);
    background: var(--card-bg);
}

.search-input::placeholder {
    color: var(--text-secondary);
}

.filter-controls {
    display: flex;
    gap: var(--spacing-md);
    align-items: center;
}

.filter-select {
    padding: var(--spacing-sm) var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    background: var(--bg-color);
    color: var(--text-primary);
    font-size: 0.875rem;
    font-weight: 500;
    transition: all var(--transition-fast);
}

.filter-select:focus {
    outline: none;
    border-color: var(--primary-color);
    box-shadow: 0 0 0 2px rgba(255, 105, 180, 0.2);
}

.media-library-button,
.create-article-button {
    padding: var(--spacing-sm) var(--spacing-lg);
    border: 1px solid transparent;
    border-radius: var(--radius-md);
    color: var(--light-text);
    font-weight: 700;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all var(--transition-fast);
    white-space: nowrap;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    position: relative;
    overflow: hidden;
}

.media-library-button::before,
.create-article-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.6s;
}

.media-library-button {
    background: linear-gradient(135deg, #36454F, #708090);
    border-color: var(--steel-gray);
}

.media-library-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(112, 128, 144, 0.4);
}

.media-library-button:hover::before {
    left: 100%;
}

.create-article-button {
    background: var(--gradient-retro-primary);
    border-color: var(--primary-color);
}

.create-article-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.4);
}

.create-article-button:hover::before {
    left: 100%;
}

.media-library-button:active,
.create-article-button:active {
    transform: translateY(0);
}

/* Loading and Error States - Dark Theme */
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
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

.empty-icon,
.error-icon {
    font-size: 3rem;
    margin-bottom: var(--spacing-md);
}

.retry-button,
.create-button {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border: 1px solid var(--primary-color);
    padding: var(--spacing-sm) var(--spacing-lg);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 600;
    margin-top: var(--spacing-md);
    transition: all var(--transition-fast);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    position: relative;
    overflow: hidden;
}

.retry-button:hover,
.create-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.4);
}

/* Articles Table - Retro-Futuristic */
.articles-section {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
    box-shadow: var(--shadow-sm);
    position: relative;
}

.articles-section::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: var(--gradient-retro-primary);
    z-index: 1;
}

.section-header {
    padding: var(--spacing-lg);
    border-bottom: 1px solid var(--border-color);
    background: var(--light-bg);
    position: relative;
}

.section-header::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background:
        linear-gradient(90deg, rgba(255, 105, 180, 0.02) 1px, transparent 1px),
        linear-gradient(rgba(255, 105, 180, 0.02) 1px, transparent 1px);
    background-size: 25px 25px;
    pointer-events: none;
}

.section-header h2 {
    margin: 0;
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    font-weight: 700;
    font-size: 1.375rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    position: relative;
    z-index: 1;
}

.articles-table {
    display: flex;
    flex-direction: column;
}

.table-header {
    display: grid;
    grid-template-columns: 1fr 120px 120px 120px;
    gap: var(--spacing-md);
    padding: var(--spacing-lg);
    background: var(--darker-bg);
    border-bottom: 1px solid var(--border-color);
    font-weight: 700;
    color: var(--primary-color);
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    position: relative;
}

.table-header::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 1px;
    background: var(--gradient-retro-secondary);
    opacity: 0.5;
}

.table-row {
    display: grid;
    grid-template-columns: 1fr 120px 120px 120px;
    gap: var(--spacing-md);
    padding: var(--spacing-lg);
    border-bottom: 1px solid var(--border-color);
    transition: all var(--transition-fast);
    position: relative;
}

.table-row::before {
    content: '';
    position: absolute;
    left: -2px;
    top: 0;
    bottom: 0;
    width: 2px;
    background: var(--gradient-retro-primary);
    opacity: 0;
    transition: opacity var(--transition-fast);
}

.table-row:hover {
    background: var(--light-bg);
    box-shadow: inset 0 0 20px rgba(255, 105, 180, 0.05);
}

.table-row:hover::before {
    opacity: 0.7;
}

.table-row:last-child {
    border-bottom: none;
}

.article-title {
    margin: 0 0 var(--spacing-xs) 0;
    font-size: 1.125rem;
    font-weight: 600;
    color: var(--text-primary);
}

.article-excerpt {
    margin: 0 0 var(--spacing-sm) 0;
    color: var(--text-secondary);
    font-size: 0.875rem;
    line-height: 1.4;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
}

.article-meta {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xs);
    font-size: 0.75rem;
    color: var(--text-secondary);
}

.slug {
    font-family: 'SF Mono', 'Menlo', 'Monaco', 'Inconsolata', 'Roboto Mono', 'Consolas', monospace;
    background: var(--darker-bg);
    color: var(--primary-color);
    padding: 3px 6px;
    border-radius: var(--radius-sm);
    border: 1px solid rgba(255, 105, 180, 0.3);
    align-self: flex-start;
    font-size: 0.75rem;
    font-weight: 600;
}

.tags {
    display: flex;
    flex-wrap: wrap;
    gap: var(--spacing-xs);
}

.tag {
    background: rgba(255, 105, 180, 0.1);
    color: var(--primary-color);
    border: 1px solid rgba(255, 105, 180, 0.3);
    padding: 2px 8px;
    border-radius: var(--radius-full);
    font-size: 0.7rem;
    font-weight: 600;
    position: relative;
    overflow: hidden;
    transition: all var(--transition-fast);
}

.tag::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 105, 180, 0.2), transparent);
    transition: left 0.6s;
}

.tag:hover {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 10px rgba(255, 105, 180, 0.4);
}

.tag:hover::before {
    left: 100%;
}

.status-badge {
    display: inline-block;
    padding: var(--spacing-xs) var(--spacing-sm);
    border-radius: var(--radius-full);
    font-size: 0.75rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    border: 1px solid;
    position: relative;
    overflow: hidden;
    transition: all var(--transition-fast);
}

.status-badge::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.6s;
}

.status-badge:hover::before {
    left: 100%;
}

.status-badge.published {
    background: rgba(34, 197, 94, 0.15);
    color: #22C55E;
    border-color: rgba(34, 197, 94, 0.3);
    box-shadow: 0 0 10px rgba(34, 197, 94, 0.2);
}

.status-badge.published:hover {
    background: #22C55E;
    color: var(--bg-color);
    box-shadow: 0 0 15px rgba(34, 197, 94, 0.4);
}

.status-badge.draft {
    background: rgba(204, 136, 0, 0.15);
    color: var(--accent-amber);
    border-color: rgba(204, 136, 0, 0.3);
    box-shadow: 0 0 10px rgba(204, 136, 0, 0.2);
}

.status-badge.draft:hover {
    background: var(--accent-amber);
    color: var(--bg-color);
    box-shadow: 0 0 15px rgba(204, 136, 0, 0.4);
}

.publish-date {
    font-size: 0.75rem;
    color: var(--text-secondary);
    margin-top: var(--spacing-xs);
}

.action-buttons {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xs);
    width: 100%;
}

.action-button {
    width: 100%;
    padding: var(--spacing-xs) var(--spacing-sm);
    border: 1px solid;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-size: 0.75rem;
    font-weight: 700;
    transition: all var(--transition-fast);
    display: flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    position: relative;
    overflow: hidden;
}

.action-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.6s;
}

.action-button:hover::before {
    left: 100%;
}

.edit-button {
    background: rgba(255, 105, 180, 0.1);
    color: var(--primary-color);
    border-color: rgba(255, 105, 180, 0.3);
}

.edit-button:hover {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    transform: translateY(-1px);
}

.view-button {
    background: rgba(255, 105, 180, 0.1);
    color: var(--primary-color);
    border-color: rgba(255, 105, 180, 0.3);
}

.view-button:hover {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    transform: translateY(-1px);
}

.publish-button {
    background: rgba(34, 197, 94, 0.1);
    color: #22C55E;
    border-color: rgba(34, 197, 94, 0.3);
}

.publish-button:hover {
    background: #22C55E;
    color: var(--bg-color);
    border-color: #22C55E;
    box-shadow: 0 0 15px rgba(34, 197, 94, 0.4);
    transform: translateY(-1px);
}

.delete-button {
    background: rgba(255, 69, 0, 0.1);
    color: var(--accent-orange);
    border-color: rgba(255, 69, 0, 0.3);
}

.delete-button:hover {
    background: var(--accent-orange);
    color: var(--bg-color);
    border-color: var(--accent-orange);
    box-shadow: 0 0 15px rgba(255, 69, 0, 0.4);
    transform: translateY(-1px);
}

/* Pagination - Retro-Futuristic */
.pagination {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: var(--spacing-lg);
    padding: var(--spacing-lg);
    border-top: 1px solid var(--border-color);
    background: var(--darker-bg);
    position: relative;
}

.pagination::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--gradient-retro-secondary);
    opacity: 0.6;
}

.pagination-button {
    padding: var(--spacing-sm) var(--spacing-lg);
    border: 1px solid var(--primary-color);
    background: rgba(255, 105, 180, 0.1);
    color: var(--primary-color);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 700;
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.pagination-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 105, 180, 0.2), transparent);
    transition: left 0.6s;
}

.pagination-button:hover:not(:disabled) {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.4);
    transform: translateY(-2px);
}

.pagination-button:hover:not(:disabled)::before {
    left: 100%;
}

.pagination-button:disabled {
    opacity: 0.3;
    cursor: not-allowed;
    background: var(--darker-bg);
    color: var(--text-secondary);
    border-color: var(--border-color);
    transform: none;
}

.pagination-info {
    display: flex;
    align-items: center;
    gap: var(--spacing-sm);
    font-weight: 600;
    font-size: 1rem;
    color: var(--text-primary);
    background: var(--card-bg);
    padding: var(--spacing-sm) var(--spacing-md);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
}

.pagination-current {
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    font-weight: 700;
    font-size: 1.125rem;
}

.pagination-separator {
    color: var(--text-secondary);
    margin: 0 var(--spacing-xs);
}

.pagination-total {
    color: var(--primary-color);
    font-weight: 700;
}

/* Modal - Retro-Futuristic */
.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(8px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
    animation: modalFadeIn 0.3s ease-out;
}

@keyframes modalFadeIn {
    from {
        opacity: 0;
        backdrop-filter: blur(0px);
    }
    to {
        opacity: 1;
        backdrop-filter: blur(8px);
    }
}

.modal-content {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    max-width: 450px;
    width: 90%;
    box-shadow:
        var(--shadow-xl),
        0 0 50px rgba(255, 105, 180, 0.2);
    position: relative;
    overflow: hidden;
    animation: modalSlideIn 0.3s ease-out;
}

@keyframes modalSlideIn {
    from {
        transform: translateY(-20px) scale(0.95);
        opacity: 0;
    }
    to {
        transform: translateY(0) scale(1);
        opacity: 1;
    }
}

.modal-content::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: var(--gradient-retro-primary);
    z-index: 1;
}

.modal-content::after {
    content: '';
    position: absolute;
    top: -2px;
    left: -2px;
    right: -2px;
    bottom: -2px;
    background: var(--gradient-retro-secondary);
    border-radius: var(--radius-lg);
    opacity: 0.1;
    z-index: -1;
}

.modal-content h3 {
    margin-top: 0;
    margin-bottom: var(--spacing-md);
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    font-weight: 700;
    font-size: 1.5rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    position: relative;
    z-index: 2;
}

.modal-content p {
    color: var(--text-primary);
    line-height: 1.6;
    margin-bottom: var(--spacing-lg);
    position: relative;
    z-index: 2;
}

.modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--spacing-md);
    margin-top: var(--spacing-lg);
    position: relative;
    z-index: 2;
}

.cancel-button,
.modal-content .delete-button {
    padding: var(--spacing-sm) var(--spacing-lg);
    border: 1px solid;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 700;
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.cancel-button::before,
.modal-content .delete-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.6s;
}

.cancel-button {
    background: rgba(255, 105, 180, 0.1);
    color: var(--primary-color);
    border-color: var(--primary-color);
}

.cancel-button:hover {
    background: var(--primary-color);
    color: var(--bg-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.4);
    transform: translateY(-2px);
}

.cancel-button:hover::before {
    left: 100%;
}

.modal-content .delete-button {
    background: rgba(255, 69, 0, 0.1);
    color: var(--accent-orange);
    border-color: var(--accent-orange);
}

.modal-content .delete-button:hover {
    background: var(--accent-orange);
    color: var(--bg-color);
    border-color: var(--accent-orange);
    box-shadow: 0 0 20px rgba(255, 69, 0, 0.4);
    transform: translateY(-2px);
}

.modal-content .delete-button:hover::before {
    left: 100%;
}

/* Responsive Design */
@media (max-width: 1024px) {
    .table-header,
    .table-row {
        grid-template-columns: 1fr 100px 100px 100px;
    }
}

@media (max-width: 768px) {
    .admin-dashboard {
        padding: var(--spacing-md);
    }

    .dashboard-header h1 {
        font-size: 2rem;
    }

    .filters-section {
        flex-direction: column;
        align-items: stretch;
    }

    .search-box {
        max-width: none;
    }

    .filter-controls {
        flex-wrap: wrap;
    }

    .filter-select {
        flex: 1;
        min-width: 150px;
    }

    .create-article-button {
        width: 100%;
    }

    .table-header {
        display: none;
    }

    .table-row {
        grid-template-columns: 1fr;
        gap: var(--spacing-md);
        padding: var(--spacing-md);
    }

    .col-status,
    .col-updated,
    .col-actions {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .col-status::before {
        content: "Status: ";
        font-weight: 600;
    }

    .col-updated::before {
        content: "Updated: ";
        font-weight: 600;
    }

    .col-actions::before {
        content: "Actions: ";
        font-weight: 600;
    }

    .stats-grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (max-width: 480px) {
    .stats-grid {
        grid-template-columns: 1fr;
    }

    .action-buttons {
        flex-wrap: wrap;
    }
}
</style>
