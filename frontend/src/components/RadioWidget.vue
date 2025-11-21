<template>
  <Teleport to="body">
    <div
      v-if="!isOnVisualizerPage"
      class="radio-widget"
      :class="{
        'is-minimized': widgetState.isMinimized,
        'is-dragging': isDragging,
        'is-mobile': isMobile,
      }"
      :style="
        !isMobile
          ? {
            left: position.x + 'px',
            top: position.y + 'px',
          }
          : {}
      "
      @mousedown="!isMobile ? startDrag : null"
    >
      <!-- Widget Header -->
      <div class="widget-header">
        <div class="widget-title">
          <svg
            class="radio-icon"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              d="M16.24 7.76a6 6 0 0 1 0 8.49m-8.48-.01a6 6 0 0 1 0-8.49m11.31-2.82a10 10 0 0 1 0 14.14m-14.14 0a10 10 0 0 1 0-14.14M12 12h.01"
            />
          </svg>
          <span>Radio</span>
        </div>
        <div class="widget-controls">
          <button
            class="widget-btn"
            :title="
              widgetState.isMinimized ? 'Maximize' : 'Minimize'
            "
            @click.stop="toggleMinimize"
          >
            <svg
              v-if="widgetState.isMinimized"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <polyline points="15 3 21 3 21 9" />
              <polyline points="9 21 3 21 3 15" />
              <line
                x1="21"
                y1="3"
                x2="14"
                y2="10"
              />
              <line
                x1="3"
                y1="21"
                x2="10"
                y2="14"
              />
            </svg>
            <svg
              v-else
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
            >
              <polyline points="4 14 10 14 10 20" />
              <polyline points="20 10 14 10 14 4" />
              <line
                x1="14"
                y1="10"
                x2="21"
                y2="3"
              />
              <line
                x1="3"
                y1="21"
                x2="10"
                y2="14"
              />
            </svg>
          </button>
        </div>
      </div>

      <!-- Widget Body (shows when not minimized) -->
      <Transition name="expand">
        <div
          v-if="!widgetState.isMinimized"
          class="widget-body"
        >
          <!-- Track Info -->
          <div
            v-if="player.isLoading.value"
            class="track-info"
          >
            <div class="loading-state">
              <div class="spinner-small" />
              <span class="loading-text">Buffering...</span>
            </div>
          </div>
          <div
            v-else-if="player.currentTrack.value"
            class="track-info"
          >
            <div class="track-title">
              {{ player.currentTrack.value.title }}
            </div>
            <div class="track-artist">
              {{ player.currentTrack.value.artist }}
            </div>
          </div>
          <div
            v-else-if="player.error.value"
            class="track-info"
          >
            <div class="error-text">
              {{ player.error.value }}
            </div>
          </div>
          <div
            v-else
            class="track-info"
          >
            <div class="no-track">
              No radio configured
            </div>
          </div>

          <!-- Progress Bar -->
          <div
            v-if="
              player.currentTrack.value &&
                player.duration.value > 0
            "
            class="progress-bar"
          >
            <div
              class="progress-fill"
              :style="{ width: player.progress.value + '%' }"
            />
          </div>

          <!-- Controls -->
          <div class="widget-player-controls">
            <!-- Listen Live Button (shown when not playing) -->
            <button
              v-if="!player.isPlaying.value"
              class="play-btn large listen-live"
              :disabled="
                player.isLoading.value ||
                  !player.currentTrack.value
              "
              @click.stop="handleListenLive"
            >
              <div
                v-if="player.isLoading.value"
                class="spinner-small"
              />
              <svg
                v-else
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <polygon points="5 3 19 12 5 21 5 3" />
              </svg>
            </button>

            <!-- Pause Button (shown when playing) -->
            <button
              v-else
              class="play-btn large"
              @click.stop="player.pause"
            >
              <svg
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <rect
                  x="6"
                  y="4"
                  width="4"
                  height="16"
                />
                <rect
                  x="14"
                  y="4"
                  width="4"
                  height="16"
                />
              </svg>
            </button>

            <!-- Mute Toggle (next to play/pause) -->
            <button
              class="mute-btn"
              :title="
                player.volume.value === 0 ? 'Unmute' : 'Mute'
              "
              @click.stop="handleMuteToggle"
            >
              <svg
                v-if="player.volume.value === 0"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <polygon
                  points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"
                />
                <line
                  x1="23"
                  y1="9"
                  x2="17"
                  y2="15"
                />
                <line
                  x1="17"
                  y1="9"
                  x2="23"
                  y2="15"
                />
              </svg>
              <svg
                v-else-if="player.volume.value < 50"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <polygon
                  points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"
                />
                <path d="M15.54 8.46a5 5 0 0 1 0 7.07" />
              </svg>
              <svg
                v-else
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <polygon
                  points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"
                />
                <path
                  d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07"
                />
              </svg>
            </button>

            <!-- Volume Slider -->
            <input
              type="range"
              class="volume-slider"
              min="0"
              max="100"
              :value="player.volume.value"
              @input="
                (e) => player.setVolume(Number(e.target.value))
              "
              @click.stop
            >

            <!-- Playlist Toggle -->
            <button
              class="playlist-btn"
              :title="
                showPlaylist ? 'Hide Playlist' : 'Show Playlist'
              "
              @click.stop="showPlaylist = !showPlaylist"
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <line
                  x1="8"
                  y1="6"
                  x2="21"
                  y2="6"
                />
                <line
                  x1="8"
                  y1="12"
                  x2="21"
                  y2="12"
                />
                <line
                  x1="8"
                  y1="18"
                  x2="21"
                  y2="18"
                />
                <line
                  x1="3"
                  y1="6"
                  x2="3.01"
                  y2="6"
                />
                <line
                  x1="3"
                  y1="12"
                  x2="3.01"
                  y2="12"
                />
                <line
                  x1="3"
                  y1="18"
                  x2="3.01"
                  y2="18"
                />
              </svg>
            </button>
          </div>
        </div>
      </Transition>

      <!-- Playlist Panel -->
      <Transition name="playlist">
        <div
          v-if="showPlaylist && !widgetState.isMinimized"
          class="widget-playlist-panel"
          @click.stop
        >
          <div class="playlist-header">
            <h3>Playlist</h3>
            <button
              class="close-btn"
              @click="showPlaylist = false"
            >
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <line
                  x1="18"
                  y1="6"
                  x2="6"
                  y2="18"
                />
                <line
                  x1="6"
                  y1="6"
                  x2="18"
                  y2="18"
                />
              </svg>
            </button>
          </div>
          <div class="playlist-content">
            <div
              v-if="player.playlist.length === 0"
              class="empty-playlist"
            >
              No tracks in playlist
            </div>
            <div
              v-else
              class="playlist-tracks"
            >
              <div
                v-for="(track, index) in player.playlist.value"
                :key="index"
                class="playlist-track"
                :class="{
                  active: index === player.currentIndex.value,
                }"
                @click="loadTrack(index)"
              >
                <div class="track-number">
                  {{ index + 1 }}
                </div>
                <div class="track-details">
                  <div class="playlist-track-title">
                    {{ track.title }}
                  </div>
                  <div class="playlist-track-artist">
                    {{ track.artist }}
                  </div>
                </div>
                <div
                  v-if="track.duration > 0"
                  class="track-duration"
                >
                  {{ formatTime(track.duration) }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </div>
  </Teleport>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from "vue";
import { useRoute } from "vue-router";
import { useRadioStore } from "@/composables/useRadioStore";
import { useDraggable } from "@/composables/useDraggable";

const route = useRoute();
const {
    player,
    widgetState,
    setWidgetPosition,
    toggleMinimize,
    restoreUserVolume,
} = useRadioStore();

// Local state
const showPlaylist = ref(false);
const isMobile = ref(false);

// Check if device is mobile
function checkMobile() {
    isMobile.value = window.innerWidth <= 768;
}

// Draggable behavior
const { position, isDragging, startDrag, setPosition } = useDraggable({
    initialX: widgetState.position.x,
    initialY: widgetState.position.y,
    onDragEnd: (x, y) => {
        setWidgetPosition(x, y);
    },
});

// Check if we're on the visualizer page
const isOnVisualizerPage = computed(() => route.path === "/visualizer");

// Watch for widget position changes from store (on mount)
watch(
    () => widgetState.position,
    (newPos) => {
        setPosition(newPos.x, newPos.y);
    },
    { immediate: true },
);

// Format time helper
function formatTime(seconds) {
    if (!seconds || seconds < 0) return "--:--";
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
}

// Handle Listen Live button - first time user clicks to start radio
function handleListenLive() {
    // Restore user's saved volume and mark as listened
    // This will update userState.hasListened reactively
    restoreUserVolume();

    // Start playback if not already playing
    if (!player.isPlaying.value) {
        player.play().catch(() => {
            // Ignore play errors - user can try again
        });
    }
}

// Handle mute toggle - toggle between muted and unmuted
function handleMuteToggle() {
    if (player.volume.value === 0) {
        // Unmute - restore to saved volume
        const saved = localStorage.getItem("radio_saved_volume");
        const volumeToRestore = saved ? parseInt(saved, 10) : 70;
        player.setVolume(volumeToRestore);
    } else {
        // Mute
        player.setVolume(0);
    }
}

// Load a specific track
async function loadTrack(index) {
    await player.loadTrack(index);
    if (player.isPlaying.value) {
        await player.play();
    }
}

// Handle keyboard shortcuts
function handleKeyPress(event) {
    // Only handle if not typing in an input
    if (
        event.target.tagName === "INPUT" ||
        event.target.tagName === "TEXTAREA"
    ) {
        return;
    }

    switch (event.key.toLowerCase()) {
        case "arrowup":
            event.preventDefault();
            player.setVolume(Math.min(100, player.volume.value + 5));
            break;
        case "arrowdown":
            event.preventDefault();
            player.setVolume(Math.max(0, player.volume.value - 5));
            break;
        case "m":
            event.preventDefault();
            player.toggleMute();
            break;
    }
}

// Setup keyboard shortcuts and mobile detection
onMounted(() => {
    checkMobile();
    window.addEventListener("resize", checkMobile);
    document.addEventListener("keydown", handleKeyPress);
});

onUnmounted(() => {
    window.removeEventListener("resize", checkMobile);
    document.removeEventListener("keydown", handleKeyPress);
});
</script>

<style scoped>
.radio-widget {
    position: fixed;
    z-index: 10000;
    width: 320px;
    background: var(--bg-color, #1f2527);
    border: 2px solid var(--primary-color, #ff69b4);
    border-radius: var(--radius-lg, 12px);
    box-shadow:
        0 10px 40px rgba(255, 105, 180, 0.3),
        0 0 20px rgba(255, 105, 180, 0.2);
    overflow: visible;
    user-select: none;
    transition: box-shadow 0.2s ease;
}

.radio-widget.is-dragging {
    box-shadow:
        0 20px 60px rgba(255, 105, 180, 0.5),
        0 0 40px rgba(255, 105, 180, 0.4);
    cursor: grabbing;
}

.radio-widget.is-minimized {
    width: auto;
}

.widget-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    background: linear-gradient(
        135deg,
        rgba(255, 105, 180, 0.1),
        rgba(184, 188, 200, 0.1)
    );
    border-bottom: 1px solid rgba(255, 105, 180, 0.3);
    cursor: grab;
}

.radio-widget.is-dragging .widget-header {
    cursor: grabbing;
}

.widget-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 600;
    color: var(--primary-color, #ff69b4);
    font-size: 14px;
}

.radio-icon {
    width: 18px;
    height: 18px;
}

.widget-controls {
    display: flex;
    gap: 4px;
}

.widget-btn {
    width: 24px;
    height: 24px;
    padding: 4px;
    background: transparent;
    border: none;
    color: var(--chrome-silver, #b8bcc8);
    cursor: pointer;
    border-radius: var(--radius-sm, 4px);
    transition: all 0.2s ease;
    display: flex;
    align-items: center;
    justify-content: center;
}

.widget-btn:hover {
    background: rgba(255, 105, 180, 0.1);
    color: var(--primary-color, #ff69b4);
}

.widget-btn svg {
    width: 100%;
    height: 100%;
}

.widget-body {
    padding: 16px;
}

.track-info {
    margin-bottom: 12px;
    min-height: 48px;
}

.track-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--primary-color, #ff69b4);
    margin-bottom: 4px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.track-artist {
    font-size: 12px;
    color: var(--chrome-silver, #b8bcc8);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.error-text {
    font-size: 12px;
    color: #ff6b6b;
}

.no-track {
    font-size: 12px;
    color: var(--chrome-silver, #b8bcc8);
    font-style: italic;
}

.loading-state {
    display: flex;
    align-items: center;
    gap: 12px;
}

.loading-text {
    font-size: 12px;
    color: var(--chrome-silver, #b8bcc8);
    animation: pulse 1.5s ease-in-out infinite;
}

.progress-bar {
    width: 100%;
    height: 4px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 2px;
    overflow: hidden;
    margin-bottom: 12px;
}

.progress-fill {
    height: 100%;
    background: linear-gradient(
        90deg,
        var(--primary-color, #ff69b4),
        var(--chrome-silver, #b8bcc8)
    );
    border-radius: 2px;
    transition: width 0.1s linear;
}

.widget-player-controls {
    display: flex;
    align-items: center;
    gap: 12px;
}

.play-btn {
    width: 40px;
    height: 40px;
    border: none;
    border-radius: 50%;
    background: linear-gradient(135deg, var(--primary-color, #ff69b4), #ff1493);
    color: white;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
    flex-shrink: 0;
}

.play-btn:hover:not(:disabled) {
    transform: scale(1.05);
    box-shadow: 0 4px 12px rgba(255, 105, 180, 0.4);
}

.play-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.play-btn svg {
    width: 18px;
    height: 18px;
}

.mute-btn {
    width: 40px;
    height: 40px;
    border: 1px solid rgba(255, 105, 180, 0.3);
    border-radius: 50%;
    background: transparent;
    color: var(--chrome-silver, #b8bcc8);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
    flex-shrink: 0;
}

.mute-btn:hover {
    border-color: var(--primary-color, #ff69b4);
    color: var(--primary-color, #ff69b4);
    background: rgba(255, 105, 180, 0.1);
}

.mute-btn svg {
    width: 20px;
    height: 20px;
}

.spinner-small {
    width: 20px;
    height: 20px;
    border: 2px solid rgba(255, 105, 180, 0.2);
    border-top-color: var(--primary-color, #ff69b4);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    flex-shrink: 0;
}

.play-btn .spinner-small {
    border: 2px solid rgba(255, 255, 255, 0.3);
    border-top-color: white;
}

@keyframes spin {
    to {
        transform: rotate(360deg);
    }
}

@keyframes pulse {
    0%,
    100% {
        opacity: 1;
    }
    50% {
        opacity: 0.5;
    }
}

.volume-slider {
    flex: 1;
    height: 4px;
    border-radius: 2px;
    background: rgba(255, 255, 255, 0.1);
    outline: none;
    -webkit-appearance: none;
    appearance: none;
}

.volume-slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: var(--primary-color, #ff69b4);
    cursor: pointer;
    transition: all 0.2s ease;
}

.volume-slider::-webkit-slider-thumb:hover {
    transform: scale(1.2);
}

.volume-slider::-moz-range-thumb {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    background: var(--primary-color, #ff69b4);
    cursor: pointer;
    border: none;
    transition: all 0.2s ease;
}

.volume-slider::-moz-range-thumb:hover {
    transform: scale(1.2);
}

.playlist-btn {
    width: 32px;
    height: 32px;
    padding: 6px;
    background: transparent;
    border: 1px solid rgba(255, 105, 180, 0.3);
    border-radius: var(--radius-sm, 4px);
    color: var(--chrome-silver, #b8bcc8);
    cursor: pointer;
    transition: all 0.2s ease;
    flex-shrink: 0;
}

.playlist-btn:hover {
    border-color: var(--primary-color, #ff69b4);
    color: var(--primary-color, #ff69b4);
}

/* Playlist Panel */
.widget-playlist-panel {
    position: absolute;
    bottom: 100%;
    left: 0;
    right: 0;
    margin-bottom: 8px;
    background: var(--bg-color, #1f2527);
    border: 2px solid var(--primary-color, #ff69b4);
    border-radius: var(--radius-lg, 12px);
    max-height: 300px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 10px 40px rgba(255, 105, 180, 0.3);
}

.playlist-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid rgba(255, 105, 180, 0.3);
    background: linear-gradient(
        135deg,
        rgba(255, 105, 180, 0.1),
        rgba(184, 188, 200, 0.1)
    );
}

.playlist-header h3 {
    margin: 0;
    font-size: 14px;
    font-weight: 600;
    color: var(--primary-color, #ff69b4);
}

.close-btn {
    width: 24px;
    height: 24px;
    padding: 4px;
    background: transparent;
    border: none;
    color: var(--chrome-silver, #b8bcc8);
    cursor: pointer;
    border-radius: var(--radius-sm, 4px);
    transition: all 0.2s ease;
}

.close-btn:hover {
    background: rgba(255, 105, 180, 0.1);
    color: var(--primary-color, #ff69b4);
}

.playlist-content {
    overflow-y: auto;
    flex: 1;
}

.empty-playlist {
    padding: 32px 16px;
    text-align: center;
    color: var(--chrome-silver, #b8bcc8);
    font-size: 12px;
}

.playlist-tracks {
    padding: 8px;
}

.playlist-track {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px 12px;
    border-radius: var(--radius-sm, 4px);
    cursor: pointer;
    transition: all 0.2s ease;
}

.playlist-track:hover {
    background: rgba(255, 105, 180, 0.1);
}

.playlist-track.active {
    background: rgba(255, 105, 180, 0.2);
    border-left: 3px solid var(--primary-color, #ff69b4);
}

.track-number {
    font-size: 12px;
    color: var(--chrome-silver, #b8bcc8);
    min-width: 24px;
}

.track-details {
    flex: 1;
    min-width: 0;
}

.playlist-track-title {
    font-size: 12px;
    font-weight: 500;
    color: var(--primary-color, #ff69b4);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.playlist-track-artist {
    font-size: 11px;
    color: var(--chrome-silver, #b8bcc8);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}

.track-duration {
    font-size: 11px;
    color: var(--chrome-silver, #b8bcc8);
}

/* Transitions */
.expand-enter-active,
.expand-leave-active {
    transition: all 0.3s ease;
    overflow: hidden;
}

.expand-enter-from,
.expand-leave-to {
    max-height: 0;
    opacity: 0;
}

.expand-enter-to,
.expand-leave-from {
    max-height: 500px;
    opacity: 1;
}

.playlist-enter-active,
.playlist-leave-active {
    transition: all 0.2s ease;
}

.playlist-enter-from,
.playlist-leave-to {
    opacity: 0;
    transform: translateY(10px);
}

/* Mobile Responsiveness */
@media (max-width: 768px) {
    .radio-widget.is-mobile {
        position: fixed !important;
        bottom: 0 !important;
        left: 0 !important;
        right: 0 !important;
        top: auto !important;
        width: 100% !important;
        border-radius: var(--radius-lg, 12px) var(--radius-lg, 12px) 0 0;
        border-bottom: none;
        z-index: 999;
        max-width: 100%;
    }

    .radio-widget.is-mobile .widget-header {
        cursor: default;
        padding: 10px 16px;
    }

    .radio-widget.is-mobile .widget-body {
        padding: 12px 16px;
    }

    .radio-widget.is-mobile .widget-player-controls {
        gap: 8px;
    }

    .radio-widget.is-mobile .play-btn {
        width: 36px;
        height: 36px;
    }

    .radio-widget.is-mobile .mute-btn {
        width: 36px;
        height: 36px;
    }

    .radio-widget.is-mobile .volume-slider {
        flex: 0.8;
    }

    .radio-widget.is-mobile .widget-playlist-panel {
        max-height: 60vh;
        bottom: 100%;
        margin-bottom: 0;
        border-radius: var(--radius-lg, 12px) var(--radius-lg, 12px) 0 0;
    }

    /* Non-mobile styles (when widget is draggable) */
    .radio-widget:not(.is-mobile) {
        width: 280px;
    }

    .radio-widget:not(.is-mobile) .widget-playlist-panel {
        max-height: 250px;
    }
}
</style>
