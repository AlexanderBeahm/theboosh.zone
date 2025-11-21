import { reactive, readonly } from "vue";
import { useAudioPlayer } from "./useAudioPlayer";

/**
 * Global Radio Store (Singleton Pattern)
 *
 * Provides a shared instance of the audio player across all components.
 * This allows the RadioPage and RadioWidget to share the same playback state,
 * ensuring synchronized playback when navigating between pages.
 *
 * Features:
 * - Singleton audio player instance
 * - Widget visibility and position management
 * - Persistent widget state (position, minimized)
 */

// Singleton player instance - shared across all components
let playerInstance = null;

// Widget state - reactive and shared
const widgetState = reactive({
    isVisible: false,
    isMinimized: false,
    position: loadPosition(),
});

// User interaction state - reactive and shared
const userState = reactive({
    hasListened: loadHasListened(),
    hasUserInteracted: false,
    savedUserVolume: 70,
});

/**
 * Load saved widget position from localStorage
 */
function loadPosition() {
    try {
        const saved = localStorage.getItem("radio_widget_position");
        if (saved) {
            const position = JSON.parse(saved);
            // Validate position is within reasonable bounds
            const x = Math.max(
                0,
                Math.min(position.x, window.innerWidth - 320),
            );
            const y = Math.max(
                0,
                Math.min(position.y, window.innerHeight - 100),
            );
            return { x, y };
        }
    } catch (e) {
        console.warn("Failed to load widget position:", e);
    }

    // Default position: bottom-right corner
    return {
        x: window.innerWidth - 340,
        y: window.innerHeight - 120,
    };
}

/**
 * Save widget position to localStorage
 */
function savePosition(x, y) {
    try {
        localStorage.setItem("radio_widget_position", JSON.stringify({ x, y }));
    } catch (e) {
        console.warn("Failed to save widget position:", e);
    }
}

/**
 * Load widget minimized state from localStorage
 */
function loadMinimizedState() {
    try {
        const saved = localStorage.getItem("radio_widget_minimized");
        return saved === "true";
    } catch (e) {
        console.warn("Failed to load widget minimized state:", e);
        return false;
    }
}

/**
 * Load hasListened state from localStorage
 */
function loadHasListened() {
    try {
        const saved = localStorage.getItem("radio_has_listened");
        return saved === "true";
    } catch (e) {
        console.warn("Failed to load hasListened state:", e);
        return false;
    }
}

/**
 * Save hasListened state to localStorage
 */
function saveHasListened(listened) {
    try {
        localStorage.setItem("radio_has_listened", listened.toString());
    } catch (e) {
        console.warn("Failed to save hasListened state:", e);
    }
}

/**
 * Save widget minimized state to localStorage
 */
function saveMinimizedState(isMinimized) {
    try {
        localStorage.setItem("radio_widget_minimized", isMinimized.toString());
    } catch (e) {
        console.warn("Failed to save widget minimized state:", e);
    }
}

/**
 * Initialize radio by loading and syncing playlist
 * Audio is loaded but starts muted (volume 0)
 */
async function initializeRadio() {
    if (!playerInstance) return;

    try {
        // Save the user's preferred volume before muting
        userState.savedUserVolume = playerInstance.volume;

        // Set volume to 0 (muted) before loading
        playerInstance.setVolume(0);

        // Load playlist with sync
        await playerInstance.loadPlaylistWithSync();

        // Start playback (will be muted)
        await playerInstance.play();
    } catch (error) {
        console.warn("Failed to initialize radio:", error);
        // Silently fail - user can manually start later
    }
}

/**
 * Restore user's saved volume on first interaction (Listen Live button)
 */
function restoreUserVolume() {
    if (!userState.hasUserInteracted && playerInstance) {
        userState.hasUserInteracted = true;
        userState.hasListened = true;
        saveHasListened(true);

        // Try to get saved volume from localStorage (set by App.vue initialization)
        const saved = localStorage.getItem("radio_saved_volume");
        const volumeToRestore = saved
            ? parseInt(saved, 10)
            : userState.savedUserVolume;

        console.log(
            "Restoring volume:",
            volumeToRestore,
            "from localStorage:",
            saved,
        );
        playerInstance.setVolume(volumeToRestore);
    }
}

/**
 * Main composable - returns shared radio player and widget controls
 */
export function useRadioStore() {
    // Initialize player instance only once
    if (!playerInstance) {
        playerInstance = useAudioPlayer();
        playerInstance.init();

        // Load saved minimized state
        widgetState.isMinimized = loadMinimizedState();

        // Note: Radio initialization happens in App.vue onMounted
    }

    return {
        // Shared player instance
        // Note: Templates must use .value to access refs (e.g., player.playlist.value)
        player: playerInstance,

        // Widget state (read-only to prevent direct mutation from outside)
        widgetState: readonly(widgetState),

        // Widget visibility actions
        showWidget() {
            widgetState.isVisible = true;
        },

        hideWidget() {
            widgetState.isVisible = false;
        },

        toggleWidget() {
            widgetState.isVisible = !widgetState.isVisible;
        },

        // Widget position actions
        setWidgetPosition(x, y) {
            widgetState.position = { x, y };
            savePosition(x, y);
        },

        // Widget minimize actions
        minimizeWidget() {
            widgetState.isMinimized = true;
            saveMinimizedState(true);
        },

        maximizeWidget() {
            widgetState.isMinimized = false;
            saveMinimizedState(false);
        },

        toggleMinimize() {
            widgetState.isMinimized = !widgetState.isMinimized;
            saveMinimizedState(widgetState.isMinimized);
        },

        // Volume restoration on user interaction
        restoreUserVolume,

        // User state (reactive)
        userState: readonly(userState),
    };
}

/**
 * Reset the singleton instance (useful for testing)
 */
export function resetRadioStore() {
    if (playerInstance) {
        playerInstance.cleanup();
        playerInstance = null;
    }

    widgetState.isVisible = false;
    widgetState.isMinimized = false;
    widgetState.position = loadPosition();
}
