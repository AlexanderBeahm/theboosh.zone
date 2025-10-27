<template>
  <div class="admin-media-page">
    <div class="page-header">
      <h1>Media Library</h1>
      <p class="page-description">
        Upload and manage images and media files for your articles and
        content.
      </p>
    </div>

    <!-- Tab Navigation -->
    <div class="tab-navigation">
      <button
        class="tab-button"
        :class="{ active: activeTab === 'library' }"
        @click="activeTab = 'library'"
      >
        Browse Media
      </button>
    </div>

    <!-- Tab Content -->
    <div class="tab-content">
      <!-- Upload Tab -->
      <div
        v-if="activeTab === 'upload'"
        class="upload-section"
      >
        <div class="section-header">
          <h2>Upload Media</h2>
          <p>
            Upload images to use in your articles and content.
            Supported formats: JPEG, PNG, GIF, WebP, SVG.
          </p>
        </div>

        <ImageUploader
          ref="uploader"
          :max-size-m-b="5"
          :show-metadata="true"
          :auto-upload="false"
          @upload-success="handleUploadSuccess"
          @upload-error="handleUploadError"
        />
      </div>

      <!-- Library Tab -->
      <div
        v-if="activeTab === 'library'"
        class="library-section"
      >
        <div class="section-header">
          <h2>Media Library</h2>
          <p>Browse, search, and manage your uploaded media files.</p>
        </div>

        <MediaLibrary
          ref="mediaLibrary"
          selection-mode="none"
          @media-updated="handleMediaUpdated"
          @media-deleted="handleMediaDeleted"
        />
      </div>
    </div>

    <!-- Success Toast -->
    <Transition name="toast">
      <div
        v-if="showSuccessToast"
        class="success-toast"
      >
        {{ successMessage }}
      </div>
    </Transition>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import ImageUploader from "../components/ImageUploader.vue";
import MediaLibrary from "../components/MediaLibrary.vue";
import { useAuth } from "../composables/useAuth";

const router = useRouter();
const { requireAuth } = useAuth();

// Protect this page - redirect if not authenticated
requireAuth(router);

// State
const activeTab = ref("library");
const uploader = ref(null);
const mediaLibrary = ref(null);
const showSuccessToast = ref(false);
const successMessage = ref("");

// Methods
function handleUploadSuccess(media) {
    // Show success message
    successMessage.value = `"${media.original_filename}" uploaded successfully!`;
    showSuccessToast.value = true;

    // Hide toast after 3 seconds
    setTimeout(() => {
        showSuccessToast.value = false;
    }, 3000);

    // Switch to library tab and refresh
    setTimeout(() => {
        activeTab.value = "library";
        if (mediaLibrary.value) {
            mediaLibrary.value.fetchMedia();
        }
    }, 500);
}

function handleUploadError() {
    // Error is already displayed by the ImageUploader component
}

function handleMediaUpdated() {
    successMessage.value = "Media metadata updated successfully!";
    showSuccessToast.value = true;

    setTimeout(() => {
        showSuccessToast.value = false;
    }, 3000);
}

function handleMediaDeleted(media) {
    successMessage.value = `"${media.original_filename}" deleted successfully!`;
    showSuccessToast.value = true;

    setTimeout(() => {
        showSuccessToast.value = false;
    }, 3000);
}
</script>

<style scoped>
.admin-media-page {
    max-width: 1400px;
    margin: 0 auto;
    padding: var(--spacing-lg);
}

.page-header {
    text-align: center;
    margin-bottom: var(--spacing-xl);
}

.page-header h1 {
    font-size: 2.5rem;
    color: var(--primary-color);
    margin-bottom: var(--spacing-sm);
    font-weight: 700;
}

.page-description {
    font-size: 1.125rem;
    color: var(--text-secondary);
    max-width: 700px;
    margin: 0 auto;
}

/* Tab Navigation */
.tab-navigation {
    display: flex;
    gap: var(--spacing-sm);
    margin-bottom: var(--spacing-xl);
    border-bottom: 2px solid var(--border-color);
}

.tab-button {
    padding: var(--spacing-md) var(--spacing-xl);
    border: none;
    background-color: transparent;
    color: var(--text-secondary);
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all var(--transition-fast);
    border-bottom: 3px solid transparent;
    margin-bottom: -2px;
}

.tab-button:hover {
    color: var(--primary-color);
}

.tab-button.active {
    color: var(--primary-color);
    border-bottom-color: var(--primary-color);
}

/* Tab Content */
.tab-content {
    animation: fadeIn var(--transition-normal);
}

@keyframes fadeIn {
    from {
        opacity: 0;
        transform: translateY(10px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

.section-header {
    margin-bottom: var(--spacing-lg);
}

.section-header h2 {
    font-size: 1.75rem;
    color: var(--text-primary);
    margin-bottom: var(--spacing-xs);
    font-weight: 600;
}

.section-header p {
    color: var(--text-secondary);
    font-size: 1rem;
}

.upload-section,
.library-section {
    background-color: var(--bg-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    border: 1px solid var(--border-color);
}

/* Success Toast */
.success-toast {
    position: fixed;
    bottom: var(--spacing-xl);
    right: var(--spacing-xl);
    background-color: var(--success-color);
    color: var(--light-text);
    padding: var(--spacing-md) var(--spacing-xl);
    border-radius: var(--radius-lg);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    font-weight: 600;
    z-index: 1000;
}

.toast-enter-active,
.toast-leave-active {
    transition: all var(--transition-normal);
}

.toast-enter-from,
.toast-leave-to {
    opacity: 0;
    transform: translateY(20px);
}

/* Responsive Design */
@media (max-width: 768px) {
    .admin-media-page {
        padding: var(--spacing-md);
    }

    .page-header h1 {
        font-size: 2rem;
    }

    .page-description {
        font-size: 1rem;
    }

    .tab-navigation {
        flex-direction: column;
        border-bottom: none;
        gap: 0;
    }

    .tab-button {
        border-bottom: 1px solid var(--border-color);
        border-left: 3px solid transparent;
        margin-bottom: 0;
        margin-left: -2px;
        text-align: left;
    }

    .tab-button.active {
        border-left-color: var(--primary-color);
        border-bottom-color: var(--border-color);
    }

    .upload-section,
    .library-section {
        padding: var(--spacing-lg);
    }

    .success-toast {
        right: var(--spacing-md);
        left: var(--spacing-md);
        bottom: var(--spacing-md);
    }
}
</style>
