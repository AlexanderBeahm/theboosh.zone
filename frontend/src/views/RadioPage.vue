<template>
    <div class="radio-page">
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
                    <h2 class="station-name">TheBoosh Radio</h2>
                    <div v-if="player.currentTrack.value" class="track-info">
                        <div class="track-title">
                            {{ player.currentTrack.value.title }}
                        </div>
                        <div class="track-artist">
                            {{ player.currentTrack.value.artist }}
                        </div>
                    </div>
                    <div v-else-if="player.error.value" class="error-message">
                        {{ player.error.value }}
                    </div>
                    <div v-else class="loading-message">
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
                        <input
                            type="range"
                            min="0"
                            :max="player.duration.value"
                            :value="player.currentTime.value"
                            class="progress-bar"
                            @input="handleSeek"
                        />
                        <div
                            class="progress-fill"
                            :style="{ width: player.progress.value + '%' }"
                        />
                    </div>
                    <div class="time-display">
                        <span>{{ formatTime(player.currentTime.value) }}</span>
                        <span>{{ formatTime(player.duration.value) }}</span>
                    </div>
                </div>

                <!-- Playback Controls -->
                <div class="controls-section">
                    <button
                        class="control-button"
                        :disabled="!player.hasPrevious.value"
                        @click="player.previous"
                    >
                        <svg
                            width="24"
                            height="24"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                        >
                            <path
                                d="M19 20L9 12L19 4V20Z"
                                stroke-width="2"
                                stroke-linecap="round"
                                stroke-linejoin="round"
                            />
                            <line
                                x1="5"
                                y1="19"
                                x2="5"
                                y2="5"
                                stroke-width="2"
                                stroke-linecap="round"
                            />
                        </svg>
                    </button>

                    <button
                        class="control-button play-button"
                        :disabled="!player.currentTrack.value"
                        @click="player.togglePlay"
                    >
                        <svg
                            v-if="!player.isPlaying.value"
                            width="32"
                            height="32"
                            viewBox="0 0 24 24"
                            fill="currentColor"
                        >
                            <path d="M8 5v14l11-7z" />
                        </svg>
                        <svg
                            v-else
                            width="32"
                            height="32"
                            viewBox="0 0 24 24"
                            fill="currentColor"
                        >
                            <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z" />
                        </svg>
                    </button>

                    <button
                        class="control-button"
                        :disabled="!player.hasNext.value"
                        @click="player.next"
                    >
                        <svg
                            width="24"
                            height="24"
                            viewBox="0 0 24 24"
                            fill="none"
                            stroke="currentColor"
                        >
                            <path
                                d="M5 4L15 12L5 20V4Z"
                                stroke-width="2"
                                stroke-linecap="round"
                                stroke-linejoin="round"
                            />
                            <line
                                x1="19"
                                y1="5"
                                x2="19"
                                y2="19"
                                stroke-width="2"
                                stroke-linecap="round"
                            />
                        </svg>
                    </button>
                </div>

                <!-- Volume Control -->
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
                                !player.isMuted.value && player.volume.value > 0
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
                        v-model.number="player.volume.value"
                        type="range"
                        min="0"
                        max="100"
                        class="volume-slider"
                    />
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

            <!-- Playlist Panel -->
            <Transition name="playlist">
                <div v-if="showPlaylist" class="playlist-panel">
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
                            v-if="player.playlist.value.length === 0"
                            class="empty-playlist"
                        >
                            No tracks loaded
                        </div>
                        <div v-else class="playlist-tracks">
                            <div
                                v-for="(track, index) in player.playlist.value"
                                :key="index"
                                class="playlist-track"
                                :class="{
                                    active: index === player.currentIndex.value,
                                }"
                                @click="selectTrack(index)"
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
        <div v-if="player.isLoading.value" class="loading-overlay">
            <div class="spinner" />
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import AudioVisualizer from "../components/AudioVisualizer.vue";
import { useAudioPlayer } from "../composables/useAudioPlayer";

const player = useAudioPlayer();
const showPlaylist = ref(false);

// Format time in MM:SS
function formatTime(seconds) {
    if (!seconds || seconds < 0) return "0:00";

    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, "0")}`;
}

// Handle seek
function handleSeek(event) {
    const time = parseFloat(event.target.value);
    player.seek(time);
}

// Select track from playlist
function selectTrack(index) {
    player.loadTrack(index);
    if (player.isPlaying.value) {
        player.play();
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
        case " ":
            event.preventDefault();
            player.togglePlay();
            break;
        case "ArrowLeft":
            event.preventDefault();
            player.previous();
            break;
        case "ArrowRight":
            event.preventDefault();
            player.next();
            break;
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
onMounted(async () => {
    // Initialize player
    player.init();

    // Load playlist
    await player.loadPlaylist();

    // Add keyboard listener
    window.addEventListener("keydown", handleKeyPress);
});

onUnmounted(() => {
    window.removeEventListener("keydown", handleKeyPress);
    player.cleanup();
});
</script>

<style scoped>
.radio-page {
    position: relative;
    width: 100%;
    min-height: 100vh;
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
    z-index: 10;
    width: 100%;
    height: 100vh;
    display: flex;
    align-items: flex-end;
    justify-content: center;
    padding: var(--spacing-xl);
}

.player-controls {
    background: rgba(42, 47, 49, 0.95);
    border: 1px solid var(--primary-color);
    border-radius: var(--radius-lg);
    padding: var(--spacing-xl);
    box-shadow: 0 0 40px rgba(255, 105, 180, 0.4);
    backdrop-filter: blur(20px);
    min-width: 600px;
    max-width: 800px;
}

.track-info-section {
    text-align: center;
    margin-bottom: var(--spacing-lg);
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

.controls-section {
    display: flex;
    gap: var(--spacing-md);
    justify-content: center;
    align-items: center;
    margin-bottom: var(--spacing-lg);
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
    justify-content: center;
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
    margin-left: var(--spacing-md);
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
    background: var(--light-bg);
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
    top: var(--spacing-xl);
    left: 50%;
    transform: translateX(-50%);
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
}
</style>
