<template>
    <div id="app">
        <NavBar />
        <ErrorBoundary>
            <router-view />
        </ErrorBoundary>

        <!-- Global Radio Widget -->
        <RadioWidget />
    </div>
</template>

<script setup>
import { onMounted, nextTick } from "vue";
import NavBar from "./components/NavBar.vue";
import ErrorBoundary from "./components/ErrorBoundary.vue";
import RadioWidget from "./components/RadioWidget.vue";
import { useRadioStore } from "./composables/useRadioStore";

const radioStore = useRadioStore();

// Initialize radio on app mount
onMounted(async () => {
    // Wait for Vue's render cycle to complete
    await nextTick();

    try {
        // Ensure audio element is initialized before proceeding
        console.log(
            "[App] Audio element exists:",
            !!radioStore.player.audio.value,
        );
        if (!radioStore.player.audio.value) {
            await radioStore.player.init();
        }

        const hasListened = radioStore.userState.hasListened;

        // Save user's preferred volume (from localStorage or default)
        const savedVolume = radioStore.player.volume.value;

        // If user has never listened, set to 0 (muted)
        // If user has listened before, keep their saved volume
        if (!hasListened) {
            radioStore.player.setVolume(0);
            // Store the saved volume for later restoration
            localStorage.setItem("radio_saved_volume", savedVolume.toString());
        }
        // else: volume already loaded from localStorage by useAudioPlayer.init()

        // Load and sync playlist
        await radioStore.player.loadPlaylistWithSync();
        console.log(
            "[App] currentTrack:",
            radioStore.player.currentTrack.value,
        );

        // Note: Auto-play is blocked by browser policy until user interaction
        // Both new and returning users must click to start playback
        // The RadioWidget "Listen Live" button or Visualizer page will handle playback
        console.log(
            "[App] Radio ready, waiting for user interaction to start playback",
        );
    } catch (err) {
        // Log error for debugging but don't show to user
        // Radio can still be started manually via UI
    }
});
</script>
