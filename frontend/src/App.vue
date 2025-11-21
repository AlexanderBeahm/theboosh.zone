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
import { onMounted } from "vue";
import NavBar from "./components/NavBar.vue";
import ErrorBoundary from "./components/ErrorBoundary.vue";
import RadioWidget from "./components/RadioWidget.vue";
import { useRadioStore } from "./composables/useRadioStore";

const radioStore = useRadioStore();

// Initialize radio on app mount
onMounted(async () => {
    // Give the app a moment to render, then initialize radio
    await new Promise((resolve) => setTimeout(resolve, 100));

    try {
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

        // Only auto-play if user has listened before
        // First-time users need to click "Listen Live" button
        if (hasListened) {
            await radioStore.player.play();
        }
    } catch (error) {
        console.warn("Failed to initialize radio:", error);
    }
});
</script>
