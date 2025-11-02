<template>
  <div class="admin-media-page">
    <div class="page-header">
      <h1>Media Library</h1>
      <p class="page-description">
        Upload and manage images and media files for your articles and
        content.
      </p>
    </div>


    <!-- Media Library Content -->
    <div class="library-section">
      <MediaLibrary
        ref="mediaLibrary"
        selection-mode="none"
        @media-updated="handleMediaUpdated"
        @media-deleted="handleMediaDeleted"
      />
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
import MediaLibrary from "../components/MediaLibrary.vue";
import { useAuth } from "../composables/useAuth";

const router = useRouter();
const { requireAuth } = useAuth();

// Protect this page - redirect if not authenticated
requireAuth(router);

// State
const mediaLibrary = ref(null);
const showSuccessToast = ref(false);
const successMessage = ref("");

// Methods
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
