<template>
  <div class="image-uploader">
    <div
      class="upload-area"
      :class="{ 'drag-over': isDragOver, 'has-error': error }"
      @drop.prevent="handleDrop"
      @dragover.prevent="isDragOver = true"
      @dragleave.prevent="isDragOver = false"
      @click="triggerFileInput"
    >
      <input
        ref="fileInput"
        type="file"
        accept="image/jpeg,image/png,image/gif,image/webp,image/svg+xml"
        style="display: none"
        @change="handleFileSelect"
      >

      <!-- Preview Image -->
      <div
        v-if="previewUrl"
        class="preview-container"
      >
        <img
          :src="previewUrl"
          :alt="altText || 'Preview'"
          class="preview-image"
        >
        <button
          v-if="!isUploading"
          type="button"
          class="remove-button"
          @click.stop="clearPreview"
        >
          Remove
        </button>
      </div>

      <!-- Upload Area -->
      <div
        v-else
        class="upload-prompt"
      >
        <div class="upload-icon">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="48"
            height="48"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"
            />
            <polyline points="17 8 12 3 7 8" />
            <line
              x1="12"
              y1="3"
              x2="12"
              y2="15"
            />
          </svg>
        </div>
        <p class="upload-text">
          <strong>Click to upload</strong> or drag and drop
        </p>
        <p class="upload-hint">
          PNG, JPG, GIF, WEBP, or SVG (max {{ maxSizeMB }}MB)
        </p>
      </div>

      <!-- Upload Progress -->
      <div
        v-if="isUploading"
        class="upload-progress"
      >
        <div class="progress-bar">
          <div
            class="progress-fill"
            :style="{ width: uploadProgress + '%' }"
          />
        </div>
        <p class="progress-text">
          Uploading... {{ uploadProgress }}%
        </p>
      </div>
    </div>

    <!-- Error Message -->
    <div
      v-if="error"
      class="error-message"
    >
      {{ error }}
    </div>

    <!-- Metadata Inputs -->
    <div
      v-if="previewUrl && showMetadata"
      class="metadata-inputs"
    >
      <div class="form-group">
        <label for="alt-text">Alt Text</label>
        <input
          id="alt-text"
          v-model="altText"
          type="text"
          placeholder="Describe the image for accessibility"
          class="form-input"
        >
      </div>
      <div class="form-group">
        <label for="caption">Caption</label>
        <input
          id="caption"
          v-model="caption"
          type="text"
          placeholder="Optional caption"
          class="form-input"
        >
      </div>
    </div>

    <!-- Upload Button -->
    <button
      v-if="previewUrl && !isUploading && !uploadComplete"
      type="button"
      class="upload-button"
      @click="uploadFile"
    >
      Upload Image
    </button>

    <!-- Success Message -->
    <div
      v-if="uploadComplete"
      class="success-message"
    >
      Image uploaded successfully!
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from "vue";
import axios from "axios";

const props = defineProps({
    maxSizeMB: {
        type: Number,
        default: 5,
    },
    showMetadata: {
        type: Boolean,
        default: true,
    },
    autoUpload: {
        type: Boolean,
        default: false,
    },
});

const emit = defineEmits(["upload-success", "upload-error"]);

// State
const fileInput = ref(null);
const selectedFile = ref(null);
const previewUrl = ref(null);
const altText = ref("");
const caption = ref("");
const isDragOver = ref(false);
const isUploading = ref(false);
const uploadProgress = ref(0);
const uploadComplete = ref(false);
const error = ref(null);

// Computed
const maxSizeBytes = computed(() => props.maxSizeMB * 1024 * 1024);

// Methods
function triggerFileInput() {
    if (!isUploading.value) {
        fileInput.value?.click();
    }
}

function handleFileSelect(event) {
    const file = event.target.files?.[0];
    if (file) {
        processFile(file);
    }
}

function handleDrop(event) {
    isDragOver.value = false;
    const file = event.dataTransfer.files?.[0];
    if (file) {
        processFile(file);
    }
}

function processFile(file) {
    error.value = null;
    uploadComplete.value = false;

    // Validate file type
    const allowedTypes = [
        "image/jpeg",
        "image/png",
        "image/gif",
        "image/webp",
        "image/svg+xml",
    ];
    if (!allowedTypes.includes(file.type)) {
        error.value =
            "Invalid file type. Please upload an image file (PNG, JPG, GIF, WEBP, or SVG).";
        return;
    }

    // Validate file size
    if (file.size > maxSizeBytes.value) {
        error.value = `File size exceeds ${props.maxSizeMB}MB limit.`;
        return;
    }

    selectedFile.value = file;

    // Create preview
    const reader = new FileReader();
    reader.onload = (e) => {
        previewUrl.value = e.target?.result;
        if (props.autoUpload) {
            uploadFile();
        }
    };
    reader.readAsDataURL(file);
}

async function uploadFile() {
    if (!selectedFile.value) return;

    isUploading.value = true;
    uploadProgress.value = 0;
    error.value = null;

    const formData = new FormData();
    formData.append("file", selectedFile.value);
    if (altText.value) formData.append("alt_text", altText.value);
    if (caption.value) formData.append("caption", caption.value);

    try {
        const response = await axios.post("/api/admin/media/upload", formData, {
            headers: {
                "Content-Type": "multipart/form-data",
            },
            onUploadProgress: (progressEvent) => {
                if (progressEvent.total) {
                    uploadProgress.value = Math.round(
                        (progressEvent.loaded * 100) / progressEvent.total,
                    );
                }
            },
        });

        if (response.data.success) {
            uploadComplete.value = true;
            emit("upload-success", response.data.media);

            // Reset after a delay
            setTimeout(() => {
                clearPreview();
            }, 2000);
        } else {
            throw new Error(response.data.error || "Upload failed");
        }
    } catch (err) {
        error.value =
            err.response?.data?.error ||
            err.message ||
            "Failed to upload image";
        emit("upload-error", error.value);
    } finally {
        isUploading.value = false;
    }
}

function clearPreview() {
    selectedFile.value = null;
    previewUrl.value = null;
    altText.value = "";
    caption.value = "";
    uploadProgress.value = 0;
    uploadComplete.value = false;
    error.value = null;
    if (fileInput.value) {
        fileInput.value.value = "";
    }
}

// Expose methods for parent components
defineExpose({
    clearPreview,
});
</script>

<style scoped>
.image-uploader {
    width: 100%;
}

.upload-area {
    position: relative;
    border: 2px dashed var(--border-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    text-align: center;
    cursor: pointer;
    transition: all var(--transition-fast);
    background-color: var(--light-bg);
    min-height: 200px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
}

.upload-area:hover {
    border-color: var(--primary-color);
    background-color: var(--primary-color-light);
}

.upload-area.drag-over {
    border-color: var(--primary-color);
    background-color: var(--primary-color-light);
    transform: scale(1.02);
}

.upload-area.has-error {
    border-color: var(--error-color);
}

.preview-container {
    position: relative;
    width: 100%;
    max-width: 400px;
}

.preview-image {
    width: 100%;
    height: auto;
    border-radius: var(--radius-md);
    object-fit: contain;
    max-height: 300px;
}

.remove-button {
    position: absolute;
    top: var(--spacing-sm);
    right: var(--spacing-sm);
    background-color: var(--error-color);
    color: white;
    border: none;
    border-radius: var(--radius-md);
    padding: var(--spacing-xs) var(--spacing-sm);
    cursor: pointer;
    font-weight: 500;
    transition: opacity var(--transition-fast);
}

.remove-button:hover {
    opacity: 0.8;
}

.upload-prompt {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-md);
}

.upload-icon {
    color: var(--text-secondary);
}

.upload-text {
    font-size: 1rem;
    color: var(--text-primary);
    margin: 0;
}

.upload-text strong {
    color: var(--primary-color);
}

.upload-hint {
    font-size: 0.875rem;
    color: var(--text-secondary);
    margin: 0;
}

.upload-progress {
    width: 100%;
    max-width: 400px;
}

.progress-bar {
    width: 100%;
    height: 8px;
    background-color: var(--border-color);
    border-radius: var(--radius-full);
    overflow: hidden;
    margin-bottom: var(--spacing-sm);
}

.progress-fill {
    height: 100%;
    background-color: var(--primary-color);
    transition: width var(--transition-fast);
}

.progress-text {
    font-size: 0.875rem;
    color: var(--text-secondary);
    margin: 0;
}

.error-message {
    margin-top: var(--spacing-md);
    padding: var(--spacing-sm) var(--spacing-md);
    background-color: #fee;
    border: 1px solid var(--error-color);
    border-radius: var(--radius-md);
    color: var(--error-color);
    font-size: 0.875rem;
}

.success-message {
    margin-top: var(--spacing-md);
    padding: var(--spacing-sm) var(--spacing-md);
    background-color: #efe;
    border: 1px solid var(--success-color);
    border-radius: var(--radius-md);
    color: var(--success-color);
    font-size: 0.875rem;
    font-weight: 500;
}

.metadata-inputs {
    margin-top: var(--spacing-lg);
    display: flex;
    flex-direction: column;
    gap: var(--spacing-md);
}

.form-group {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xs);
}

.form-group label {
    font-size: 0.875rem;
    font-weight: 600;
    color: var(--text-primary);
}

.form-input {
    padding: var(--spacing-sm) var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    font-size: 1rem;
    transition: border-color var(--transition-fast);
}

.form-input:focus {
    outline: none;
    border-color: var(--primary-color);
}

.upload-button {
    margin-top: var(--spacing-lg);
    padding: var(--spacing-sm) var(--spacing-xl);
    background-color: var(--primary-color);
    color: white;
    border: none;
    border-radius: var(--radius-md);
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: background-color var(--transition-fast);
}

.upload-button:hover {
    background-color: var(--primary-color-dark);
}

@media (max-width: 768px) {
    .upload-area {
        padding: var(--spacing-lg);
        min-height: 150px;
    }

    .preview-image {
        max-height: 200px;
    }
}
</style>
