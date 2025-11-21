<template>
  <div class="visualizer-page">
    <!-- Visualizer (full-page background) -->
    <div class="visualizer-container">
      <AudioVisualizer
        :audio-element="player.audio.value"
        :is-playing="player.isPlaying.value"
      />
    </div>

    <!-- Player Controls (overlaid) -->
    <div class="player-overlay">
      <div class="player-controls">
        <!-- Track Info -->
        <div class="track-info-section">
          <h2 class="station-name">
            TheBoosh.Zone Visualizer
          </h2>
          <div
            v-if="player.currentTrack.value"
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
            class="error-message"
          >
            {{ player.error.value }}
          </div>
          <div
            v-else
            class="loading-message"
          >
            Loading playlist...
          </div>
        </div>

        <!-- Progress Bar -->
        <div
          v-if="
            player.currentTrack.value && player.duration.value > 0
          "
          class="progress-section"
        >
          <div class="progress-bar-container">
            <div
              class="progress-fill"
              :style="{ width: player.progress.value + '%' }"
            />
          </div>
        </div>

        <!-- Bottom Controls: Play/Pause, Volume and Playlist -->
        <div class="bottom-controls">
          <!-- Play/Pause Button -->
          <button
            v-if="player.isPlaying.value"
            class="control-button play-pause-button"
            title="Pause"
            @click="player.pause"
          >
            <svg
              width="24"
              height="24"
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
          <button
            v-else
            class="control-button play-pause-button"
            title="Play"
            @click="startListening"
          >
            <svg
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="currentColor"
            >
              <path d="M8 5v14l11-7z" />
            </svg>
          </button>

          <div class="volume-section">
            <button
              class="control-button volume-button"
              @click="player.toggleMute"
            >
              <svg
                v-if="
                  !player.isMuted.value &&
                    player.volume.value > 50
                "
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path
                  d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"
                />
              </svg>
              <svg
                v-else-if="
                  !player.isMuted.value &&
                    player.volume.value > 0
                "
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path
                  d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02z"
                />
              </svg>
              <svg
                v-else
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="currentColor"
              >
                <path
                  d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"
                />
              </svg>
            </button>
            <input
              type="range"
              min="0"
              max="100"
              class="volume-slider"
              :value="player.volume.value"
              @input="
                (e) => player.setVolume(Number(e.target.value))
              "
            >
          </div>

          <!-- Playlist Toggle -->
          <button
            class="control-button playlist-toggle"
            @click="showPlaylist = !showPlaylist"
          >
            <svg
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="currentColor"
            >
              <path
                d="M15 6H3v2h12V6zm0 4H3v2h12v-2zM3 16h8v-2H3v2zM17 6v8.18c-.31-.11-.65-.18-1-.18-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3V8h3V6h-5z"
              />
            </svg>
          </button>
        </div>
      </div>

      <!-- Playlist Panel -->
      <Transition name="playlist">
        <div
          v-if="showPlaylist"
          class="playlist-panel"
        >
          <div class="playlist-header">
            <h3>Playlist</h3>
            <button
              class="close-button"
              @click="showPlaylist = false"
            >
              ✕
            </button>
          </div>
          <div class="playlist-content">
            <div
              v-if="player.playlist.length === 0"
              class="empty-playlist"
            >
              No tracks loaded
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

    <!-- Loading Indicator -->
    <div
      v-if="player.isLoading.value"
      class="loading-overlay"
    >
      <div class="spinner" />
    </div>

    <!-- Click to Listen Live Overlay - shown when not playing -->
    <div
      v-if="!player.isPlaying.value"
      class="listen-live-overlay"
    >
      <div class="listen-live-content">
        <HeroBurst size="large" />
        <h1 class="listen-live-title">
          TheBoosh.Zone Radio
        </h1>
        <p class="listen-live-subtitle">
          Synchronized streaming for all listeners
        </p>
        <button
          class="listen-live-button"
          @click="startListening"
        >
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="currentColor"
          >
            <path d="M8 5v14l11-7z" />
          </svg>
          <span>Click to Listen Live</span>
        </button>
        <p
          v-if="player.error.value"
          class="listen-live-error"
        >
          {{ player.error.value }}
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import AudioVisualizer from "../components/AudioVisualizer.vue";
import HeroBurst from "../components/HeroBurst.vue";
import { useRadioStore } from "../composables/useRadioStore";

// Use shared radio store instead of local player instance
const { player, restoreUserVolume } = useRadioStore();

const showPlaylist = ref(false);

// Format time in MM:SS
function formatTime(seconds) {
    if (!seconds || seconds < 0) return "0:00";

    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
}

// Handle Listen Live - restores volume on first interaction
function startListening() {
    // Restore user's saved volume and mark as listened
    // This will update userState.hasListened reactively
    restoreUserVolume();

    // Ensure playing
    if (!player.isPlaying.value) {
        player.play().catch(() => {
            // Ignore play errors - user can try again
        });
    }
}

// Load a specific track from the playlist
async function loadTrack(index) {
    await player.loadTrack(index);
    if (player.isPlaying.value) {
        await player.play();
    }
}

// Keyboard shortcuts
function handleKeyPress(event) {
    // Ignore if typing in an input
    if (
        event.target.tagName === "INPUT" ||
        event.target.tagName === "TEXTAREA"
    ) {
        return;
    }

    switch (event.key) {
        case "ArrowUp":
            event.preventDefault();
            player.setVolume(Math.min(100, player.volume.value + 5));
            break;
        case "ArrowDown":
            event.preventDefault();
            player.setVolume(Math.max(0, player.volume.value - 5));
            break;
        case "m":
            player.toggleMute();
            break;
        case "p":
            showPlaylist.value = !showPlaylist.value;
            break;
    }
}

// Lifecycle
onMounted(() => {
    // Player is already initialized by the store, no need to init again
    // Add keyboard listener
    window.addEventListener("keydown", handleKeyPress);
});

onUnmounted(() => {
    window.removeEventListener("keydown", handleKeyPress);
    // Don't cleanup player - it's shared globally
});
</script>

<style scoped>
.visualizer-page {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100vh;
    background: var(--bg-color);
    overflow: hidden;
}

.visualizer-container {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
}

.player-overlay {
    position: relative;
    z-index: 1;
    width: 100%;
    height: 100vh;
    display: flex;
    align-items: flex-end;
    justify-content: center;
    padding: var(--spacing-md);
    padding-bottom: var(--spacing-lg);
    box-sizing: border-box;
}

.player-controls {
    background: rgba(42, 47, 49, 0.95);
    border: 1px solid var(--primary-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-lg);
    box-shadow: 0 0 40px rgba(255, 105, 180, 0.4);
    backdrop-filter: blur(20px);
    min-width: 600px;
    max-width: 800px;
}

.track-info-section {
    text-align: center;
    margin-bottom: var(--spacing-md);
}

.station-name {
    font-size: 1.25rem;
    color: var(--chrome-silver);
    margin-bottom: var(--spacing-sm);
    text-transform: uppercase;
    letter-spacing: 0.1em;
}

.track-title {
    font-size: 1.5rem;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 0.25rem;
}

.track-artist {
    font-size: 1.125rem;
    color: var(--text-secondary);
}

.error-message {
    color: var(--error-text);
    font-size: 1rem;
}

.loading-message {
    color: var(--text-secondary);
    font-size: 1rem;
}

.progress-section {
    margin-bottom: var(--spacing-lg);
}

.progress-bar-container {
    position: relative;
    height: 6px;
    background: var(--darker-bg);
    border-radius: var(--radius-full);
    overflow: hidden;
    margin-bottom: var(--spacing-sm);
}

.progress-bar {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    opacity: 0;
    cursor: pointer;
    z-index: 2;
}

.progress-fill {
    position: absolute;
    top: 0;
    left: 0;
    height: 100%;
    background: var(--gradient-retro-primary);
    border-radius: var(--radius-full);
    transition: width 0.1s linear;
    pointer-events: none;
}

.time-display {
    display: flex;
    justify-content: space-between;
    font-size: 0.875rem;
    color: var(--text-secondary);
    font-family: "Courier New", monospace;
}

.bottom-controls {
    display: flex;
    gap: var(--spacing-lg);
    justify-content: space-between;
    align-items: center;
}

.control-button {
    background: var(--card-bg);
    color: var(--text-primary);
    border: 1px solid var(--border-color);
    border-radius: 50%;
    width: 50px;
    height: 50px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all var(--transition-fast);
}

.control-button:hover:not(:disabled) {
    background: var(--gradient-retro-primary);
    border-color: var(--primary-color);
    transform: scale(1.1);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.6);
}

.control-button:disabled {
    opacity: 0.3;
    cursor: not-allowed;
}

.play-button {
    width: 70px;
    height: 70px;
    background: var(--gradient-retro-primary);
    border-color: var(--primary-color);
}

.volume-section {
    display: flex;
    gap: var(--spacing-md);
    align-items: center;
    flex: 1;
}

.volume-button {
    flex-shrink: 0;
}

.volume-slider {
    width: 150px;
    height: 6px;
    background: var(--darker-bg);
    border-radius: var(--radius-full);
    outline: none;
    -webkit-appearance: none;
}

.volume-slider::-webkit-slider-thumb {
    -webkit-appearance: none;
    appearance: none;
    width: 16px;
    height: 16px;
    background: var(--primary-color);
    border-radius: 50%;
    cursor: pointer;
}

.volume-slider::-moz-range-thumb {
    width: 16px;
    height: 16px;
    background: var(--primary-color);
    border-radius: 50%;
    cursor: pointer;
    border: none;
}

.playlist-toggle {
    flex-shrink: 0;
}

.playlist-panel {
    position: fixed;
    top: var(--spacing-xl);
    right: var(--spacing-xl);
    width: 400px;
    max-height: 70vh;
    background: rgba(42, 47, 49, 0.98);
    border: 1px solid var(--primary-color);
    border-radius: var(--radius-lg);
    box-shadow: 0 0 40px rgba(255, 105, 180, 0.4);
    backdrop-filter: blur(20px);
    display: flex;
    flex-direction: column;
    z-index: 20;
}

.playlist-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: var(--spacing-lg);
    border-bottom: 1px solid var(--border-color);
}

.playlist-header h3 {
    margin: 0;
    font-size: 1.25rem;
    color: var(--primary-color);
}

.close-button {
    background: transparent;
    border: none;
    color: var(--text-secondary);
    font-size: 1.5rem;
    cursor: pointer;
    padding: 0;
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all var(--transition-fast);
}

.close-button:hover {
    color: var(--primary-color);
}

.playlist-content {
    flex: 1;
    overflow-y: auto;
    padding: var(--spacing-md);
}

.empty-playlist {
    text-align: center;
    color: var(--text-secondary);
    padding: var(--spacing-xl);
}

.playlist-tracks {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xs);
}

.playlist-track {
    display: flex;
    align-items: center;
    gap: var(--spacing-md);
    padding: var(--spacing-md);
    background: var(--darker-bg);
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: all var(--transition-fast);
}

.playlist-track:hover {
    background: rgba(255, 105, 180, 0.1);
    transform: translateX(4px);
}

.playlist-track.active {
    background: var(--primary-color-dark);
    border: 1px solid var(--primary-color);
}

.track-number {
    font-size: 0.875rem;
    color: var(--text-secondary);
    min-width: 2rem;
    text-align: center;
    font-family: "Courier New", monospace;
}

.track-details {
    flex: 1;
    min-width: 0;
}

.playlist-track-title {
    font-weight: 600;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.playlist-track-artist {
    font-size: 0.875rem;
    color: var(--text-secondary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}

.track-duration {
    font-size: 0.875rem;
    color: var(--chrome-silver);
    font-family: "Courier New", monospace;
}

.loading-overlay {
    position: fixed;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background: rgba(42, 47, 49, 0.95);
    border: 1px solid var(--primary-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-lg);
    z-index: 30;
}

.spinner {
    width: 40px;
    height: 40px;
    border: 3px solid var(--border-color);
    border-top-color: var(--primary-color);
    border-radius: 50%;
    animation: spin 1s linear infinite;
}

@keyframes spin {
    to {
        transform: rotate(360deg);
    }
}

@keyframes textGlow {
    from {
        text-shadow:
            0 0 clamp(15px, 1.5vw, 20px) rgba(184, 188, 200, 0.3),
            0 0 clamp(30px, 3vw, 40px) rgba(255, 105, 180, 0.2);
    }
    to {
        text-shadow:
            0 0 clamp(20px, 2vw, 30px) rgba(184, 188, 200, 0.5),
            0 0 clamp(45px, 4.5vw, 60px) rgba(255, 105, 180, 0.4);
    }
}

.listen-live-overlay {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    z-index: 5;
    display: flex;
    align-items: center;
    justify-content: center;
}

.listen-live-overlay::before {
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(31, 37, 39, 0.98);
    backdrop-filter: blur(20px);
    z-index: -1;
}

.listen-live-content {
    text-align: center;
    padding: var(--spacing-xl);
    max-width: 75%;
    position: relative;
}

.listen-live-title {
    font-size: clamp(2rem, 4vw + 1rem, 3.5rem);
    font-weight: 700;
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    margin-bottom: var(--spacing-md);
    text-transform: uppercase;
    letter-spacing: clamp(0.02em, 0.05em, 0.08em);
    text-shadow: 0 0 clamp(20px, 2vw, 30px) rgba(184, 188, 200, 0.3);
    animation: textGlow 4s ease-in-out infinite alternate;
    position: relative;
    z-index: 2;
    -webkit-text-stroke: clamp(1px, 0.15vw, 2px) black;
}

.listen-live-subtitle {
    font-size: clamp(1rem, 2vw + 0.5rem, 1.125rem);
    color: var(--text-secondary);
    margin-bottom: var(--spacing-xl);
    position: relative;
    z-index: 2;
    line-height: 1.6;
    text-shadow:
        1px 1px 0 #000,
        -1px 1px 0 #000,
        1px -1px 0 #000,
        -1px -1px 0 #000,
        0px 1px 0 #000,
        0px -1px 0 #000,
        -1px 0px 0 #000,
        1px 0px 0 #000,
        2px 2px 0 #000,
        -2px 2px 0 #000,
        2px -2px 0 #000,
        -2px -2px 0 #000,
        0px 2px 0 #000,
        0px -2px 0 #000,
        -2px 0px 0 #000,
        2px 0px 0 #000,
        1px 2px 0 #000,
        -1px 2px 0 #000,
        1px -2px 0 #000,
        -1px -2px 0 #000,
        2px 1px 0 #000,
        -2px 1px 0 #000,
        2px -1px 0 #000,
        -2px -1px 0 #000;
}

.listen-live-button {
    display: inline-flex;
    align-items: center;
    gap: var(--spacing-md);
    background: var(--gradient-retro-primary);
    color: white;
    border: 2px solid var(--primary-color);
    border-radius: var(--radius-full);
    padding: var(--spacing-lg) var(--spacing-xl);
    font-size: 1.25rem;
    font-weight: 600;
    cursor: pointer;
    transition: all var(--transition-base);
    box-shadow: 0 0 30px rgba(255, 105, 180, 0.5);
    position: relative;
    z-index: 2;
}

.listen-live-button:hover {
    transform: scale(1.05);
    box-shadow: 0 0 50px rgba(255, 105, 180, 0.8);
}

.listen-live-button:active {
    transform: scale(0.98);
}

.listen-live-error {
    margin-top: var(--spacing-lg);
    color: var(--error-text);
    font-size: 1rem;
    position: relative;
    z-index: 2;
}

.playlist-enter-active,
.playlist-leave-active {
    transition: all 0.3s ease;
}

.playlist-enter-from {
    opacity: 0;
    transform: translateX(100px);
}

.playlist-leave-to {
    opacity: 0;
    transform: translateX(100px);
}

@media (max-width: 768px) {
    .player-controls {
        min-width: auto;
        width: 100%;
        padding: var(--spacing-md);
    }

    .player-overlay {
        padding: var(--spacing-md);
    }

    .playlist-panel {
        top: var(--spacing-md);
        right: var(--spacing-md);
        left: var(--spacing-md);
        width: auto;
        max-height: 60vh;
    }

    .volume-slider {
        width: 100px;
    }

    .station-name {
        font-size: 1rem;
    }

    .track-title {
        font-size: 1.25rem;
    }

    .track-artist {
        font-size: 1rem;
    }

    /* Splash screen mobile fixes */
    .listen-live-content {
        max-width: 90%;
        padding: var(--spacing-lg);
    }

    .listen-live-title {
        font-size: 2rem;
        letter-spacing: 0.05em;
        margin-bottom: var(--spacing-sm);
    }

    .listen-live-subtitle {
        font-size: 1rem;
        margin-bottom: var(--spacing-lg);
    }

    .listen-live-button {
        padding: var(--spacing-md) var(--spacing-lg);
        font-size: 1.125rem;
        gap: var(--spacing-sm);
    }

    .listen-live-button svg {
        width: 20px;
        height: 20px;
    }
}

/* Small mobile devices */
@media (max-width: 480px) {
    .listen-live-content {
        max-width: 95%;
        padding: var(--spacing-md);
    }

    .listen-live-title {
        font-size: 1.5rem;
        letter-spacing: 0.025em;
        line-height: 1.2;
        margin-bottom: var(--spacing-xs);
    }

    .listen-live-subtitle {
        font-size: 0.875rem;
        margin-bottom: var(--spacing-md);
    }

    .listen-live-button {
        padding: var(--spacing-sm) var(--spacing-md);
        font-size: 1rem;
        gap: var(--spacing-xs);
    }

    .listen-live-button svg {
        width: 18px;
        height: 18px;
    }
}
</style>
