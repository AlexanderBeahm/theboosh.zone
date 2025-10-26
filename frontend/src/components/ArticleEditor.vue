<template>
  <div
    v-if="isVisible"
    class="modal-overlay"
    @click="handleOverlayClick"
  >
    <div
      class="editor-container"
      @click.stop
    >
      <div class="editor-header">
        <h2>{{ article ? "Edit Article" : "Create New Article" }}</h2>
        <button
          class="close-button"
          @click="$emit('close')"
        >
          ✕
        </button>
      </div>

      <form
        class="editor-form"
        @submit.prevent="handleSave"
      >
        <div class="form-row">
          <div class="form-group">
            <label for="title">Title *</label>
            <input
              id="title"
              v-model="form.title"
              type="text"
              required
              :disabled="isSaving"
              class="form-input"
              placeholder="Enter article title"
              @input="generateSlug"
            >
          </div>

          <div class="form-group">
            <label for="slug">URL Slug *</label>
            <input
              id="slug"
              v-model="form.slug"
              type="text"
              required
              :disabled="isSaving"
              class="form-input"
              placeholder="article-url-slug"
            >
          </div>
        </div>

        <div class="form-group">
          <label for="excerpt">Excerpt</label>
          <textarea
            id="excerpt"
            v-model="form.excerpt"
            :disabled="isSaving"
            class="form-textarea"
            placeholder="Brief description of the article (optional)"
            rows="2"
          />
        </div>

        <div class="form-group">
          <label for="content">Content *</label>
          <div class="editor-tabs">
            <button
              type="button"
              class="tab-button"
              :class="{ active: activeTab === 'write' }"
              @click="activeTab = 'write'"
            >
              Write
            </button>
            <button
              type="button"
              class="tab-button"
              :class="{ active: activeTab === 'preview' }"
              @click="activeTab = 'preview'"
            >
              Preview
            </button>
            <button
              type="button"
              class="tab-button insert-image-button"
              :disabled="isSaving"
              @click="openUnifiedInsertModal"
            >
              Insert Image
            </button>
          </div>

          <div class="editor-content">
            <textarea
              v-show="activeTab === 'write'"
              id="content"
              ref="contentTextarea"
              v-model="form.content"
              required
              :disabled="isSaving"
              class="content-textarea"
              placeholder="Write your article content in Markdown..."
              rows="20"
              @keydown="handleTabKey"
              @paste="handlePaste"
            />

            <div
              v-show="activeTab === 'preview'"
              class="preview-container"
            >
              <MarkdownRenderer
                v-if="form.content"
                :content="form.content"
                :sanitize="true"
              />
              <div
                v-else
                class="empty-preview"
              >
                <p>
                  Nothing to preview yet. Switch to the Write
                  tab and add some content!
                </p>
              </div>
            </div>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="tags">Tags</label>
            <div class="tags-input-container">
              <input
                v-model="tagInput"
                type="text"
                :disabled="isSaving"
                class="tag-input"
                placeholder="Add tags..."
                @keydown="handleTagInput"
                @input="searchTags"
              >

              <div
                v-if="tagSuggestions.length > 0"
                class="tag-suggestions"
              >
                <div
                  v-for="tag in tagSuggestions"
                  :key="tag.id"
                  class="tag-suggestion"
                  @click="addTag(tag)"
                >
                  {{ tag.name }}
                  <span class="usage-count">({{ tag.usage_count }})</span>
                </div>
              </div>
              <div class="selected-tags">
                <span
                  v-for="tag in selectedTags"
                  :key="tag.id"
                  class="selected-tag"
                >
                  {{ tag.name }}
                  <button
                    type="button"
                    class="remove-tag-button"
                    @click="removeTag(tag)"
                  >
                    ✕
                  </button>
                </span>
              </div>
            </div>
          </div>

          <div class="form-group">
            <label for="author">Author</label>
            <input
              id="author"
              v-model="form.author"
              type="text"
              :disabled="isSaving"
              class="form-input"
              placeholder="Author name"
            >
          </div>
        </div>

        <div class="form-group">
          <label>Featured Image</label>
          <div class="featured-image-section">
            <div
              v-if="form.featured_image"
              class="featured-image-preview"
            >
              <img
                :src="form.featured_image"
                alt="Featured image preview"
              >
              <button
                type="button"
                class="remove-image-button"
                :disabled="isSaving"
                @click="removeFeaturedImage"
              >
                Remove Image
              </button>
            </div>

            <div
              v-else
              class="image-selection-buttons"
            >
              <button
                type="button"
                class="select-image-button"
                :disabled="isSaving"
                @click="showMediaLibraryModal = true"
              >
                Browse Media Library
              </button>
              <button
                type="button"
                class="upload-image-button"
                :disabled="isSaving"
                @click="showImageUploadModal = true"
              >
                Upload New Image
              </button>
            </div>

            <input
              v-model="form.featured_image"
              :type="isRelativeUrl ? 'text' : 'url'"
              :disabled="isSaving"
              class="form-input featured-image-url"
              placeholder="Or enter image URL directly"
            >
          </div>
        </div>

        <div class="form-group">
          <label for="meta_description">Meta Description</label>
          <input
            id="meta_description"
            v-model="form.meta_description"
            type="text"
            :disabled="isSaving"
            class="form-input"
            placeholder="SEO meta description"
            maxlength="160"
          >
          <small v-if="form.meta_description">
            {{ form.meta_description.length }}/160 characters
          </small>
        </div>

        <div class="form-group">
          <div class="publish-controls">
            <div class="checkbox-group">
              <input
                id="is_published"
                v-model="form.is_published"
                type="checkbox"
                :disabled="isSaving"
                class="form-checkbox"
              >
              <label
                for="is_published"
                class="checkbox-label"
              >
                Publish immediately
              </label>
            </div>

            <div
              v-if="form.is_published && !article"
              class="publish-note"
            >
              This article will be published with the current date
              and time.
            </div>

            <div
              v-if="
                article &&
                  !article.is_published &&
                  form.is_published
              "
              class="publish-note"
            >
              This article will be published with the current date
              and time.
            </div>
          </div>
        </div>

        <div class="form-actions">
          <div class="action-buttons">
            <button
              type="button"
              :disabled="isSaving"
              class="cancel-button"
              @click="$emit('close')"
            >
              Cancel
            </button>

            <button
              type="submit"
              :disabled="isSaving || !isFormValid"
              class="save-button"
            >
              <span v-if="isSaving">{{
                article ? "Updating..." : "Creating..."
              }}</span>
              <span v-else>{{
                article ? "Update Article" : "Create Article"
              }}</span>
            </button>
          </div>

          <div
            v-if="error"
            class="error-message"
          >
            {{ error }}
          </div>
        </div>
      </form>
    </div>

    <!-- Media Library Modal -->
    <div
      v-if="showMediaLibraryModal"
      class="image-modal-overlay"
      @click="showMediaLibraryModal = false"
    >
      <div
        class="image-modal-content"
        @click.stop
      >
        <div class="image-modal-header">
          <h3>Select Featured Image</h3>
          <button
            class="close-button"
            @click="showMediaLibraryModal = false"
          >
            ✕
          </button>
        </div>
        <div class="image-modal-body">
          <MediaLibrary
            ref="mediaLibrary"
            selection-mode="single"
            @media-selected="handleMediaSelected"
          />
        </div>
      </div>
    </div>

    <!-- Image Upload Modal -->
    <div
      v-if="showImageUploadModal"
      class="image-modal-overlay"
      @click="showImageUploadModal = false"
    >
      <div
        class="image-modal-content"
        @click.stop
      >
        <div class="image-modal-header">
          <h3>Upload Featured Image</h3>
          <button
            class="close-button"
            @click="showImageUploadModal = false"
          >
            ✕
          </button>
        </div>
        <div class="image-modal-body">
          <ImageUploader
            ref="imageUploader"
            :max-size-m-b="5"
            :show-metadata="true"
            :auto-upload="false"
            @upload-success="handleImageUpload"
          />
        </div>
      </div>
    </div>

    <!-- Paste Image Confirmation Modal -->
    <div
      v-if="showPasteImageModal"
      class="image-modal-overlay"
      @click="closePasteImageModal"
    >
      <div
        class="image-modal-content"
        @click.stop
      >
        <div class="image-modal-header">
          <h3>Confirm Pasted Image</h3>
          <button
            class="close-button"
            @click="closePasteImageModal"
          >
            ✕
          </button>
        </div>
        <div class="image-modal-body">
          <div
            v-if="pastedImageData"
            class="paste-image-preview"
          >
            <div class="preview-image-container">
              <img
                :src="pastedImageData.dataUrl"
                :alt="pastedImageData.name"
                class="preview-image"
              >
            </div>

            <div class="paste-image-info">
              <p>
                <strong>File:</strong>
                {{ pastedImageData.name }}
              </p>
              <p>
                <strong>Type:</strong>
                {{ pastedImageData.type }}
              </p>
              <p>
                <strong>Size:</strong>
                {{ formatFileSize(pastedImageData.size) }}
              </p>
            </div>

            <div class="paste-image-actions">
              <button
                type="button"
                class="button-secondary"
                @click="closePasteImageModal"
              >
                Cancel
              </button>
              <button
                type="button"
                class="button-primary"
                :disabled="isPastingImage"
                @click="handlePastedImageConfirm"
              >
                <span v-if="isPastingImage">Uploading...</span>
                <span v-else>Upload and Insert</span>
              </button>
            </div>
          </div>

          <div
            v-if="isPastingImage"
            class="uploading-indicator"
          >
            <div class="loading-spinner" />
            <p>Processing pasted image...</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Unified Insert Image Modal -->
    <div
      v-if="showUnifiedInsertModal"
      class="image-modal-overlay"
      @click="closeUnifiedInsertModal"
    >
      <div
        class="image-modal-content unified-modal"
        @click.stop
      >
        <div class="image-modal-header">
          <h3>Insert Image</h3>
          <button
            class="close-button"
            @click="closeUnifiedInsertModal"
          >
            ✕
          </button>
        </div>

        <div class="unified-modal-tabs">
          <button
            type="button"
            class="unified-tab-button"
            :class="{ active: unifiedModalActiveTab === 'browse' }"
            @click="unifiedModalActiveTab = 'browse'"
          >
            Browse Library
          </button>
          <button
            type="button"
            class="unified-tab-button"
            :class="{ active: unifiedModalActiveTab === 'upload' }"
            @click="unifiedModalActiveTab = 'upload'"
          >
            Upload New
          </button>
          <button
            type="button"
            class="unified-tab-button"
            :class="{ active: unifiedModalActiveTab === 'paste' }"
            @click="unifiedModalActiveTab = 'paste'"
          >
            Paste Image
          </button>
        </div>

        <div class="image-modal-body">
          <!-- Browse Tab -->
          <div
            v-show="unifiedModalActiveTab === 'browse'"
            class="unified-tab-content"
          >
            <MediaLibrary
              ref="unifiedMediaLibrary"
              selection-mode="single"
              @media-selected="handleUnifiedMediaSelected"
            />
          </div>

          <!-- Upload Tab -->
          <div
            v-show="unifiedModalActiveTab === 'upload'"
            class="unified-tab-content"
          >
            <ImageUploader
              ref="unifiedImageUploader"
              :max-size-m-b="5"
              :show-metadata="true"
              :auto-upload="false"
              @upload-success="handleUnifiedImageUpload"
            />
          </div>

          <!-- Paste Tab -->
          <div
            v-show="unifiedModalActiveTab === 'paste'"
            class="unified-tab-content"
          >
            <div class="paste-instructions">
              <div class="paste-icon">
                📋
              </div>
              <h4>Paste an Image</h4>
              <p>
                Use <kbd>Ctrl+V</kbd> (or <kbd>Cmd+V</kbd> on
                Mac) to paste an image from your clipboard. You
                can also paste directly into the content area
                while writing.
              </p>
              <div class="paste-tips">
                <h5>Tips:</h5>
                <ul>
                  <li>
                    Copy an image from another application
                  </li>
                  <li>Take a screenshot and copy it</li>
                  <li>
                    Right-click an image in your browser and
                    "Copy image"
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from "vue";
import axios from "axios";
import MarkdownRenderer from "./MarkdownRenderer.vue";
import MediaLibrary from "./MediaLibrary.vue";
import ImageUploader from "./ImageUploader.vue";

const props = defineProps({
    article: {
        type: Object,
        default: null,
    },
    isVisible: {
        type: Boolean,
        default: false,
    },
});

const emit = defineEmits(["close", "saved"]);

// Reactive state
const isSaving = ref(false);
const error = ref("");
const activeTab = ref("write");
const tagInput = ref("");
const tagSuggestions = ref([]);
const availableTags = ref([]);
const selectedTags = ref([]);
const showMediaLibraryModal = ref(false);
const showImageUploadModal = ref(false);
const showPasteImageModal = ref(false);
const showUnifiedInsertModal = ref(false);
const unifiedModalActiveTab = ref("browse");
const mediaLibrary = ref(null);
const imageUploader = ref(null);
const unifiedMediaLibrary = ref(null);
const unifiedImageUploader = ref(null);
const contentTextarea = ref(null);
const savedCaretPosition = ref(0);
const pastedImageData = ref(null);
const isPastingImage = ref(false);

const form = ref({
    title: "",
    slug: "",
    content: "",
    excerpt: "",
    author: "Alex Beahm",
    featured_image: "",
    meta_description: "",
    is_published: false,
});

// Computed properties
const isFormValid = computed(() => {
    return (
        form.value.title.trim() &&
        form.value.slug.trim() &&
        form.value.content.trim()
    );
});

const isRelativeUrl = computed(() => {
    const url = form.value.featured_image;
    return url && (url.startsWith("/") || !url.includes("://"));
});

// Methods
function initializeForm() {
    if (props.article) {
        // Editing existing article
        form.value = {
            title: props.article.title || "",
            slug: props.article.slug || "",
            content: props.article.content || "",
            excerpt: props.article.excerpt || "",
            author: props.article.author || "Alex Beahm",
            featured_image: props.article.featured_image || "",
            meta_description: props.article.meta_description || "",
            is_published: props.article.is_published || false,
        };

        // Set selected tags
        selectedTags.value = props.article.tags ? [...props.article.tags] : [];
    } else {
        // Creating new article
        form.value = {
            title: "",
            slug: "",
            content: "",
            excerpt: "",
            author: "Alex Beahm",
            featured_image: "",
            meta_description: "",
            is_published: false,
        };
        selectedTags.value = [];
    }
}

function generateSlug() {
    if (!form.value.title || props.article) return; // Don't auto-generate slug when editing

    const slug = form.value.title
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, "") // Remove special characters
        .replace(/\s+/g, "-") // Replace spaces with hyphens
        .replace(/-+/g, "-") // Replace multiple hyphens with single
        .replace(/^-|-$/g, ""); // Remove leading/trailing hyphens

    form.value.slug = slug;
}

async function loadTags() {
    try {
        const response = await axios.get("/api/tags");
        if (response.data.success) {
            availableTags.value = response.data.tags || [];
        }
    } catch {
        // Failed to load tags - non-critical, continue without tag suggestions
    }
}

function searchTags() {
    if (!tagInput.value.trim()) {
        tagSuggestions.value = [];
        return;
    }

    const query = tagInput.value.toLowerCase();
    tagSuggestions.value = availableTags.value
        .filter(
            (tag) =>
                tag.name.toLowerCase().includes(query) &&
                !selectedTags.value.some((selected) => selected.id === tag.id),
        )
        .slice(0, 5); // Limit to 5 suggestions
}

function addTag(tag) {
    if (!selectedTags.value.some((t) => t.id === tag.id)) {
        selectedTags.value.push(tag);
    }
    tagInput.value = "";
    tagSuggestions.value = [];
}

function removeTag(tagToRemove) {
    selectedTags.value = selectedTags.value.filter(
        (tag) => tag.id !== tagToRemove.id,
    );
}

function handleTagInput(event) {
    if (event.key === "Enter" && tagInput.value.trim()) {
        event.preventDefault();

        const tagName = tagInput.value.trim();

        // Check if tag already exists
        const existingTag = availableTags.value.find(
            (tag) => tag.name.toLowerCase() === tagName.toLowerCase(),
        );

        if (existingTag) {
            addTag(existingTag);
        } else {
            // Create a temporary tag object (will be created on server when saving)
            const tempTag = {
                id: `temp-${Date.now()}`,
                name: tagName,
                slug: tagName.toLowerCase().replace(/\s+/g, "-"),
                usage_count: 0,
            };
            selectedTags.value.push(tempTag);
            tagInput.value = "";
            tagSuggestions.value = [];
        }
    } else if (event.key === "Escape") {
        tagSuggestions.value = [];
    }
}

function handleTabKey(event) {
    if (event.key === "Tab") {
        event.preventDefault();
        const textarea = event.target;
        const start = textarea.selectionStart;
        const end = textarea.selectionEnd;

        // Insert tab character
        form.value.content =
            form.value.content.substring(0, start) +
            "\t" +
            form.value.content.substring(end);

        // Move cursor to after the inserted tab
        textarea.selectionStart = textarea.selectionEnd = start + 1;
    }
}

async function handlePaste(event) {
    const clipboardData =
        event.clipboardData || event.originalEvent?.clipboardData;
    if (!clipboardData) return;

    // Check if clipboard contains image files
    const items = Array.from(clipboardData.items);
    const imageItems = items.filter((item) => item.type.startsWith("image/"));

    if (imageItems.length === 0) {
        // No images in clipboard, allow normal paste
        return;
    }

    // Prevent default paste behavior when images are detected
    event.preventDefault();

    // Save current caret position
    if (contentTextarea.value) {
        savedCaretPosition.value = contentTextarea.value.selectionStart;
    }

    // Process the first image found
    const imageItem = imageItems[0];
    const file = imageItem.getAsFile();

    if (file) {
        isPastingImage.value = true;

        // Convert image to base64 for preview and upload
        const reader = new FileReader();
        reader.onload = (e) => {
            pastedImageData.value = {
                file: file,
                dataUrl: e.target.result,
                type: file.type,
                size: file.size,
                name: `pasted-image-${Date.now()}.${file.type.split("/")[1]}`,
            };

            // Show paste confirmation modal
            showPasteImageModal.value = true;
            isPastingImage.value = false;
        };

        reader.onerror = () => {
            isPastingImage.value = false;
            error.value = "Failed to process pasted image";
        };

        reader.readAsDataURL(file);
    }
}

function handleMediaSelected(media) {
    form.value.featured_image = media.url;
    showMediaLibraryModal.value = false;
}

function handleImageUpload(media) {
    form.value.featured_image = media.url;
    showImageUploadModal.value = false;
}

function removeFeaturedImage() {
    form.value.featured_image = "";
}

function openUnifiedInsertModal() {
    // Save current caret position
    if (contentTextarea.value) {
        savedCaretPosition.value = contentTextarea.value.selectionStart;
    }
    unifiedModalActiveTab.value = "browse";
    showUnifiedInsertModal.value = true;
}

function closeUnifiedInsertModal() {
    showUnifiedInsertModal.value = false;
    unifiedModalActiveTab.value = "browse";
}

function handleUnifiedMediaSelected(media) {
    insertImageMarkdown(media);
    closeUnifiedInsertModal();
}

function handleUnifiedImageUpload(media) {
    insertImageMarkdown(media);
    closeUnifiedInsertModal();
}

function insertImageMarkdown(media) {
    // Generate markdown syntax for the image
    const altText = media.alt_text || media.original_filename || "Image";
    const imageUrl = media.url;
    const markdownSyntax = `![${altText}](${imageUrl})`;

    // Insert at saved caret position
    const pos = savedCaretPosition.value;
    const currentContent = form.value.content || "";

    form.value.content =
        currentContent.substring(0, pos) +
        markdownSyntax +
        currentContent.substring(pos);

    // Restore focus and move caret to after inserted text
    if (contentTextarea.value) {
        contentTextarea.value.focus();
        const newCaretPos = pos + markdownSyntax.length;
        contentTextarea.value.setSelectionRange(newCaretPos, newCaretPos);
    }
}

function closePasteImageModal() {
    showPasteImageModal.value = false;
    pastedImageData.value = null;
    isPastingImage.value = false;
}

async function handlePastedImageConfirm() {
    if (!pastedImageData.value) return;

    try {
        isPastingImage.value = true;

        // Create FormData for upload
        const formData = new FormData();
        formData.append("file", pastedImageData.value.file);
        formData.append(
            "alt_text",
            `Pasted image ${new Date().toLocaleString()}`,
        );
        formData.append("caption", "");

        // Upload the pasted image
        const response = await axios.post("/api/admin/media/upload", formData, {
            headers: {
                "Content-Type": "multipart/form-data",
            },
        });

        if (response.data.success) {
            // Insert markdown syntax at saved caret position
            const media = response.data.media;
            const altText =
                media.alt_text || media.original_filename || "Pasted Image";
            const imageUrl = media.url;
            const markdownSyntax = `![${altText}](${imageUrl})`;

            // Insert at saved caret position
            const pos = savedCaretPosition.value;
            const currentContent = form.value.content || "";

            form.value.content =
                currentContent.substring(0, pos) +
                markdownSyntax +
                currentContent.substring(pos);

            // Close modal
            closePasteImageModal();

            // Restore focus and move caret to after inserted text
            if (contentTextarea.value) {
                contentTextarea.value.focus();
                const newCaretPos = pos + markdownSyntax.length;
                contentTextarea.value.setSelectionRange(
                    newCaretPos,
                    newCaretPos,
                );
            }
        } else {
            throw new Error(
                response.data.error || "Failed to upload pasted image",
            );
        }
    } catch (err) {
        error.value =
            err.response?.data?.error ||
            err.message ||
            "Failed to upload pasted image";
    } finally {
        isPastingImage.value = false;
    }
}

function formatFileSize(bytes) {
    if (bytes === 0) return "0 Bytes";
    const k = 1024;
    const sizes = ["Bytes", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round((bytes / Math.pow(k, i)) * 100) / 100 + " " + sizes[i];
}

async function handleSave() {
    if (!isFormValid.value) return;

    isSaving.value = true;
    error.value = "";

    try {
        // Prepare article data
        const articleData = {
            ...form.value,
            tags: selectedTags.value.map((tag) => tag.name), // Send tag names, not objects
        };

        let response;
        if (props.article) {
            // Update existing article
            response = await axios.put(
                `/api/admin/articles/${props.article.id}`,
                articleData,
            );
        } else {
            // Create new article
            response = await axios.post("/api/admin/articles", articleData);
        }

        if (response.data.success) {
            emit("saved", response.data.article);
        } else {
            throw new Error(response.data.error || "Failed to save article");
        }
    } catch (err) {
        error.value =
            err.response?.data?.error ||
            err.message ||
            "Failed to save article";
    } finally {
        isSaving.value = false;
    }
}

function handleOverlayClick() {
    if (!isSaving.value) {
        emit("close");
    }
}

// Watchers
watch(
    () => props.isVisible,
    (newValue) => {
        if (newValue) {
            initializeForm();
            loadTags();
            activeTab.value = "write";
            error.value = "";
        }
    },
);

// Lifecycle
onMounted(() => {
    if (props.isVisible) {
        initializeForm();
        loadTags();
    }
});
</script>

<style scoped>
.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.8);
    backdrop-filter: blur(8px);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 2000;
    overflow-y: auto;
    padding: var(--spacing-lg);
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

.editor-container {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    box-shadow:
        var(--shadow-xl),
        0 0 60px rgba(255, 105, 180, 0.2);
    width: 100%;
    max-width: 1000px;
    max-height: 90vh;
    overflow-y: auto;
    position: relative;
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

.editor-container::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: var(--gradient-retro-secondary);
    border-radius: var(--radius-lg) var(--radius-lg) 0 0;
    z-index: 1;
}

.editor-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--spacing-lg);
    border-bottom: 1px solid var(--border-color);
    background-color: var(--light-bg);
    border-radius: var(--radius-lg) var(--radius-lg) 0 0;
}

.editor-header h2 {
    margin: 0;
    color: var(--text-primary);
    font-weight: 600;
    font-size: 1.5rem;
}

.close-button {
    width: 32px;
    height: 32px;
    border: none;
    background-color: transparent;
    color: var(--text-secondary);
    font-size: 1.25rem;
    cursor: pointer;
    border-radius: var(--radius-sm);
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all var(--transition-fast);
}

.close-button:hover {
    background-color: var(--error-bg);
    color: var(--error-text);
}

.editor-form {
    padding: var(--spacing-lg);
}

.form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: var(--spacing-lg);
    margin-bottom: var(--spacing-lg);
}

.form-group {
    margin-bottom: var(--spacing-lg);
}

.form-group label {
    display: block;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: var(--spacing-xs);
    font-size: 0.875rem;
}

.form-input,
.form-textarea {
    width: 100%;
    padding: var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    font-size: 1rem;
    background: var(--bg-color);
    color: var(--text-primary);
    transition: all var(--transition-fast);
    font-family: inherit;
}

.form-input:focus,
.form-textarea:focus {
    outline: none;
    border-color: var(--accent-cyan);
    box-shadow:
        0 0 0 2px rgba(0, 206, 209, 0.2),
        0 0 20px rgba(0, 206, 209, 0.3);
    background: var(--card-bg);
}

.form-input::placeholder,
.form-textarea::placeholder {
    color: var(--text-secondary);
}

.form-input:disabled,
.form-textarea:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    background: var(--darker-bg);
}

.form-textarea {
    resize: vertical;
    min-height: 80px;
}

/* Editor Tabs - Retro-Futuristic */
.editor-tabs {
    display: flex;
    margin-bottom: var(--spacing-sm);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md) var(--radius-md) 0 0;
    overflow: hidden;
    background: var(--darker-bg);
    position: relative;
}

.editor-tabs::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 1px;
    background: var(--gradient-retro-secondary);
    opacity: 0.5;
}

.tab-button {
    flex: 1;
    padding: var(--spacing-sm) var(--spacing-md);
    border: none;
    background: transparent;
    color: var(--text-secondary);
    cursor: pointer;
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    transition: all var(--transition-fast);
    position: relative;
    border-bottom: 3px solid transparent;
}

.tab-button::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: var(--gradient-retro-primary);
    opacity: 0;
    transition: opacity var(--transition-fast);
    z-index: -1;
}

.tab-button.active {
    background: var(--card-bg);
    color: var(--accent-cyan);
    border-bottom-color: var(--accent-cyan);
    box-shadow: 0 0 20px rgba(0, 206, 209, 0.3);
}

.tab-button.active::before {
    opacity: 0.1;
}

.tab-button:not(.active):hover {
    background: rgba(0, 206, 209, 0.05);
    color: var(--accent-cyan);
    border-bottom-color: rgba(0, 206, 209, 0.5);
}

.tab-button:not(.active):hover::before {
    opacity: 0.05;
}

.editor-content {
    position: relative;
    border: 1px solid var(--border-color);
    border-top: none;
    border-radius: 0 0 var(--radius-md) var(--radius-md);
    overflow: hidden;
}

.content-textarea {
    width: 100%;
    min-height: 400px;
    padding: var(--spacing-lg);
    border: none;
    border-radius: 0;
    resize: vertical;
    font-family: "Monaco", "Menlo", "Ubuntu Mono", monospace;
    font-size: 0.875rem;
    line-height: 1.6;
    background-color: var(--bg-color);
}

.content-textarea:focus {
    box-shadow: none;
}

.preview-container {
    min-height: 400px;
    padding: var(--spacing-lg);
    background-color: var(--bg-color);
    overflow-y: auto;
}

.empty-preview {
    display: flex;
    align-items: center;
    justify-content: center;
    height: 400px;
    color: var(--text-secondary);
    font-style: italic;
}

/* Tags Input */
.tags-input-container {
    position: relative;
}

.selected-tags {
    display: flex;
    flex-wrap: wrap;
    gap: var(--spacing-xs);
    min-height: 0;
}

.selected-tags:not(:empty) {
    margin-bottom: var(--spacing-sm);
}

.selected-tag {
    display: inline-flex;
    align-items: center;
    gap: var(--spacing-xs);
    padding: var(--spacing-xs) var(--spacing-sm);
    background-color: var(--primary-color-light);
    color: var(--primary-color);
    border-radius: var(--radius-sm);
    font-size: 0.875rem;
    font-weight: 500;
}

.remove-tag-button {
    background: none;
    border: none;
    color: var(--primary-color);
    cursor: pointer;
    font-size: 0.75rem;
    padding: 0;
    width: 14px;
    height: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    transition: background-color var(--transition-fast);
}

.remove-tag-button:hover {
    background-color: var(--primary-color);
    color: var(--light-text);
}

.tag-input {
    width: 100%;
    padding: var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    font-size: 1rem;
    background-color: var(--bg-color);
    color: var(--text-primary);
}

.tag-suggestions {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    background-color: var(--card-bg);
    border: 1px solid var(--border-color);
    border-top: none;
    border-radius: 0 0 var(--radius-md) var(--radius-md);
    box-shadow: var(--shadow-md);
    z-index: 100;
    max-height: 150px;
    overflow-y: auto;
}

.tag-suggestion {
    padding: var(--spacing-sm) var(--spacing-md);
    cursor: pointer;
    display: flex;
    justify-content: space-between;
    align-items: center;
    transition: background-color var(--transition-fast);
}

.tag-suggestion:hover {
    background-color: var(--light-bg);
}

.usage-count {
    font-size: 0.75rem;
    color: var(--text-secondary);
}

/* Publish Controls */
.publish-controls {
    padding: var(--spacing-lg);
    background-color: var(--light-bg);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
}

.checkbox-group {
    display: flex;
    align-items: center;
    gap: var(--spacing-sm);
}

.form-checkbox {
    width: 18px;
    height: 18px;
    cursor: pointer;
}

.checkbox-label {
    cursor: pointer;
    font-weight: 500;
    margin: 0;
}

.publish-note {
    margin-top: var(--spacing-sm);
    padding: var(--spacing-sm);
    background-color: var(--primary-color-light);
    color: var(--primary-color);
    border-radius: var(--radius-sm);
    font-size: 0.875rem;
    border-left: 3px solid var(--primary-color);
}

/* Form Actions */
.form-actions {
    margin-top: var(--spacing-xl);
    padding-top: var(--spacing-lg);
    border-top: 1px solid var(--border-color);
}

.action-buttons {
    display: flex;
    justify-content: flex-end;
    gap: var(--spacing-md);
    margin-bottom: var(--spacing-md);
}

.cancel-button,
.save-button {
    padding: var(--spacing-sm) var(--spacing-lg);
    border: none;
    border-radius: var(--radius-md);
    font-weight: 600;
    cursor: pointer;
    transition: all var(--transition-fast);
    font-size: 1rem;
}

.cancel-button {
    background-color: var(--light-bg);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
}

.cancel-button:hover:not(:disabled) {
    background-color: var(--border-color);
}

.save-button {
    background-color: var(--primary-color);
    color: var(--light-text);
}

.save-button:hover:not(:disabled) {
    background-color: var(--primary-color-dark);
    transform: translateY(-1px);
    box-shadow: var(--shadow-sm);
}

.save-button:disabled,
.cancel-button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    transform: none;
}

.error-message {
    display: flex;
    align-items: center;
    gap: var(--spacing-sm);
    padding: var(--spacing-md);
    background-color: var(--error-bg);
    color: var(--error-text);
    border: 1px solid var(--error-border);
    border-radius: var(--radius-md);
    font-size: 0.875rem;
}

.error-icon {
    font-size: 1rem;
}

small {
    display: block;
    margin-top: var(--spacing-xs);
    font-size: 0.75rem;
    color: var(--text-secondary);
}

/* Responsive Design */
@media (max-width: 768px) {
    .modal-overlay {
        padding: var(--spacing-md);
    }

    .editor-container {
        max-height: 95vh;
    }

    .editor-header,
    .editor-form {
        padding: var(--spacing-md);
    }

    .form-row {
        grid-template-columns: 1fr;
        gap: 0;
    }

    .content-textarea {
        min-height: 300px;
        font-size: 1rem;
    }

    .preview-container {
        min-height: 300px;
    }

    .empty-preview {
        height: 300px;
    }

    .action-buttons {
        flex-direction: column;
    }
}

@media (max-width: 480px) {
    .editor-header {
        flex-direction: column;
        gap: var(--spacing-sm);
        text-align: center;
    }

    .editor-header h2 {
        font-size: 1.25rem;
    }

    .content-textarea {
        padding: var(--spacing-sm);
    }

    .preview-container {
        padding: var(--spacing-sm);
    }
}

/* Featured Image Section */
.featured-image-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-md);
}

.featured-image-preview {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-sm);
    padding: var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    background-color: var(--light-bg);
}

.featured-image-preview img {
    width: 100%;
    max-height: 300px;
    object-fit: contain;
    border-radius: var(--radius-md);
}

.remove-image-button {
    padding: var(--spacing-xs) var(--spacing-md);
    border: 1px solid var(--error-color);
    background-color: var(--error-bg);
    color: var(--error-color);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 500;
    font-size: 0.875rem;
    transition: all var(--transition-fast);
}

.remove-image-button:hover:not(:disabled) {
    background-color: var(--error-color);
    color: var(--light-text);
}

.image-selection-buttons {
    display: flex;
    gap: var(--spacing-sm);
    flex-wrap: wrap;
}

.select-image-button,
.upload-image-button {
    flex: 1;
    min-width: 180px;
    padding: var(--spacing-sm) var(--spacing-md);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    cursor: pointer;
    font-weight: 500;
    font-size: 0.875rem;
    transition: all var(--transition-fast);
}

.select-image-button {
    background-color: var(--primary-color-light);
    color: var(--primary-color);
    border-color: var(--primary-color);
}

.select-image-button:hover:not(:disabled) {
    background-color: var(--primary-color);
    color: var(--light-text);
}

.upload-image-button {
    background-color: var(--bg-color);
    color: var(--text-primary);
}

.upload-image-button:hover:not(:disabled) {
    background-color: var(--primary-color-light);
    border-color: var(--primary-color);
    color: var(--primary-color);
}

.featured-image-url {
    margin-top: 0;
}

/* Image Modals */
.image-modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: rgba(0, 0, 0, 0.75);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 3000;
    padding: var(--spacing-lg);
}

.image-modal-content {
    background-color: var(--card-bg);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-xl);
    width: 100%;
    max-width: 1200px;
    max-height: 90vh;
    overflow: hidden;
    display: flex;
    flex-direction: column;
}

.image-modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--spacing-lg);
    border-bottom: 1px solid var(--border-color);
    background-color: var(--light-bg);
}

.image-modal-header h3 {
    margin: 0;
    color: var(--text-primary);
    font-weight: 600;
    font-size: 1.25rem;
}

.image-modal-body {
    flex: 1;
    overflow-y: auto;
    padding: var(--spacing-lg);
}

/* Paste Image Modal Styles */
.paste-image-preview {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-lg);
}

.preview-image-container {
    display: flex;
    justify-content: center;
    padding: var(--spacing-md);
    background-color: var(--light-bg);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
}

.preview-image {
    max-width: 100%;
    max-height: 300px;
    object-fit: contain;
    border-radius: var(--radius-sm);
}

.paste-image-info {
    padding: var(--spacing-md);
    background-color: var(--light-bg);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
}

.paste-image-info p {
    margin: var(--spacing-xs) 0;
    font-size: 0.875rem;
    color: var(--text-primary);
}

.paste-image-actions {
    display: flex;
    gap: var(--spacing-md);
    justify-content: flex-end;
}

.uploading-indicator {
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

.button-secondary,
.button-primary {
    padding: var(--spacing-sm) var(--spacing-lg);
    border: none;
    border-radius: var(--radius-md);
    font-weight: 600;
    cursor: pointer;
    transition: all var(--transition-fast);
    font-size: 1rem;
}

.button-secondary {
    background-color: var(--light-bg);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
}

.button-secondary:hover:not(:disabled) {
    background-color: var(--border-color);
}

.button-primary {
    background-color: var(--primary-color);
    color: var(--light-text);
}

.button-primary:hover:not(:disabled) {
    background-color: var(--primary-color-dark);
    transform: translateY(-1px);
    box-shadow: var(--shadow-sm);
}

.button-primary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
    transform: none;
}

@keyframes spin {
    0% {
        transform: rotate(0deg);
    }
    100% {
        transform: rotate(360deg);
    }
}

/* Unified Insert Modal Styles */
.unified-modal {
    max-width: 1400px;
    max-height: 95vh;
}

.unified-modal-tabs {
    display: flex;
    border-bottom: 1px solid var(--border-color);
    background-color: var(--light-bg);
}

.unified-tab-button {
    flex: 1;
    padding: var(--spacing-md) var(--spacing-lg);
    border: none;
    background-color: transparent;
    color: var(--text-secondary);
    cursor: pointer;
    font-size: 0.875rem;
    font-weight: 500;
    transition: all var(--transition-fast);
    border-bottom: 3px solid transparent;
}

.unified-tab-button.active {
    background-color: var(--bg-color);
    color: var(--primary-color);
    border-bottom-color: var(--primary-color);
}

.unified-tab-button:not(.active):hover {
    background-color: var(--border-color);
    color: var(--text-primary);
}

.unified-tab-content {
    min-height: 500px;
    padding: var(--spacing-lg);
}

.insert-image-button {
    margin-left: auto;
    background-color: var(--primary-color-light);
    color: var(--primary-color);
    border: 1px solid var(--primary-color);
}

.insert-image-button:hover:not(:disabled) {
    background-color: var(--primary-color);
    color: var(--light-text);
}

.insert-image-button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

/* Paste Instructions Styles */
.paste-instructions {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    padding: var(--spacing-xxl);
    color: var(--text-primary);
}

.paste-icon {
    font-size: 4rem;
    margin-bottom: var(--spacing-lg);
}

.paste-instructions h4 {
    margin: 0 0 var(--spacing-md) 0;
    color: var(--text-primary);
    font-size: 1.5rem;
    font-weight: 600;
}

.paste-instructions p {
    margin: 0 0 var(--spacing-lg) 0;
    color: var(--text-secondary);
    font-size: 1rem;
    line-height: 1.6;
    max-width: 500px;
}

.paste-instructions kbd {
    background-color: var(--light-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-sm);
    padding: var(--spacing-xs) var(--spacing-sm);
    font-size: 0.875rem;
    font-family: monospace;
    color: var(--text-primary);
}

.paste-tips {
    background-color: var(--light-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    padding: var(--spacing-lg);
    max-width: 400px;
    text-align: left;
}

.paste-tips h5 {
    margin: 0 0 var(--spacing-sm) 0;
    color: var(--text-primary);
    font-size: 1rem;
    font-weight: 600;
}

.paste-tips ul {
    margin: 0;
    padding-left: var(--spacing-lg);
    color: var(--text-secondary);
}

.paste-tips li {
    margin-bottom: var(--spacing-xs);
    font-size: 0.875rem;
}

@media (max-width: 768px) {
    .image-selection-buttons {
        flex-direction: column;
    }

    .select-image-button,
    .upload-image-button {
        min-width: 100%;
    }

    .image-modal-overlay {
        padding: var(--spacing-md);
    }

    .image-modal-content {
        max-width: 100%;
    }

    .image-modal-body {
        padding: var(--spacing-md);
    }

    .paste-image-actions {
        flex-direction: column;
    }

    .preview-image {
        max-height: 200px;
    }
}
</style>
