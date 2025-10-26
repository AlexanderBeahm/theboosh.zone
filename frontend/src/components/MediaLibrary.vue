<template>
  <div
    class="media-library"
    tabindex="0"
    @paste="handlePaste"
    @keydown.ctrl.v="handleKeyboardPaste"
    @keydown.meta.v="handleKeyboardPaste"
  >
    <!-- Header with Search and Filters -->
    <div class="library-header">
      <div class="search-bar">
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Search by filename, alt text, or caption..."
          class="search-input"
          @input="debouncedSearch"
        >
      </div>

      <div class="filter-controls">
        <select
          v-model="selectedMimeType"
          class="filter-select"
          @change="fetchMedia"
        >
          <option value="">
            All Types
          </option>
          <option value="image/jpeg">
            JPEG
          </option>
          <option value="image/png">
            PNG
          </option>
          <option value="image/gif">
            GIF
          </option>
          <option value="image/webp">
            WebP
          </option>
          <option value="image/svg+xml">
            SVG
          </option>
        </select>
      </div>
    </div>

    <!-- Upload Zone -->
    <div
      class="upload-zone"
      :class="{
        'drag-over': isDragOver,
        'uploading': isUploading
      }"
      @drop="handleDrop"
      @dragover="handleDragOver"
      @dragenter="handleDragEnter"
      @dragleave="handleDragLeave"
      @click="triggerFileInput"
    >
      <input
        ref="fileInput"
        type="file"
        multiple
        accept="image/*"
        class="hidden-file-input"
        @change="handleFileSelect"
      >

      <div
        v-if="!isUploading"
        class="upload-zone-content"
      >
        <div class="upload-icon">
          📁
        </div>
        <p class="upload-text">
          <strong>Drop images here to upload</strong>
        </p>
        <p class="upload-subtext">
          or click to browse files, or paste images with <kbd>Ctrl+V</kbd>
        </p>
        <div class="upload-formats">
          Supports: JPEG, PNG, GIF, WebP, SVG
        </div>
      </div>

      <div
        v-if="isUploading"
        class="uploading-content"
      >
        <div class="upload-progress">
          <div class="loading-spinner" />
          <p>Uploading {{ uploadQueue.length }} file(s)...</p>
          <div class="progress-bar">
            <div
              class="progress-fill"
              :style="{ width: uploadProgress + '%' }"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Loading State -->
    <div
      v-if="isLoading"
      class="loading-container"
    >
      <div class="loading-spinner" />
      <p>Loading media...</p>
    </div>

    <!-- Error State -->
    <div
      v-else-if="error"
      class="error-container"
    >
      <p>{{ error }}</p>
      <button
        class="retry-button"
        @click="fetchMedia"
      >
        Try Again
      </button>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="mediaItems.length === 0"
      class="empty-container"
    >
      <p v-if="searchQuery || selectedMimeType">
        No media found matching your filters.
      </p>
      <p v-else>
        No media uploaded yet. Upload your first image to get started!
      </p>
    </div>

    <!-- Media Grid -->
    <div
      v-else
      class="media-grid"
    >
      <div
        v-for="media in mediaItems"
        :key="media.id"
        class="media-item"
        :class="{ selected: isSelected(media.id) }"
        @click="handleMediaClick(media)"
      >
        <div class="media-thumbnail">
          <img
            :src="media.url"
            :alt="media.alt_text || media.original_filename"
            loading="lazy"
          >
          <div
            v-if="isSelected(media.id)"
            class="selected-indicator"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="3"
            >
              <polyline points="20 6 9 17 4 12" />
            </svg>
          </div>
        </div>

        <div class="media-info">
          <p
            class="media-filename"
            :title="media.original_filename"
          >
            {{ media.original_filename }}
          </p>
          <div class="media-meta">
            <span class="media-size">{{
              formatFileSize(media.file_size)
            }}</span>
            <span
              v-if="media.width && media.height"
              class="media-dimensions"
            >
              {{ media.width }} × {{ media.height }}
            </span>
          </div>
          <p
            v-if="media.alt_text"
            class="media-alt"
            :title="media.alt_text"
          >
            {{ media.alt_text }}
          </p>
        </div>

        <div
          class="media-actions"
          @click.stop
        >
          <button
            type="button"
            class="action-button edit-button"
            title="Edit metadata"
            @click="editMedia(media)"
          >
            Edit
          </button>
          <button
            type="button"
            class="action-button delete-button"
            title="Delete media"
            @click="deleteMedia(media)"
          >
            Delete
          </button>
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
        Previous
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
        Next
      </button>
    </div>

    <!-- Edit Modal -->
    <div
      v-if="editingMedia"
      class="modal-overlay"
      @click="closeEditModal"
    >
      <div
        class="modal-content"
        @click.stop
      >
        <h3>Edit Media Metadata</h3>

        <div class="form-group">
          <label>Alt Text</label>
          <input
            v-model="editForm.alt_text"
            type="text"
            class="form-input"
            placeholder="Describe the image for accessibility"
          >
        </div>

        <div class="form-group">
          <label>Caption</label>
          <input
            v-model="editForm.caption"
            type="text"
            class="form-input"
            placeholder="Optional caption"
          >
        </div>

        <div class="modal-actions">
          <button
            type="button"
            class="button-secondary"
            @click="closeEditModal"
          >
            Cancel
          </button>
          <button
            type="button"
            class="button-primary"
            @click="saveMediaEdit"
          >
            Save Changes
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from "vue";
import axios from "axios";

const props = defineProps({
    selectionMode: {
        type: String,
        default: "single", // 'single', 'multiple', or 'none'
        validator: (value) => ["single", "multiple", "none"].includes(value),
    },
});

const emit = defineEmits([
    "media-selected",
    "media-deselected",
    "media-updated",
    "media-deleted",
]);

// State
const mediaItems = ref([]);
const isLoading = ref(false);
const error = ref(null);
const searchQuery = ref("");
const selectedMimeType = ref("");
const currentPage = ref(1);
const pagination = ref({
    current_page: 1,
    total_pages: 1,
    total_count: 0,
    per_page: 20,
    has_next: false,
    has_prev: false,
});
const selectedMediaIds = ref(new Set());
const editingMedia = ref(null);
const editForm = ref({
    alt_text: "",
    caption: "",
});
const isDragOver = ref(false);
const isUploading = ref(false);
const uploadQueue = ref([]);
const uploadProgress = ref(0);
const fileInput = ref(null);

let searchDebounceTimer = null;

// Methods
async function fetchMedia() {
    isLoading.value = true;
    error.value = null;

    try {
        const params = {
            page: currentPage.value,
            limit: 20,
        };

        if (selectedMimeType.value) {
            params.mime_type = selectedMimeType.value;
        }

        if (searchQuery.value) {
            params.search = searchQuery.value;
        }

        const response = await axios.get("/api/admin/media", { params });

        if (response.data.success) {
            mediaItems.value = response.data.media;
            pagination.value = response.data.pagination;
        } else {
            throw new Error(response.data.error || "Failed to fetch media");
        }
    } catch (err) {
        error.value =
            err.response?.data?.error || err.message || "Failed to load media";
    } finally {
        isLoading.value = false;
    }
}

function debouncedSearch() {
    clearTimeout(searchDebounceTimer);
    searchDebounceTimer = setTimeout(() => {
        currentPage.value = 1;
        fetchMedia();
    }, 500);
}

function changePage(page) {
    currentPage.value = page;
    fetchMedia();
}

function handleMediaClick(media) {
    if (props.selectionMode === "none") return;

    if (props.selectionMode === "single") {
        if (selectedMediaIds.value.has(media.id)) {
            selectedMediaIds.value.clear();
            emit("media-deselected", media);
        } else {
            selectedMediaIds.value.clear();
            selectedMediaIds.value.add(media.id);
            emit("media-selected", media);
        }
    } else if (props.selectionMode === "multiple") {
        if (selectedMediaIds.value.has(media.id)) {
            selectedMediaIds.value.delete(media.id);
            emit("media-deselected", media);
        } else {
            selectedMediaIds.value.add(media.id);
            emit("media-selected", media);
        }
    }
}

function isSelected(mediaId) {
    return selectedMediaIds.value.has(mediaId);
}

function editMedia(media) {
    editingMedia.value = media;
    editForm.value = {
        alt_text: media.alt_text || "",
        caption: media.caption || "",
    };
}

function closeEditModal() {
    editingMedia.value = null;
    editForm.value = { alt_text: "", caption: "" };
}

async function saveMediaEdit() {
    if (!editingMedia.value) return;

    try {
        const response = await axios.put(
            `/api/admin/media/${editingMedia.value.id}`,
            editForm.value,
        );

        if (response.data.success) {
            // Update the media item in the list
            const index = mediaItems.value.findIndex(
                (m) => m.id === editingMedia.value.id,
            );
            if (index !== -1) {
                mediaItems.value[index] = response.data.media;
            }

            emit("media-updated", response.data.media);
            closeEditModal();
        } else {
            throw new Error(response.data.error || "Failed to update media");
        }
    } catch (err) {
        alert(
            err.response?.data?.error ||
                err.message ||
                "Failed to update media",
        );
    }
}

async function deleteMedia(media) {
    if (
        !confirm(
            `Are you sure you want to delete "${media.original_filename}"? This action cannot be undone.`,
        )
    ) {
        return;
    }

    try {
        const response = await axios.delete(`/api/admin/media/${media.id}`);

        if (response.data.success) {
            // Remove from the list
            mediaItems.value = mediaItems.value.filter(
                (m) => m.id !== media.id,
            );
            selectedMediaIds.value.delete(media.id);

            emit("media-deleted", media);

            // Refresh if the current page is now empty
            if (mediaItems.value.length === 0 && currentPage.value > 1) {
                currentPage.value--;
                fetchMedia();
            }
        } else {
            throw new Error(response.data.error || "Failed to delete media");
        }
    } catch (err) {
        alert(
            err.response?.data?.error ||
                err.message ||
                "Failed to delete media",
        );
    }
}

function formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes";

    const k = 1024;
    const sizes = ["Bytes", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + " " + sizes[i];
}

function clearSelection() {
    selectedMediaIds.value.clear();
}

function getSelectedMedia() {
    return mediaItems.value.filter((m) => selectedMediaIds.value.has(m.id));
}

// Drag and drop methods
function handleDragEnter(event) {
    event.preventDefault();
    isDragOver.value = true;
}

function handleDragOver(event) {
    event.preventDefault();
    isDragOver.value = true;
}

function handleDragLeave(event) {
    event.preventDefault();
    // Only set to false if leaving the upload zone completely
    if (!event.currentTarget.contains(event.relatedTarget)) {
        isDragOver.value = false;
    }
}

function handleDrop(event) {
    event.preventDefault();
    isDragOver.value = false;

    const files = Array.from(event.dataTransfer.files);
    const imageFiles = files.filter(file => file.type.startsWith('image/'));

    if (imageFiles.length > 0) {
        uploadFiles(imageFiles);
    }
}

function triggerFileInput() {
    if (!isUploading.value && fileInput.value) {
        fileInput.value.click();
    }
}

function handleFileSelect(event) {
    const files = Array.from(event.target.files);
    if (files.length > 0) {
        uploadFiles(files);
    }
    // Reset the input value to allow selecting the same file again
    event.target.value = '';
}

async function uploadFiles(files) {
    if (isUploading.value) return;

    isUploading.value = true;
    uploadQueue.value = [...files];
    uploadProgress.value = 0;

    try {
        const uploadPromises = files.map((file, index) =>
            uploadSingleFile(file, index, files.length)
        );

        await Promise.all(uploadPromises);

        // Refresh the media list after uploads
        await fetchMedia();

        // Reset upload state
        uploadQueue.value = [];
        uploadProgress.value = 0;
    } catch {
        alert('Some uploads failed. Please try again.');
    } finally {
        isUploading.value = false;
    }
}

async function uploadSingleFile(file, index, total) {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('alt_text', file.name);
    formData.append('caption', '');

    const response = await axios.post('/api/admin/media/upload', formData, {
        headers: {
            'Content-Type': 'multipart/form-data'
        }
    });

    if (response.data.success) {
        // Update progress
        uploadProgress.value = Math.round(((index + 1) / total) * 100);
        return response.data.media;
    } else {
        throw new Error(response.data.error || 'Upload failed');
    }
}

// Paste functionality
function handleKeyboardPaste(event) {
    // For keyboard shortcuts, we need to manually trigger paste event
    // This is mainly for accessibility
    event.preventDefault();
    document.execCommand('paste');
}

async function handlePaste(event) {
    const clipboardData = event.clipboardData || event.originalEvent?.clipboardData;
    if (!clipboardData) return;

    // Check if clipboard contains image files
    const items = Array.from(clipboardData.items);
    const imageItems = items.filter(item => item.type.startsWith('image/'));

    if (imageItems.length === 0) {
        // No images in clipboard, ignore
        return;
    }

    // Prevent default paste behavior when images are detected
    event.preventDefault();

    // Process all pasted images
    const imageFiles = imageItems.map(item => item.getAsFile()).filter(file => file);

    if (imageFiles.length > 0) {
        // Upload the pasted images
        await uploadFiles(imageFiles);
    }
}

// Lifecycle
onMounted(() => {
    fetchMedia();
});

// Watch for prop changes
watch(
    () => props.selectionMode,
    () => {
        clearSelection();
    },
);

// Expose methods
defineExpose({
    fetchMedia,
    clearSelection,
    getSelectedMedia,
});
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
    background: var(--bg-color);
    color: var(--text-primary);
    transition: all var(--transition-fast);
}

.search-input:focus {
    outline: none;
    border-color: var(--accent-cyan);
    box-shadow:
        0 0 0 2px rgba(0, 206, 209, 0.2),
        0 0 20px rgba(0, 206, 209, 0.3);
    background: var(--card-bg);
}

.search-input::placeholder {
    color: var(--text-secondary);
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
    background: var(--bg-color);
    color: var(--text-primary);
    cursor: pointer;
    transition: all var(--transition-fast);
}

.filter-select:focus {
    outline: none;
    border-color: var(--accent-cyan);
    box-shadow: 0 0 0 2px rgba(0, 206, 209, 0.2);
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
    border-top: 3px solid var(--accent-cyan);
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin-bottom: var(--spacing-md);
    box-shadow: 0 0 20px rgba(0, 206, 209, 0.3);
}

@keyframes spin {
    0% {
        transform: rotate(0deg);
        box-shadow: 0 0 20px rgba(0, 206, 209, 0.3);
    }
    50% {
        box-shadow: 0 0 30px rgba(0, 206, 209, 0.5);
    }
    100% {
        transform: rotate(360deg);
        box-shadow: 0 0 20px rgba(0, 206, 209, 0.3);
    }
}

.retry-button {
    margin-top: var(--spacing-md);
    padding: var(--spacing-sm) var(--spacing-lg);
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border: 1px solid var(--primary-color);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.retry-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.6s;
}

.retry-button:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.4);
}

.retry-button:hover::before {
    left: 100%;
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
    background: var(--card-bg);
    position: relative;
}

.media-item::before {
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

.media-item:hover {
    border-color: var(--accent-cyan);
    transform: translateY(-4px);
    box-shadow:
        var(--shadow-lg),
        0 0 25px rgba(0, 206, 209, 0.2);
}

.media-item:hover::before {
    opacity: 0.1;
}

.media-item.selected {
    border-color: var(--primary-color);
    box-shadow:
        var(--shadow-lg),
        0 0 20px rgba(255, 105, 180, 0.4);
}

.media-item.selected::before {
    opacity: 0.2;
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
    color: var(--light-text);
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
    border: 1px solid;
    border-radius: var(--radius-md);
    font-size: 0.75rem;
    font-weight: 700;
    cursor: pointer;
    transition: all var(--transition-fast);
    text-transform: uppercase;
    letter-spacing: 0.5px;
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
    background: rgba(0, 206, 209, 0.1);
    color: var(--accent-cyan);
    border-color: rgba(0, 206, 209, 0.3);
}

.edit-button:hover {
    background: var(--accent-cyan);
    color: var(--bg-color);
    border-color: var(--accent-cyan);
    box-shadow: 0 0 15px rgba(0, 206, 209, 0.4);
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
    color: var(--light-text);
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
    color: var(--light-text);
}

.button-secondary:hover,
.button-primary:hover {
    opacity: 0.9;
}

/* Upload Zone Styles - Retro-Futuristic */
.upload-zone {
    border: 2px dashed var(--border-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    margin-bottom: var(--spacing-lg);
    text-align: center;
    background: var(--light-bg);
    cursor: pointer;
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.upload-zone::before {
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

.upload-zone:hover {
    border-color: var(--accent-cyan);
    background: rgba(0, 206, 209, 0.05);
    box-shadow: inset 0 0 20px rgba(0, 206, 209, 0.1);
}

.upload-zone:hover::before {
    opacity: 0.1;
}

.upload-zone.drag-over {
    border-color: var(--primary-color);
    border-style: solid;
    background: rgba(255, 105, 180, 0.1);
    transform: scale(1.02);
    box-shadow:
        inset 0 0 30px rgba(255, 105, 180, 0.2),
        0 0 30px rgba(255, 105, 180, 0.3);
}

.upload-zone.drag-over::before {
    opacity: 0.2;
}

.upload-zone.uploading {
    border-color: var(--accent-cyan);
    background: var(--card-bg);
    cursor: default;
    box-shadow: 0 0 25px rgba(0, 206, 209, 0.3);
}

.hidden-file-input {
    display: none;
}

.upload-zone-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-sm);
}

.upload-icon {
    font-size: 3rem;
    margin-bottom: var(--spacing-sm);
}

.upload-text {
    margin: 0;
    font-size: 1.125rem;
    color: var(--text-primary);
}

.upload-subtext {
    margin: 0;
    font-size: 0.875rem;
    color: var(--text-secondary);
}

.upload-formats {
    font-size: 0.75rem;
    color: var(--text-secondary);
    background-color: var(--bg-color);
    padding: var(--spacing-xs) var(--spacing-sm);
    border-radius: var(--radius-sm);
    border: 1px solid var(--border-color);
}

.upload-subtext kbd {
    background-color: var(--light-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-sm);
    padding: 2px 6px;
    font-size: 0.75rem;
    font-family: monospace;
    color: var(--text-primary);
    white-space: nowrap;
}

.uploading-content {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-md);
}

.upload-progress {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-sm);
    width: 100%;
    max-width: 300px;
}

.progress-bar {
    width: 100%;
    height: 8px;
    background-color: var(--border-color);
    border-radius: var(--radius-sm);
    overflow: hidden;
}

.progress-fill {
    height: 100%;
    background-color: var(--primary-color);
    border-radius: var(--radius-sm);
    transition: width var(--transition-fast);
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

    .upload-zone {
        padding: var(--spacing-lg);
    }

    .upload-icon {
        font-size: 2rem;
    }

    .upload-text {
        font-size: 1rem;
    }
}
</style>
