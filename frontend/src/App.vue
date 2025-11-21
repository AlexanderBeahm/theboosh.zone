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

        // Note: Auto-play is blocked by browser policy until user interaction
        // Both new and returning users must click to start playback
        // The RadioWidget "Listen Live" button or Visualizer page will handle playback
    } catch {
        // Radio can still be started manually via UI if initialization fails
    }
});
</script>
