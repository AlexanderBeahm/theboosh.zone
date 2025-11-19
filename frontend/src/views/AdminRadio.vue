<template>
  <div class="admin-radio-page">
    <div class="page-header">
      <h1>Radio Configuration</h1>
      <p class="page-description">
        Configure the radio streaming playlist for your visitors
      </p>
    </div>

    <div class="config-section">
      <!-- Current Configuration Display -->
      <div
        v-if="currentPlaylistUrl && !isEditing"
        class="current-config-card"
      >
        <h2>Current Playlist</h2>
        <div class="config-display">
          <div class="config-label">Playlist URL:</div>
          <div class="config-value">{{ currentPlaylistUrl }}</div>
        </div>
        <button
          class="btn-edit"
          @click="startEditing"
        >
          Update Playlist URL
        </button>
      </div>

      <!-- Configuration Form -->
      <div
        v-if="!currentPlaylistUrl || isEditing"
        class="config-form-card"
      >
        <h2>{{ currentPlaylistUrl ? 'Update' : 'Set' }} Playlist URL</h2>

        <form @submit.prevent="savePlaylistUrl">
          <div class="form-group">
            <label for="playlist-url">Playlist URL</label>
            <input
              id="playlist-url"
              v-model="playlistUrl"
              type="text"
              placeholder="https://example.com/playlist.m3u or /uploads/playlist.m3u"
              required
              :disabled="isSaving"
            >
            <p class="help-text">
              Enter a URL to a .m3u or .m3u8 playlist file. Can be an HTTP(S) URL or a local path starting with /.
            </p>
          </div>

          <div
            v-if="error"
            class="error-message"
          >
            {{ error }}
          </div>

          <div class="form-actions">
            <button
              v-if="isEditing"
              type="button"
              class="btn-secondary"
              :disabled="isSaving"
              @click="cancelEditing"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="btn-primary"
              :disabled="isSaving || !playlistUrl"
            >
              {{ isSaving ? 'Saving...' : 'Save Playlist URL' }}
            </button>
          </div>
        </form>
      </div>

      <!-- Playlist Preview (if parse is successful) -->
      <div
        v-if="previewTracks.length > 0"
        class="preview-card"
      >
        <h2>Playlist Preview</h2>
        <div class="tracks-list">
          <div
            v-for="(track, index) in previewTracks"
            :key="index"
            class="track-item"
          >
            <div class="track-number">{{ index + 1 }}</div>
            <div class="track-info">
              <div class="track-title">{{ track.title }}</div>
              <div class="track-artist">{{ track.artist }}</div>
            </div>
            <div
              v-if="track.duration > 0"
              class="track-duration"
            >
              {{ formatDuration(track.duration) }}
            </div>
          </div>
        </div>
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
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import axios from 'axios';
import { useAuth } from '../composables/useAuth';
import { useCSRF } from '../composables/useCSRF';

const router = useRouter();
const { requireAuth } = useAuth();
const { getToken } = useCSRF();

// Protect this page - redirect if not authenticated
requireAuth(router);

// State
const currentPlaylistUrl = ref('');
const playlistUrl = ref('');
const isEditing = ref(false);
const isSaving = ref(false);
const error = ref('');
const showSuccessToast = ref(false);
const successMessage = ref('');
const previewTracks = ref([]);

// Methods
async function loadCurrentConfig() {
    try {
        const response = await axios.get('/api/admin/radio/config');

        if (response.data.success && response.data.config) {
            const playlistConfig = response.data.config.find(
                c => c.config_key === 'playlist_url'
            );

            if (playlistConfig) {
                currentPlaylistUrl.value = playlistConfig.config_value;

                // Try to load preview
                if (currentPlaylistUrl.value) {
                    loadPlaylistPreview();
                }
            }
        }
    } catch (err) {
        console.error('Failed to load radio configuration:', err);
        error.value = 'Failed to load current configuration';
    }
}

async function loadPlaylistPreview() {
    try {
        const response = await axios.get('/api/radio/playlist', {
            params: { parse: 1 }
        });

        if (response.data.success && response.data.playlist.tracks) {
            previewTracks.value = response.data.playlist.tracks.slice(0, 10); // Show first 10 tracks
        }
    } catch (err) {
        console.error('Failed to load playlist preview:', err);
        // Don't show error to user - preview is optional
    }
}

function startEditing() {
    playlistUrl.value = currentPlaylistUrl.value;
    isEditing.value = true;
    error.value = '';
}

function cancelEditing() {
    isEditing.value = false;
    playlistUrl.value = '';
    error.value = '';
}

async function savePlaylistUrl() {
    if (!playlistUrl.value || isSaving.value) return;

    isSaving.value = true;
    error.value = '';

    try {
        const csrfToken = await getToken();

        const response = await axios.post(
            '/api/admin/radio/playlist',
            { playlist_url: playlistUrl.value },
            {
                headers: {
                    'X-CSRF-Token': csrfToken
                }
            }
        );

        if (response.data.success) {
            currentPlaylistUrl.value = playlistUrl.value;
            isEditing.value = false;
            playlistUrl.value = '';

            successMessage.value = 'Playlist URL updated successfully!';
            showSuccessToast.value = true;

            setTimeout(() => {
                showSuccessToast.value = false;
            }, 3000);

            // Reload preview
            loadPlaylistPreview();
        }
    } catch (err) {
        console.error('Failed to save playlist URL:', err);

        if (err.response?.data?.error) {
            error.value = err.response.data.error;
        } else {
            error.value = 'Failed to save playlist URL. Please try again.';
        }
    } finally {
        isSaving.value = false;
    }
}

function formatDuration(seconds) {
    if (seconds < 0) return '';

    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
}

// Lifecycle
onMounted(() => {
    loadCurrentConfig();
});
</script>

<style scoped>
.admin-radio-page {
    max-width: 900px;
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
}

.config-section {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-lg);
}

.current-config-card,
.config-form-card,
.preview-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    transition: all var(--transition-fast);
}

.current-config-card:hover,
.config-form-card:hover,
.preview-card:hover {
    border-color: var(--primary-color);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.2);
}

h2 {
    font-size: 1.5rem;
    color: var(--primary-color);
    margin-bottom: var(--spacing-md);
}

.config-display {
    background: var(--darker-bg);
    padding: var(--spacing-md);
    border-radius: var(--radius-md);
    margin-bottom: var(--spacing-md);
}

.config-label {
    font-size: 0.875rem;
    color: var(--text-secondary);
    margin-bottom: var(--spacing-xs);
}

.config-value {
    font-family: 'Courier New', monospace;
    color: var(--primary-color);
    word-break: break-all;
}

.form-group {
    margin-bottom: var(--spacing-lg);
}

.form-group label {
    display: block;
    font-weight: 600;
    margin-bottom: var(--spacing-sm);
    color: var(--text-primary);
}

.form-group input[type="text"] {
    width: 100%;
    padding: var(--spacing-md);
    background: var(--darker-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    color: var(--text-primary);
    font-size: 1rem;
    transition: all var(--transition-fast);
}

.form-group input[type="text"]:focus {
    outline: none;
    border-color: var(--primary-color);
    box-shadow: 0 0 10px rgba(255, 105, 180, 0.3);
}

.form-group input[type="text"]:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.help-text {
    font-size: 0.875rem;
    color: var(--text-secondary);
    margin-top: var(--spacing-xs);
}

.error-message {
    background: var(--error-bg);
    border: 1px solid var(--error-border);
    color: var(--error-text);
    padding: var(--spacing-md);
    border-radius: var(--radius-md);
    margin-bottom: var(--spacing-md);
}

.form-actions {
    display: flex;
    gap: var(--spacing-md);
    justify-content: flex-end;
}

.btn-primary,
.btn-secondary,
.btn-edit {
    padding: var(--spacing-md) var(--spacing-lg);
    border-radius: var(--radius-md);
    font-weight: 600;
    font-size: 1rem;
    cursor: pointer;
    transition: all var(--transition-fast);
    border: none;
}

.btn-primary {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border: 1px solid var(--primary-color);
}

.btn-primary:hover:not(:disabled) {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.5);
}

.btn-primary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.btn-secondary {
    background: var(--card-bg);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
}

.btn-secondary:hover:not(:disabled) {
    border-color: var(--primary-color);
}

.btn-edit {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    border: 1px solid var(--primary-color);
    width: 100%;
}

.btn-edit:hover {
    transform: translateY(-2px);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.5);
}

.tracks-list {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-sm);
}

.track-item {
    display: flex;
    align-items: center;
    gap: var(--spacing-md);
    padding: var(--spacing-md);
    background: var(--darker-bg);
    border-radius: var(--radius-md);
    transition: all var(--transition-fast);
}

.track-item:hover {
    background: var(--light-bg);
    transform: translateX(4px);
}

.track-number {
    font-size: 0.875rem;
    color: var(--text-secondary);
    min-width: 2rem;
    text-align: center;
}

.track-info {
    flex: 1;
}

.track-title {
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: 0.25rem;
}

.track-artist {
    font-size: 0.875rem;
    color: var(--text-secondary);
}

.track-duration {
    font-size: 0.875rem;
    color: var(--chrome-silver);
    font-family: 'Courier New', monospace;
}

.success-toast {
    position: fixed;
    bottom: var(--spacing-xl);
    right: var(--spacing-xl);
    background: var(--success-bg);
    color: var(--success-text);
    padding: var(--spacing-md) var(--spacing-lg);
    border-radius: var(--radius-md);
    border: 1px solid var(--primary-color);
    box-shadow: 0 4px 12px rgba(255, 105, 180, 0.3);
    z-index: 1000;
    font-weight: 600;
}

.toast-enter-active,
.toast-leave-active {
    transition: all 0.3s ease;
}

.toast-enter-from {
    opacity: 0;
    transform: translateY(20px);
}

.toast-leave-to {
    opacity: 0;
    transform: translateY(-20px);
}

@media (max-width: 768px) {
    .admin-radio-page {
        padding: var(--spacing-md);
    }

    .page-header h1 {
        font-size: 2rem;
    }

    .form-actions {
        flex-direction: column;
    }

    .btn-primary,
    .btn-secondary {
        width: 100%;
    }

    .success-toast {
        bottom: var(--spacing-md);
        right: var(--spacing-md);
        left: var(--spacing-md);
    }
}
</style>
