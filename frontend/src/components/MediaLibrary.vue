<template>
  <div class="media-library">
    <!-- Header with Search and Filters -->
    <div class="library-header">
      <div class="search-bar">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Search by filename, alt text, or caption..."
          class="search-input"
          @input="debouncedSearch"
        />
      </div>

      <div class="filter-controls">
        <select v-model="selectedMimeType" class="filter-select" @change="fetchMedia">
          <option value="">All Types</option>
          <option value="image/jpeg">JPEG</option>
          <option value="image/png">PNG</option>
          <option value="image/gif">GIF</option>
          <option value="image/webp">WebP</option>
          <option value="image/svg+xml">SVG</option>
        </select>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="loading-container">
      <div class="loading-spinner"></div>
      <p>Loading media...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="error-container">
      <p>{{ error }}</p>
      <button @click="fetchMedia" class="retry-button">Try Again</button>
    </div>

    <!-- Empty State -->
    <div v-else-if="mediaItems.length === 0" class="empty-container">
      <p v-if="searchQuery || selectedMimeType">
        No media found matching your filters.
      </p>
      <p v-else>
        No media uploaded yet. Upload your first image to get started!
      </p>
    </div>

    <!-- Media Grid -->
    <div v-else class="media-grid">
      <div
        v-for="media in mediaItems"
        :key="media.id"
        class="media-item"
        :class="{ 'selected': isSelected(media.id) }"
        @click="handleMediaClick(media)"
      >
        <div class="media-thumbnail">
          <img
            :src="media.url"
            :alt="media.alt_text || media.original_filename"
            loading="lazy"
          />
          <div v-if="isSelected(media.id)" class="selected-indicator">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
              <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
          </div>
        </div>

        <div class="media-info">
          <p class="media-filename" :title="media.original_filename">
            {{ media.original_filename }}
          </p>
          <div class="media-meta">
            <span class="media-size">{{ formatFileSize(media.file_size) }}</span>
            <span v-if="media.width && media.height" class="media-dimensions">
              {{ media.width }} × {{ media.height }}
            </span>
          </div>
          <p v-if="media.alt_text" class="media-alt" :title="media.alt_text">
            {{ media.alt_text }}
          </p>
        </div>

        <div class="media-actions" @click.stop>
          <button
            type="button"
            class="action-button edit-button"
            @click="editMedia(media)"
            title="Edit metadata"
          >
            Edit
          </button>
          <button
            type="button"
            class="action-button delete-button"
            @click="deleteMedia(media)"
            title="Delete media"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="pagination.total_pages > 1" class="pagination">
      <button
        class="pagination-button"
        :disabled="!pagination.has_prev"
        @click="changePage(pagination.current_page - 1)"
      >
        Previous
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
        Next
      </button>
    </div>

    <!-- Edit Modal -->
    <div v-if="editingMedia" class="modal-overlay" @click="closeEditModal">
      <div class="modal-content" @click.stop>
        <h3>Edit Media Metadata</h3>

        <div class="form-group">
          <label>Alt Text</label>
          <input
            v-model="editForm.alt_text"
            type="text"
            class="form-input"
            placeholder="Describe the image for accessibility"
          />
        </div>

        <div class="form-group">
          <label>Caption</label>
          <input
            v-model="editForm.caption"
            type="text"
            class="form-input"
            placeholder="Optional caption"
          />
        </div>

        <div class="modal-actions">
          <button type="button" class="button-secondary" @click="closeEditModal">
            Cancel
          </button>
          <button type="button" class="button-primary" @click="saveMediaEdit">
            Save Changes
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import axios from 'axios'

const props = defineProps({
  selectionMode: {
    type: String,
    default: 'single', // 'single', 'multiple', or 'none'
    validator: (value) => ['single', 'multiple', 'none'].includes(value)
  }
})

const emit = defineEmits(['media-selected', 'media-deselected', 'media-updated', 'media-deleted'])

// State
const mediaItems = ref([])
const isLoading = ref(false)
const error = ref(null)
const searchQuery = ref('')
const selectedMimeType = ref('')
const currentPage = ref(1)
const pagination = ref({
  current_page: 1,
  total_pages: 1,
  total_count: 0,
  per_page: 20,
  has_next: false,
  has_prev: false
})
const selectedMediaIds = ref(new Set())
const editingMedia = ref(null)
const editForm = ref({
  alt_text: '',
  caption: ''
})

let searchDebounceTimer = null

// Methods
async function fetchMedia() {
  isLoading.value = true
  error.value = null

  try {
    const params = {
      page: currentPage.value,
      limit: 20
    }

    if (selectedMimeType.value) {
      params.mime_type = selectedMimeType.value
    }

    if (searchQuery.value) {
      params.search = searchQuery.value
    }

    const response = await axios.get('/api/admin/media', { params })

    if (response.data.success) {
      mediaItems.value = response.data.media
      pagination.value = response.data.pagination
    } else {
      throw new Error(response.data.error || 'Failed to fetch media')
    }
  } catch (err) {
    console.error('Error fetching media:', err)
    error.value = err.response?.data?.error || err.message || 'Failed to load media'
  } finally {
    isLoading.value = false
  }
}

function debouncedSearch() {
  clearTimeout(searchDebounceTimer)
  searchDebounceTimer = setTimeout(() => {
    currentPage.value = 1
    fetchMedia()
  }, 500)
}

function changePage(page) {
  currentPage.value = page
  fetchMedia()
}

function handleMediaClick(media) {
  if (props.selectionMode === 'none') return

  if (props.selectionMode === 'single') {
    if (selectedMediaIds.value.has(media.id)) {
      selectedMediaIds.value.clear()
      emit('media-deselected', media)
    } else {
      selectedMediaIds.value.clear()
      selectedMediaIds.value.add(media.id)
      emit('media-selected', media)
    }
  } else if (props.selectionMode === 'multiple') {
    if (selectedMediaIds.value.has(media.id)) {
      selectedMediaIds.value.delete(media.id)
      emit('media-deselected', media)
    } else {
      selectedMediaIds.value.add(media.id)
      emit('media-selected', media)
    }
  }
}

function isSelected(mediaId) {
  return selectedMediaIds.value.has(mediaId)
}

function editMedia(media) {
  editingMedia.value = media
  editForm.value = {
    alt_text: media.alt_text || '',
    caption: media.caption || ''
  }
}

function closeEditModal() {
  editingMedia.value = null
  editForm.value = { alt_text: '', caption: '' }
}

async function saveMediaEdit() {
  if (!editingMedia.value) return

  try {
    const response = await axios.put(`/api/admin/media/${editingMedia.value.id}`, editForm.value)

    if (response.data.success) {
      // Update the media item in the list
      const index = mediaItems.value.findIndex(m => m.id === editingMedia.value.id)
      if (index !== -1) {
        mediaItems.value[index] = response.data.media
      }

      emit('media-updated', response.data.media)
      closeEditModal()
    } else {
      throw new Error(response.data.error || 'Failed to update media')
    }
  } catch (err) {
    console.error('Error updating media:', err)
    alert(err.response?.data?.error || err.message || 'Failed to update media')
  }
}

async function deleteMedia(media) {
  if (!confirm(`Are you sure you want to delete "${media.original_filename}"? This action cannot be undone.`)) {
    return
  }

  try {
    const response = await axios.delete(`/api/admin/media/${media.id}`)

    if (response.data.success) {
      // Remove from the list
      mediaItems.value = mediaItems.value.filter(m => m.id !== media.id)
      selectedMediaIds.value.delete(media.id)

      emit('media-deleted', media)

      // Refresh if the current page is now empty
      if (mediaItems.value.length === 0 && currentPage.value > 1) {
        currentPage.value--
        fetchMedia()
      }
    } else {
      throw new Error(response.data.error || 'Failed to delete media')
    }
  } catch (err) {
    console.error('Error deleting media:', err)
    alert(err.response?.data?.error || err.message || 'Failed to delete media')
  }
}

function formatFileSize(bytes) {
  if (bytes === 0) return '0 Bytes'

  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))

  return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
}

function clearSelection() {
  selectedMediaIds.value.clear()
}

function getSelectedMedia() {
  return mediaItems.value.filter(m => selectedMediaIds.value.has(m.id))
}

// Lifecycle
onMounted(() => {
  fetchMedia()
})

// Watch for prop changes
watch(() => props.selectionMode, () => {
  clearSelection()
})

// Expose methods
defineExpose({
  fetchMedia,
  clearSelection,
  getSelectedMedia
})
</script>

<style scoped>
.media-library {
  width: 100%;
}

.library-header {
  display: flex;
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-lg);
  flex-wrap: wrap;
}

.search-bar {
  flex: 1;
  min-width: 250px;
}

.search-input {
  width: 100%;
  padding: var(--spacing-sm) var(--spacing-md);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  font-size: 1rem;
}

.search-input:focus {
  outline: none;
  border-color: var(--primary-color);
}

.filter-controls {
  display: flex;
  gap: var(--spacing-sm);
}

.filter-select {
  padding: var(--spacing-sm) var(--spacing-md);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  font-size: 1rem;
  background-color: var(--bg-color);
  cursor: pointer;
}

.loading-container,
.error-container,
.empty-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-xxl);
  text-align: center;
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
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.retry-button {
  margin-top: var(--spacing-md);
  padding: var(--spacing-sm) var(--spacing-lg);
  background-color: var(--primary-color);
  color: white;
  border: none;
  border-radius: var(--radius-md);
  cursor: pointer;
  font-weight: 500;
}

.media-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: var(--spacing-lg);
  margin-bottom: var(--spacing-xl);
}

.media-item {
  border: 2px solid var(--border-color);
  border-radius: var(--radius-lg);
  overflow: hidden;
  cursor: pointer;
  transition: all var(--transition-fast);
  background-color: var(--bg-color);
}

.media-item:hover {
  border-color: var(--primary-color);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.media-item.selected {
  border-color: var(--primary-color);
  box-shadow: 0 0 0 3px var(--primary-color-light);
}

.media-thumbnail {
  position: relative;
  width: 100%;
  height: 200px;
  background-color: var(--light-bg);
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.media-thumbnail img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.selected-indicator {
  position: absolute;
  top: var(--spacing-sm);
  right: var(--spacing-sm);
  width: 32px;
  height: 32px;
  background-color: var(--primary-color);
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.media-info {
  padding: var(--spacing-md);
}

.media-filename {
  font-weight: 600;
  font-size: 0.875rem;
  margin: 0 0 var(--spacing-xs) 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.media-meta {
  display: flex;
  gap: var(--spacing-sm);
  font-size: 0.75rem;
  color: var(--text-secondary);
  margin-bottom: var(--spacing-xs);
}

.media-alt {
  font-size: 0.75rem;
  color: var(--text-secondary);
  margin: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.media-actions {
  display: flex;
  gap: var(--spacing-xs);
  padding: var(--spacing-sm) var(--spacing-md);
  border-top: 1px solid var(--border-color);
}

.action-button {
  flex: 1;
  padding: var(--spacing-xs) var(--spacing-sm);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  font-size: 0.75rem;
  font-weight: 600;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.edit-button {
  background-color: var(--bg-color);
  color: var(--text-primary);
}

.edit-button:hover {
  background-color: var(--primary-color);
  color: white;
  border-color: var(--primary-color);
}

.delete-button {
  background-color: var(--bg-color);
  color: var(--error-color);
  border-color: var(--error-color);
}

.delete-button:hover {
  background-color: var(--error-color);
  color: white;
}

.pagination {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: var(--spacing-lg);
  margin-top: var(--spacing-xl);
}

.pagination-button {
  padding: var(--spacing-sm) var(--spacing-lg);
  border: 1px solid var(--border-color);
  background-color: var(--bg-color);
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

/* Modal Styles */
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
  background-color: var(--bg-color);
  border-radius: var(--radius-lg);
  padding: var(--spacing-xl);
  max-width: 500px;
  width: 90%;
  max-height: 90vh;
  overflow-y: auto;
}

.modal-content h3 {
  margin-top: 0;
  margin-bottom: var(--spacing-lg);
  color: var(--text-primary);
}

.form-group {
  margin-bottom: var(--spacing-md);
}

.form-group label {
  display: block;
  font-size: 0.875rem;
  font-weight: 600;
  margin-bottom: var(--spacing-xs);
  color: var(--text-primary);
}

.form-input {
  width: 100%;
  padding: var(--spacing-sm) var(--spacing-md);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md);
  font-size: 1rem;
}

.form-input:focus {
  outline: none;
  border-color: var(--primary-color);
}

.modal-actions {
  display: flex;
  gap: var(--spacing-md);
  justify-content: flex-end;
  margin-top: var(--spacing-lg);
}

.button-secondary,
.button-primary {
  padding: var(--spacing-sm) var(--spacing-lg);
  border: none;
  border-radius: var(--radius-md);
  font-weight: 600;
  cursor: pointer;
  transition: opacity var(--transition-fast);
}

.button-secondary {
  background-color: var(--light-bg);
  color: var(--text-primary);
}

.button-primary {
  background-color: var(--primary-color);
  color: white;
}

.button-secondary:hover,
.button-primary:hover {
  opacity: 0.9;
}

@media (max-width: 768px) {
  .media-grid {
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: var(--spacing-md);
  }

  .library-header {
    flex-direction: column;
  }

  .search-bar {
    width: 100%;
  }
}
</style>
