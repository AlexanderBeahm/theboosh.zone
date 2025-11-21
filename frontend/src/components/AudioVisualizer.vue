<template>
    <div class="audio-visualizer">
        <canvas ref="canvasRef" class="visualizer-canvas" />
        <div v-if="!isInitialized" class="visualizer-placeholder">
            <div class="pulse-icon">
                <svg width="100" height="100" viewBox="0 0 100 100">
                    <circle
                        cx="50"
                        cy="50"
                        r="40"
                        stroke="currentColor"
                        stroke-width="2"
                        fill="none"
                        class="pulse-circle"
                    />
                    <path
                        d="M 30 50 L 40 50 L 45 30 L 50 70 L 55 40 L 60 50 L 70 50"
                        stroke="currentColor"
                        stroke-width="2"
                        fill="none"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                    />
                </svg>
            </div>
            <p class="placeholder-text">
                {{ placeholderText }}
            </p>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, watch, computed } from "vue";
import { useAudioVisualizer } from "../composables/useAudioVisualizer";

const props = defineProps({
    audioElement: {
        type: Object, // HTMLAudioElement
        default: null,
    },
    isPlaying: {
        type: Boolean,
        default: false,
    },
});

const canvasRef = ref(null);
const visualizer = useAudioVisualizer();

const { isInitialized, setupCanvas, init, start, stop, resumeContext } =
    visualizer;

const placeholderText = computed(() => {
    if (!props.audioElement) {
        return "Loading audio...";
    }
    if (!isInitialized.value) {
        return "Initializing visualizer...";
    }
    if (!props.isPlaying) {
        return "Press play to start";
    }
    return "";
});

// Initialize when audio element is available
watch(
    () => props.audioElement,
    (newAudio, oldAudio) => {
        console.log("AudioVisualizer: audio element changed", {
            newAudio: !!newAudio,
            oldAudio: !!oldAudio,
            isInitialized: isInitialized.value,
            hasCanvas: !!canvasRef.value,
        });

        if (newAudio && !isInitialized.value) {
            console.log("AudioVisualizer: attempting to initialize");
            const success = init(newAudio);

            if (success && canvasRef.value) {
                console.log(
                    "AudioVisualizer: init successful, setting up canvas",
                );
                setupCanvas(canvasRef.value);

                if (props.isPlaying) {
                    console.log(
                        "AudioVisualizer: audio is playing, starting animation",
                    );
                    resumeContext()
                        .then(() => {
                            start();
                        })
                        .catch((err) => {
                            //eslint-disable-next-line no-console
                            console.warn("Failed to start visualizer:", err);
                        });
                } else {
                    console.log("AudioVisualizer: audio not playing yet");
                }
            } else if (!success) {
                console.error("AudioVisualizer: initialization failed");
            } else if (!canvasRef.value) {
                console.warn("AudioVisualizer: no canvas ref available");
            }
        }
    },
    { immediate: true },
);

// Start/stop visualization based on playback state
watch(
    () => props.isPlaying,
    (playing) => {
        console.log("AudioVisualizer: playback state changed", {
            playing,
            isInitialized: isInitialized.value,
        });

        if (!isInitialized.value) {
            console.log(
                "AudioVisualizer: not initialized, skipping playback state change",
            );
            return;
        }

        if (playing) {
            console.log(
                "AudioVisualizer: resuming context and starting animation",
            );
            resumeContext()
                .then(() => {
                    start();
                })
                .catch((err) => {
                    //eslint-disable-next-line no-console
                    console.warn("Failed to start visualizer:", err);
                });
        } else {
            console.log("AudioVisualizer: stopping animation");
            stop();
        }
    },
);

onMounted(() => {
    console.log("AudioVisualizer: component mounted", {
        hasCanvas: !!canvasRef.value,
        hasAudio: !!props.audioElement,
        isInitialized: isInitialized.value,
    });

    // Setup canvas if initialized but canvas wasn't set up yet
    if (isInitialized.value && canvasRef.value) {
        console.log(
            "AudioVisualizer: visualizer initialized but canvas needs setup",
        );
        setupCanvas(canvasRef.value);

        // If audio is already playing, start the animation
        if (props.isPlaying) {
            console.log(
                "AudioVisualizer: audio already playing, starting animation",
            );
            resumeContext()
                .then(() => {
                    start();
                })
                .catch((err) => {
                    console.warn("Failed to start visualizer:", err);
                });
        }
    } else if (canvasRef.value && props.audioElement && !isInitialized.value) {
        console.log("AudioVisualizer: initializing on mount");
        const success = init(props.audioElement);
        if (success) {
            setupCanvas(canvasRef.value);

            // If audio is already playing, start the animation
            if (props.isPlaying) {
                console.log(
                    "AudioVisualizer: audio already playing, starting animation",
                );
                resumeContext()
                    .then(() => {
                        start();
                    })
                    .catch((err) => {
                        console.warn("Failed to start visualizer:", err);
                    });
            }
        }
    }
});
</script>

<style scoped>
.audio-visualizer {
    position: relative;
    width: 100%;
    height: 100%;
    background: var(--bg-color);
    overflow: hidden;
}

.visualizer-canvas {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
}

.visualizer-placeholder {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
    color: var(--text-secondary);
    pointer-events: none;
}

.pulse-icon {
    color: var(--primary-color);
    margin-bottom: var(--spacing-md);
    animation: pulse 2s ease-in-out infinite;
}

.pulse-circle {
    transform-origin: center;
    animation: pulse-ring 2s ease-in-out infinite;
}

.placeholder-text {
    font-size: 1.125rem;
    margin: 0;
    text-transform: uppercase;
    letter-spacing: 0.1em;
}

@keyframes pulse {
    0%,
    100% {
        opacity: 0.6;
        transform: scale(1);
    }
    50% {
        opacity: 1;
        transform: scale(1.05);
    }
}

@keyframes pulse-ring {
    0%,
    100% {
        opacity: 1;
        stroke-width: 2;
    }
    50% {
        opacity: 0.5;
        stroke-width: 4;
    }
}
</style>
