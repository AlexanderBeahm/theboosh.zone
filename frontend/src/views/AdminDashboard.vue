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
                <div class="stat-number">{{ stats.totalArticles }}</div>
                <div class="stat-label">Total Articles</div>
            </div>

            <div class="stat-card">
                <div class="stat-number">{{ stats.publishedArticles }}</div>
                <div class="stat-label">Published</div>
            </div>

            <div class="stat-card">
                <div class="stat-number">{{ stats.draftArticles }}</div>
                <div class="stat-label">Drafts</div>
            </div>

            <div class="stat-card">
                <div class="stat-number">{{ stats.totalTags }}</div>
                <div class="stat-label">Tags</div>
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
                />
            </div>

            <div class="filter-controls">
                <select
                    v-model="statusFilter"
                    class="filter-select"
                    @change="fetchArticles"
                >
                    <option value="">All Status</option>
                    <option value="published">Published</option>
                    <option value="draft">Drafts</option>
                </select>

                <select
                    v-model="sortBy"
                    class="filter-select"
                    @change="fetchArticles"
                >
                    <option value="date_updated">Recently Updated</option>
                    <option value="date_added">Recently Created</option>
                    <option value="published_at">Recently Published</option>
                    <option value="title">Title A-Z</option>
                </select>

                <button
                    @click="$router.push('/admin/media')"
                    class="media-library-button"
                >
                    Media Library
                </button>

                <button
                    @click="showCreateArticle = true"
                    class="create-article-button"
                >
                    New Article
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
            <div class="error-icon">⚠️</div>
            <h3>Failed to load articles</h3>
            <p>{{ error }}</p>
            <button @click="fetchArticles" class="retry-button">
                Try Again
            </button>
        </div>

        <!-- Articles Table -->
        <div v-else class="articles-section">
            <div class="section-header">
                <h2>Articles ({{ pagination.total_count }})</h2>
            </div>

            <!-- Empty State -->
            <div v-if="articles.length === 0" class="empty-container">
                <div class="empty-icon">📝</div>
                <h3>No articles found</h3>
                <p v-if="searchQuery">
                    No articles match your search "{{ searchQuery }}".
                </p>
                <p v-else-if="statusFilter">
                    No {{ statusFilter }} articles found.
                </p>
                <p v-else>Get started by creating your first article!</p>
                <button @click="showCreateArticle = true" class="create-button">
                    Create Article
                </button>
            </div>

            <!-- Articles List -->
            <div v-else class="articles-table">
                <div class="table-header">
                    <div class="col-title">Title</div>
                    <div class="col-status">Status</div>
                    <div class="col-updated">Updated</div>
                    <div class="col-actions">Actions</div>
                </div>

                <div
                    v-for="article in articles"
                    :key="article.id"
                    class="table-row"
                >
                    <div class="col-title">
                        <div class="article-info">
                            <h4 class="article-title">{{ article.title }}</h4>
                            <p class="article-excerpt" v-if="article.excerpt">
                                {{ article.excerpt }}
                            </p>
                            <div class="article-meta">
                                <span class="slug">/{{ article.slug }}</span>
                                <div
                                    class="tags"
                                    v-if="
                                        article.tags && article.tags.length > 0
                                    "
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
                        <div class="publish-date" v-if="article.published_at">
                            {{ formatDate(article.published_at) }}
                        </div>
                    </div>

                    <div class="col-updated">
                        {{ formatDate(article.date_updated) }}
                    </div>

                    <div class="col-actions">
                        <div class="action-buttons">
                            <button
                                @click="editArticle(article)"
                                class="action-button edit-button"
                                title="Edit Article"
                                aria-label="Edit Article"
                            >
                                Edit
                            </button>

                            <button
                                @click="viewArticle(article)"
                                class="action-button view-button"
                                title="View Article"
                                aria-label="View Article"
                            >
                                View
                            </button>

                            <button
                                @click="togglePublish(article)"
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
                            >
                                {{
                                    article.is_published
                                        ? "Unpublish"
                                        : "Publish"
                                }}
                            </button>

                            <button
                                @click="confirmDelete(article)"
                                class="action-button delete-button"
                                title="Delete Article"
                                aria-label="Delete Article"
                            >
                                Delete
                            </button>
                        </div>
                    </div>
                </div>
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
            <div class="modal-content" @click.stop>
                <h3>Delete Article</h3>
                <p>
                    Are you sure you want to delete "<strong>{{
                        deleteConfirmation.title
                    }}</strong
                    >"? This action cannot be undone.
                </p>
                <div class="modal-actions">
                    <button @click="cancelDelete" class="cancel-button">
                        Cancel
                    </button>
                    <button @click="deleteArticle" class="delete-button">
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
            published:
                statusFilter.value === "published"
                    ? 1
                    : statusFilter.value === "draft"
                      ? 0
                      : undefined,
        };

        // Remove undefined values
        Object.keys(params).forEach(
            (key) => params[key] === undefined && delete params[key],
        );

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
        console.error("Error fetching articles:", err);
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
    } catch (err) {
        console.error("Error fetching stats:", err);
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
    } catch (err) {
        console.error("Error toggling publish status:", err);
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
    } catch (err) {
        console.error("Error deleting article:", err);
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
}

/* Header */
.dashboard-header {
    background: linear-gradient(
        135deg,
        var(--primary-color) 0%,
        var(--primary-color-dark) 100%
    );
    color: white;
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    margin-bottom: var(--spacing-xl);
    box-shadow: var(--shadow-md);
}

.header-content {
    text-align: center;
    color: var(--text-primary);
}

.dashboard-header h1 {
    font-size: 2.5rem;
    margin: 0 0 var(--spacing-xs) 0;
    font-weight: 700;
}

.welcome-message {
    margin: 0;
    opacity: 0.9;
    font-size: 1.125rem;
}

/* Stats Grid */
.stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: var(--spacing-lg);
    margin-bottom: var(--spacing-xl);
}

.stat-card {
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-lg);
    text-align: center;
    box-shadow: var(--shadow-sm);
    transition: transform var(--transition-fast);
}

.stat-card:hover {
    transform: translateY(-2px);
    box-shadow: var(--shadow-md);
}

.stat-number {
    font-size: 2.5rem;
    font-weight: 700;
    color: var(--primary-color);
    margin-bottom: var(--spacing-xs);
}

.stat-label {
    color: var(--text-secondary);
    font-weight: 500;
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

/* Filters */
.filters-section {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: var(--spacing-xl);
    gap: var(--spacing-lg);
    flex-wrap: wrap;
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
    background-color: var(--bg-color);
    color: var(--text-primary);
}

.search-input:focus {
    outline: none;
    border-color: var(--primary-color);
    box-shadow: 0 0 0 3px var(--primary-color-light);
}

.filter-controls {
    display: flex;
    gap: var(--spacing-md);
}

.filter-select {
    padding: var(--spacing-sm) var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    background-color: var(--bg-color);
    color: var(--text-primary);
    font-size: 0.875rem;
}

.media-library-button,
.create-article-button {
    padding: var(--spacing-sm) var(--spacing-lg);
    border: none;
    border-radius: var(--radius-md);
    color: white;
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
    transition: all var(--transition-fast);
    white-space: nowrap;
    box-shadow: var(--shadow-sm);
}

.media-library-button {
    background-color: var(--text-secondary);
}

.media-library-button:hover {
    background-color: var(--text-primary);
    transform: translateY(-2px);
    box-shadow: var(--shadow-md);
}

.create-article-button {
    background-color: var(--primary-color);
}

.create-article-button:hover {
    background-color: var(--primary-dark);
    transform: translateY(-2px);
    box-shadow: var(--shadow-md);
}

.media-library-button:active,
.create-article-button:active {
    transform: translateY(0);
}

/* Loading and Error States */
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
    0% {
        transform: rotate(0deg);
    }
    100% {
        transform: rotate(360deg);
    }
}

.empty-icon,
.error-icon {
    font-size: 3rem;
    margin-bottom: var(--spacing-md);
}

.retry-button {
    background-color: var(--primary-color);
    color: white;
    border: none;
    padding: var(--spacing-sm) var(--spacing-lg);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 500;
    margin-top: var(--spacing-md);
}

/* Articles Table */
.articles-section {
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    overflow: hidden;
    box-shadow: var(--shadow-sm);
}

.section-header {
    padding: var(--spacing-lg);
    border-bottom: 1px solid var(--border-color);
    background-color: var(--light-bg);
}

.section-header h2 {
    margin: 0;
    color: var(--text-primary);
    font-weight: 600;
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
    background-color: var(--light-bg);
    border-bottom: 1px solid var(--border-color);
    font-weight: 600;
    color: var(--text-secondary);
    font-size: 0.875rem;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.table-row {
    display: grid;
    grid-template-columns: 1fr 120px 120px 120px;
    gap: var(--spacing-md);
    padding: var(--spacing-lg);
    border-bottom: 1px solid var(--border-color);
    transition: background-color var(--transition-fast);
}

.table-row:hover {
    background-color: var(--light-bg);
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
    font-family: monospace;
    background-color: var(--light-bg);
    padding: 2px 4px;
    border-radius: 2px;
    align-self: flex-start;
}

.tags {
    display: flex;
    flex-wrap: wrap;
    gap: var(--spacing-xs);
}

.tag {
    background-color: var(--primary-color-light);
    color: var(--primary-color);
    padding: 2px 6px;
    border-radius: var(--radius-sm);
    font-size: 0.7rem;
    font-weight: 500;
}

.status-badge {
    display: inline-block;
    padding: var(--spacing-xs) var(--spacing-sm);
    border-radius: var(--radius-full);
    font-size: 0.75rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.status-badge.published {
    background-color: var(--success-bg);
    color: var(--success-text);
}

.status-badge.draft {
    background-color: var(--warning-bg);
    color: var(--warning-text);
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
    border: none;
    border-radius: var(--radius-sm);
    cursor: pointer;
    font-size: 0.75rem;
    font-weight: 600;
    transition: all var(--transition-fast);
    display: flex;
    align-items: center;
    justify-content: center;
    white-space: nowrap;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.edit-button {
    background-color: var(--primary-color-light);
    color: var(--primary-color);
}

.edit-button:hover {
    background-color: var(--primary-color);
    color: white;
}

.view-button {
    background-color: var(--light-bg);
    color: var(--text-secondary);
}

.view-button:hover {
    background-color: var(--text-secondary);
    color: white;
}

.publish-button {
    background-color: var(--success-bg);
    color: var(--success-text);
}

.publish-button:hover {
    background-color: var(--success-text);
    color: white;
}

.delete-button {
    background-color: var(--error-bg);
    color: var(--error-text);
}

.delete-button:hover {
    background-color: var(--error-text);
    color: white;
}

/* Pagination */
.pagination {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: var(--spacing-lg);
    padding: var(--spacing-lg);
    border-top: 1px solid var(--border-color);
    background-color: var(--light-bg);
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

/* Modal */
.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.modal-content {
    background-color: var(--card-bg);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    max-width: 400px;
    width: 90%;
    box-shadow: var(--shadow-lg);
}

.modal-content h3 {
    margin-top: 0;
    color: var(--text-primary);
}

.modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: var(--spacing-md);
    margin-top: var(--spacing-lg);
}

.cancel-button,
.delete-button {
    padding: var(--spacing-sm) var(--spacing-lg);
    border: none;
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 500;
}

.cancel-button {
    background-color: var(--light-bg);
    color: var(--text-primary);
}

.delete-button {
    background-color: var(--error-text);
    color: white;
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
