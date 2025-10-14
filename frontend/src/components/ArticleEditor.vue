<template>
  <div class="modal-overlay" v-if="isVisible" @click="handleOverlayClick">
    <div class="editor-container" @click.stop>
      <div class="editor-header">
        <h2>{{ article ? 'Edit Article' : 'Create New Article' }}</h2>
        <button @click="$emit('close')" class="close-button">✕</button>
      </div>

      <form @submit.prevent="handleSave" class="editor-form">
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
            />
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
            />
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
          ></textarea>
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
              ✏️ Write
            </button>
            <button
              type="button"
              class="tab-button"
              :class="{ active: activeTab === 'preview' }"
              @click="activeTab = 'preview'"
            >
              👁️ Preview
            </button>
          </div>

          <div class="editor-content">
            <textarea
              v-show="activeTab === 'write'"
              id="content"
              v-model="form.content"
              required
              :disabled="isSaving"
              class="content-textarea"
              placeholder="Write your article content in Markdown..."
              rows="20"
              @keydown="handleTabKey"
            ></textarea>

            <div
              v-show="activeTab === 'preview'"
              class="preview-container"
            >
              <MarkdownRenderer
                v-if="form.content"
                :content="form.content"
                :sanitize="true"
              />
              <div v-else class="empty-preview">
                <p>Nothing to preview yet. Switch to the Write tab and add some content!</p>
              </div>
            </div>
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="tags">Tags</label>
            <div class="tags-input-container">
              <div class="selected-tags">
                <span
                  v-for="tag in selectedTags"
                  :key="tag.id"
                  class="selected-tag"
                >
                  {{ tag.name }}
                  <button
                    type="button"
                    @click="removeTag(tag)"
                    class="remove-tag-button"
                  >
                    ✕
                  </button>
                </span>
              </div>

              <input
                v-model="tagInput"
                type="text"
                :disabled="isSaving"
                class="tag-input"
                placeholder="Add tags..."
                @keydown="handleTagInput"
                @input="searchTags"
              />

              <div v-if="tagSuggestions.length > 0" class="tag-suggestions">
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
            />
          </div>
        </div>

        <div class="form-row">
          <div class="form-group">
            <label for="featured_image">Featured Image URL</label>
            <input
              id="featured_image"
              v-model="form.featured_image"
              type="url"
              :disabled="isSaving"
              class="form-input"
              placeholder="https://example.com/image.jpg"
            />
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
            />
            <small v-if="form.meta_description">
              {{ form.meta_description.length }}/160 characters
            </small>
          </div>
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
              />
              <label for="is_published" class="checkbox-label">
                Publish immediately
              </label>
            </div>

            <div v-if="form.is_published && !article" class="publish-note">
              This article will be published with the current date and time.
            </div>

            <div v-if="article && !article.is_published && form.is_published" class="publish-note">
              This article will be published with the current date and time.
            </div>
          </div>
        </div>

        <div class="form-actions">
          <div class="action-buttons">
            <button
              type="button"
              @click="$emit('close')"
              :disabled="isSaving"
              class="cancel-button"
            >
              Cancel
            </button>

            <button
              type="submit"
              :disabled="isSaving || !isFormValid"
              class="save-button"
            >
              <span v-if="isSaving">{{ article ? 'Updating...' : 'Creating...' }}</span>
              <span v-else>{{ article ? 'Update Article' : 'Create Article' }}</span>
            </button>
          </div>

          <div v-if="error" class="error-message">
            <span class="error-icon">⚠️</span>
            {{ error }}
          </div>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import axios from 'axios'
import MarkdownRenderer from './MarkdownRenderer.vue'

const props = defineProps({
  article: {
    type: Object,
    default: null
  },
  isVisible: {
    type: Boolean,
    default: false
  }
})

const emit = defineEmits(['close', 'saved'])

// Reactive state
const isSaving = ref(false)
const error = ref('')
const activeTab = ref('write')
const tagInput = ref('')
const tagSuggestions = ref([])
const availableTags = ref([])
const selectedTags = ref([])

const form = ref({
  title: '',
  slug: '',
  content: '',
  excerpt: '',
  author: 'Alex Beahm',
  featured_image: '',
  meta_description: '',
  is_published: false
})

// Computed properties
const isFormValid = computed(() => {
  return form.value.title.trim() &&
         form.value.slug.trim() &&
         form.value.content.trim()
})

// Methods
function initializeForm() {
  if (props.article) {
    // Editing existing article
    form.value = {
      title: props.article.title || '',
      slug: props.article.slug || '',
      content: props.article.content || '',
      excerpt: props.article.excerpt || '',
      author: props.article.author || 'Alex Beahm',
      featured_image: props.article.featured_image || '',
      meta_description: props.article.meta_description || '',
      is_published: props.article.is_published || false
    }

    // Set selected tags
    selectedTags.value = props.article.tags ? [...props.article.tags] : []
  } else {
    // Creating new article
    form.value = {
      title: '',
      slug: '',
      content: '',
      excerpt: '',
      author: 'Alex Beahm',
      featured_image: '',
      meta_description: '',
      is_published: false
    }
    selectedTags.value = []
  }
}

function generateSlug() {
  if (!form.value.title || props.article) return // Don't auto-generate slug when editing

  const slug = form.value.title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '') // Remove special characters
    .replace(/\s+/g, '-') // Replace spaces with hyphens
    .replace(/-+/g, '-') // Replace multiple hyphens with single
    .replace(/^-|-$/g, '') // Remove leading/trailing hyphens

  form.value.slug = slug
}

async function loadTags() {
  try {
    const response = await axios.get('/api/tags')
    if (response.data.success) {
      availableTags.value = response.data.tags || []
    }
  } catch (err) {
    console.error('Error loading tags:', err)
  }
}

function searchTags() {
  if (!tagInput.value.trim()) {
    tagSuggestions.value = []
    return
  }

  const query = tagInput.value.toLowerCase()
  tagSuggestions.value = availableTags.value
    .filter(tag =>
      tag.name.toLowerCase().includes(query) &&
      !selectedTags.value.some(selected => selected.id === tag.id)
    )
    .slice(0, 5) // Limit to 5 suggestions
}

function addTag(tag) {
  if (!selectedTags.value.some(t => t.id === tag.id)) {
    selectedTags.value.push(tag)
  }
  tagInput.value = ''
  tagSuggestions.value = []
}

function removeTag(tagToRemove) {
  selectedTags.value = selectedTags.value.filter(tag => tag.id !== tagToRemove.id)
}

function handleTagInput(event) {
  if (event.key === 'Enter' && tagInput.value.trim()) {
    event.preventDefault()

    const tagName = tagInput.value.trim()

    // Check if tag already exists
    const existingTag = availableTags.value.find(
      tag => tag.name.toLowerCase() === tagName.toLowerCase()
    )

    if (existingTag) {
      addTag(existingTag)
    } else {
      // Create a temporary tag object (will be created on server when saving)
      const tempTag = {
        id: `temp-${Date.now()}`,
        name: tagName,
        slug: tagName.toLowerCase().replace(/\s+/g, '-'),
        usage_count: 0
      }
      selectedTags.value.push(tempTag)
      tagInput.value = ''
      tagSuggestions.value = []
    }
  } else if (event.key === 'Escape') {
    tagSuggestions.value = []
  }
}

function handleTabKey(event) {
  if (event.key === 'Tab') {
    event.preventDefault()
    const textarea = event.target
    const start = textarea.selectionStart
    const end = textarea.selectionEnd

    // Insert tab character
    form.value.content = form.value.content.substring(0, start) +
                        '\t' +
                        form.value.content.substring(end)

    // Move cursor to after the inserted tab
    textarea.selectionStart = textarea.selectionEnd = start + 1
  }
}

async function handleSave() {
  if (!isFormValid.value) return

  isSaving.value = true
  error.value = ''

  try {
    // Prepare article data
    const articleData = {
      ...form.value,
      tags: selectedTags.value.map(tag => tag.name) // Send tag names, not objects
    }

    let response
    if (props.article) {
      // Update existing article
      response = await axios.put(`/api/admin/articles/${props.article.id}`, articleData)
    } else {
      // Create new article
      response = await axios.post('/api/admin/articles', articleData)
    }

    if (response.data.success) {
      emit('saved', response.data.article)
    } else {
      throw new Error(response.data.error || 'Failed to save article')
    }
  } catch (err) {
    console.error('Error saving article:', err)
    error.value = err.response?.data?.error || err.message || 'Failed to save article'
  } finally {
    isSaving.value = false
  }
}

function handleOverlayClick() {
  if (!isSaving.value) {
    emit('close')
  }
}

// Watchers
watch(() => props.isVisible, (newValue) => {
  if (newValue) {
    initializeForm()
    loadTags()
    activeTab.value = 'write'
    error.value = ''
  }
})

// Lifecycle
onMounted(() => {
  if (props.isVisible) {
    initializeForm()
    loadTags()
  }
})
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2000;
  overflow-y: auto;
  padding: var(--spacing-lg);
}

.editor-container {
  background-color: var(--card-bg);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-xl);
  width: 100%;
  max-width: 1000px;
  max-height: 90vh;
  overflow-y: auto;
  border: 1px solid var(--border-color);
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
  background-color: var(--bg-color);
  color: var(--text-primary);
  transition: all var(--transition-fast);
  font-family: inherit;
}

.form-input:focus,
.form-textarea:focus {
  outline: none;
  border-color: var(--primary-color);
  box-shadow: 0 0 0 3px var(--primary-color-light);
}

.form-input:disabled,
.form-textarea:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.form-textarea {
  resize: vertical;
  min-height: 80px;
}

/* Editor Tabs */
.editor-tabs {
  display: flex;
  margin-bottom: var(--spacing-sm);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-md) var(--radius-md) 0 0;
  overflow: hidden;
}

.tab-button {
  flex: 1;
  padding: var(--spacing-sm) var(--spacing-md);
  border: none;
  background-color: var(--light-bg);
  color: var(--text-secondary);
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  transition: all var(--transition-fast);
}

.tab-button.active {
  background-color: var(--primary-color);
  color: white;
}

.tab-button:not(.active):hover {
  background-color: var(--border-color);
  color: var(--text-primary);
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
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
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
  color: white;
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
  color: white;
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
</style>