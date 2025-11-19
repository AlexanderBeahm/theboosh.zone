import { ref, computed, onUnmounted, watch } from "vue";
import axios from "axios";
import Hls from "hls.js";

/**
 * Composable for managing audio playback with playlist support
 *
 * Features:
 * - Load and parse M3U playlists
 * - Play/pause/skip controls
 * - Volume control with persistence
 * - Track progress tracking
 * - Auto-advance to next track
 * - Media Session API integration
 */
export function useAudioPlayer() {
    // Audio element
    const audio = ref(null);

    // HLS instance for streaming
    const hls = ref(null);

    // Playlist state
    const playlist = ref([]);
    const currentIndex = ref(0);
    const playlistUrl = ref("");

    // Playback state
    const isPlaying = ref(false);
    const isLoading = ref(false);
    const duration = ref(0);
    const currentTime = ref(0);
    const volume = ref(70); // 0-100
    const isMuted = ref(false);

    // Error state
    const error = ref("");

    // Computed
    const currentTrack = computed(() => {
        if (
            playlist.value.length > 0 &&
            currentIndex.value >= 0 &&
            currentIndex.value < playlist.value.length
        ) {
            return playlist.value[currentIndex.value];
        }
        return null;
    });

    const hasNext = computed(() => {
        return currentIndex.value < playlist.value.length - 1;
    });

    const hasPrevious = computed(() => {
        return currentIndex.value > 0;
    });

    const progress = computed(() => {
        if (duration.value === 0) return 0;
        return (currentTime.value / duration.value) * 100;
    });

    /**
     * Initialize audio element and load saved preferences
     */
    function init() {
        audio.value = new Audio();
        audio.value.crossOrigin = "anonymous"; // Enable CORS for Web Audio API

        // Load saved volume
        const savedVolume = localStorage.getItem("radio_volume");
        if (savedVolume !== null) {
            volume.value = parseInt(savedVolume, 10);
        }
        setVolume(volume.value);

        // Set up event listeners
        audio.value.addEventListener("loadedmetadata", handleLoadedMetadata);
        audio.value.addEventListener("timeupdate", handleTimeUpdate);
        audio.value.addEventListener("ended", handleEnded);
        audio.value.addEventListener("play", handlePlay);
        audio.value.addEventListener("pause", handlePause);
        audio.value.addEventListener("error", handleError);
        audio.value.addEventListener("canplay", handleCanPlay);
        audio.value.addEventListener("waiting", handleWaiting);

        return audio.value;
    }

    /**
     * Load playlist from API
     */
    async function loadPlaylist() {
        isLoading.value = true;
        error.value = "";

        try {
            const response = await axios.get("/api/radio/playlist", {
                params: { parse: 1 },
            });

            if (response.data.success && response.data.playlist) {
                playlistUrl.value = response.data.playlist.url;

                if (
                    response.data.playlist.tracks &&
                    response.data.playlist.tracks.length > 0
                ) {
                    playlist.value = response.data.playlist.tracks;

                    // Auto-load first track
                    if (playlist.value.length > 0) {
                        loadTrack(0);
                    }
                } else if (response.data.playlist.url) {
                    // Backend returned URL but no parsed tracks
                    // Try to parse client-side
                    await fetchAndParsePlaylist(response.data.playlist.url);
                } else {
                    error.value = "No playlist configured";
                }
            } else {
                error.value = "No playlist configured";
            }
        } catch (err) {
            console.error("Failed to load playlist:", err);
            error.value = "Failed to load playlist";
        } finally {
            isLoading.value = false;
        }
    }

    /**
     * Fetch and parse M3U playlist client-side
     */
    async function fetchAndParsePlaylist(url) {
        try {
            const response = await fetch(url);
            const text = await response.text();
            playlist.value = parseM3U(text);

            if (playlist.value.length > 0) {
                loadTrack(0);
            }
        } catch (err) {
            console.error("Failed to fetch playlist:", err);
            error.value = "Failed to fetch playlist file";
        }
    }

    /**
     * Parse M3U playlist format
     */
    function parseM3U(text) {
        const tracks = [];
        const lines = text.split(/\r?\n/);
        let currentTrack = {};

        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed) continue;

            if (trimmed.startsWith("#EXTM3U")) {
                // Header line, skip
                continue;
            } else if (trimmed.startsWith("#EXTINF:")) {
                // Parse extended info
                const match = trimmed.match(/#EXTINF:(-?\d+),(.*)$/);
                if (match) {
                    currentTrack.duration = parseInt(match[1], 10);
                    const info = match[2];

                    // Try to parse "Artist - Title" format
                    const parts = info.split(" - ");
                    if (parts.length >= 2) {
                        currentTrack.artist = parts[0].trim();
                        currentTrack.title = parts.slice(1).join(" - ").trim();
                    } else {
                        currentTrack.title = info.trim();
                        currentTrack.artist = "Unknown Artist";
                    }
                }
            } else if (!trimmed.startsWith("#")) {
                // This is a URL
                currentTrack.url = trimmed;

                // Add track to list
                if (currentTrack.url) {
                    currentTrack.title = currentTrack.title || "Unknown Track";
                    currentTrack.artist =
                        currentTrack.artist || "Unknown Artist";
                    currentTrack.duration = currentTrack.duration || -1;

                    tracks.push({ ...currentTrack });
                }

                // Reset for next track
                currentTrack = {};
            }
        }

        return tracks;
    }

    /**
     * Load a specific track by index
     */
    function loadTrack(index) {
        if (!audio.value || index < 0 || index >= playlist.value.length) {
            return;
        }

        const track = playlist.value[index];
        currentIndex.value = index;

        // Reset state
        duration.value = 0;
        currentTime.value = 0;
        error.value = "";
        isLoading.value = true;

        // Destroy existing HLS instance if any
        if (hls.value) {
            hls.value.destroy();
            hls.value = null;
        }

        // Check if URL is HLS stream (.m3u8)
        const isHLS = track.url.includes(".m3u8");

        if (isHLS && Hls.isSupported()) {
            // Use HLS.js for HLS streams
            hls.value = new Hls({
                enableWorker: true,
                lowLatencyMode: false,
                backBufferLength: 90,
            });

            hls.value.loadSource(track.url);
            hls.value.attachMedia(audio.value);

            hls.value.on(Hls.Events.MANIFEST_PARSED, () => {
                console.log("HLS manifest loaded, ready to play");
                isLoading.value = false;
            });

            hls.value.on(Hls.Events.ERROR, (event, data) => {
                console.error("HLS error:", data);
                if (data.fatal) {
                    switch (data.type) {
                        case Hls.ErrorTypes.NETWORK_ERROR:
                            error.value = "Network error loading stream";
                            hls.value.startLoad();
                            break;
                        case Hls.ErrorTypes.MEDIA_ERROR:
                            error.value = "Media error";
                            hls.value.recoverMediaError();
                            break;
                        default:
                            error.value = "Fatal error loading stream";
                            hls.value.destroy();
                            hls.value = null;
                            break;
                    }
                }
            });
        } else if (
            isHLS &&
            audio.value.canPlayType("application/vnd.apple.mpegurl")
        ) {
            // Native HLS support (Safari)
            audio.value.src = track.url;
            audio.value.load();
        } else {
            // Regular audio file
            audio.value.src = track.url;
            audio.value.load();
        }

        // Update Media Session API
        updateMediaSession();
    }

    /**
     * Play current track
     */
    async function play() {
        if (!audio.value || !currentTrack.value) return;

        try {
            await audio.value.play();
        } catch (err) {
            console.error("Play failed:", err);
            error.value = "Playback failed";
        }
    }

    /**
     * Pause current track
     */
    function pause() {
        if (!audio.value) return;
        audio.value.pause();
    }

    /**
     * Toggle play/pause
     */
    function togglePlay() {
        if (isPlaying.value) {
            pause();
        } else {
            play();
        }
    }

    /**
     * Play next track
     */
    function next() {
        if (hasNext.value) {
            loadTrack(currentIndex.value + 1);
            if (isPlaying.value) {
                play();
            }
        }
    }

    /**
     * Play previous track
     */
    function previous() {
        if (hasPrevious.value) {
            loadTrack(currentIndex.value - 1);
            if (isPlaying.value) {
                play();
            }
        } else if (currentTime.value > 3) {
            // If more than 3 seconds into track, restart current track
            seek(0);
        }
    }

    /**
     * Seek to specific time (seconds)
     */
    function seek(time) {
        if (!audio.value) return;
        audio.value.currentTime = Math.max(0, Math.min(time, duration.value));
    }

    /**
     * Set volume (0-100)
     */
    function setVolume(value) {
        if (!audio.value) return;

        const vol = Math.max(0, Math.min(100, value));
        volume.value = vol;
        audio.value.volume = vol / 100;

        // Save to localStorage
        localStorage.setItem("radio_volume", vol.toString());
    }

    /**
     * Toggle mute
     */
    function toggleMute() {
        if (!audio.value) return;

        isMuted.value = !isMuted.value;
        audio.value.muted = isMuted.value;
    }

    /**
     * Update Media Session API
     */
    function updateMediaSession() {
        if (!("mediaSession" in navigator) || !currentTrack.value) {
            return;
        }

        navigator.mediaSession.metadata = new MediaMetadata({
            title: currentTrack.value.title,
            artist: currentTrack.value.artist,
            album: "TheBoosh Radio",
        });

        // Set up action handlers
        navigator.mediaSession.setActionHandler("play", play);
        navigator.mediaSession.setActionHandler("pause", pause);
        navigator.mediaSession.setActionHandler(
            "previoustrack",
            hasPrevious.value ? previous : null,
        );
        navigator.mediaSession.setActionHandler(
            "nexttrack",
            hasNext.value ? next : null,
        );
    }

    // Event handlers
    function handleLoadedMetadata() {
        if (audio.value) {
            duration.value = audio.value.duration;
        }
    }

    function handleTimeUpdate() {
        if (audio.value) {
            currentTime.value = audio.value.currentTime;
        }
    }

    function handleEnded() {
        // Auto-advance to next track, or loop back to beginning
        if (hasNext.value) {
            next();
        } else {
            // End of playlist - loop back to the beginning
            if (playlist.value.length > 0) {
                loadTrack(0);
                play();
            }
        }
    }

    function handlePlay() {
        isPlaying.value = true;
        isLoading.value = false;
    }

    function handlePause() {
        isPlaying.value = false;
    }

    function handleError(event) {
        console.error("Audio error:", event);
        error.value = "Failed to load audio track";
        isLoading.value = false;
        isPlaying.value = false;
    }

    function handleCanPlay() {
        isLoading.value = false;
    }

    function handleWaiting() {
        isLoading.value = true;
    }

    /**
     * Cleanup
     */
    function cleanup() {
        if (audio.value) {
            pause();
            audio.value.removeEventListener(
                "loadedmetadata",
                handleLoadedMetadata,
            );
            audio.value.removeEventListener("timeupdate", handleTimeUpdate);
            audio.value.removeEventListener("ended", handleEnded);
            audio.value.removeEventListener("play", handlePlay);
            audio.value.removeEventListener("pause", handlePause);
            audio.value.removeEventListener("error", handleError);
            audio.value.removeEventListener("canplay", handleCanPlay);
            audio.value.removeEventListener("waiting", handleWaiting);
            audio.value.src = "";
            audio.value = null;
        }

        // Destroy HLS instance
        if (hls.value) {
            hls.value.destroy();
            hls.value = null;
        }
    }

    // Cleanup on unmount
    onUnmounted(cleanup);

    // Watch for volume changes to update audio
    watch(volume, (newVolume) => {
        setVolume(newVolume);
    });

    /**
     * Load playlist with synchronization
     * Fetches sync info from server and loads at the correct position
     */
    async function loadPlaylistWithSync() {
        isLoading.value = true;
        error.value = "";

        try {
            // Fetch sync info from backend
            const response = await axios.get("/api/radio/sync-info");

            if (!response.data.success) {
                error.value = "Failed to load sync info";
                return false;
            }

            const syncInfo = response.data.sync_info;

            if (!syncInfo.configured) {
                error.value = syncInfo.message || "No playlist configured";
                return false;
            }

            // Fetch the playlist
            const playlistResponse = await axios.get("/api/radio/playlist", {
                params: { parse: 1 },
            });

            if (
                !playlistResponse.data.success ||
                !playlistResponse.data.playlist
            ) {
                error.value = "Failed to load playlist";
                return false;
            }

            playlistUrl.value = playlistResponse.data.playlist.url;

            if (
                playlistResponse.data.playlist.tracks &&
                playlistResponse.data.playlist.tracks.length > 0
            ) {
                playlist.value = playlistResponse.data.playlist.tracks;

                // Sync to calculated position
                if (syncInfo.is_hls) {
                    // For HLS streams, load and seek to position
                    await loadTrack(0);
                    if (syncInfo.current_position > 0 && audio.value) {
                        audio.value.currentTime = syncInfo.current_position;
                    }
                } else if (
                    syncInfo.total_duration &&
                    syncInfo.current_track_index !== undefined
                ) {
                    // For regular playlists, load the correct track
                    await loadTrack(syncInfo.current_track_index);
                    if (syncInfo.current_position > 0 && audio.value) {
                        audio.value.currentTime = syncInfo.current_position;
                    }
                } else {
                    // Fallback: just load first track
                    await loadTrack(0);
                }

                return true;
            } else {
                error.value = "No tracks in playlist";
                return false;
            }
        } catch (err) {
            console.error("Failed to load playlist with sync:", err);
            error.value = "Failed to load synchronized playlist";
            return false;
        } finally {
            isLoading.value = false;
        }
    }

    /**
     * Sync to a specific position in the playlist
     * Used for initial sync and periodic re-sync
     */
    function syncToPosition(trackIndex, timeOffset) {
        if (trackIndex !== currentIndex.value) {
            loadTrack(trackIndex);
        }

        if (audio.value && timeOffset > 0) {
            audio.value.currentTime = timeOffset;
        }
    }

    return {
        // Audio element
        audio,

        // State
        playlist,
        currentIndex,
        currentTrack,
        isPlaying,
        isLoading,
        duration,
        currentTime,
        volume,
        isMuted,
        error,

        // Computed
        hasNext,
        hasPrevious,
        progress,

        // Methods
        init,
        loadPlaylist,
        loadPlaylistWithSync,
        syncToPosition,
        loadTrack,
        play,
        pause,
        togglePlay,
        next,
        previous,
        seek,
        setVolume,
        toggleMute,
        cleanup,
    };
}
