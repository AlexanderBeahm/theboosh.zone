import { ref, onUnmounted } from "vue";

/**
 * Composable for creating abstract audio visualizations using Web Audio API
 *
 * Features:
 * - Real-time frequency analysis
 * - Abstract particle-based visualization
 * - Retro-futuristic styling (pink/silver theme)
 * - Performance optimized with RequestAnimationFrame
 * - Singleton pattern to prevent duplicate MediaElementSource creation
 */

// Singleton state - shared across all instances
let audioContext = null;
let analyser = null;
let dataArray = null;
let source = null;

export function useAudioVisualizer() {
    // Canvas and rendering (instance-specific)
    const canvas = ref(null);
    const canvasContext = ref(null);
    const animationId = ref(null);

    // Visualization state
    const isInitialized = ref(false);
    const particles = ref([]);

    // Configuration
    const config = {
        fftSize: 256,
        particleCount: 100,
        minParticleSize: 2,
        maxParticleSize: 8,
        speed: 0.5,
        colorPrimary: "#ff69b4", // Hot pink
        colorSecondary: "#b8bcc8", // Chrome silver
        colorBackground: "#1f2527", // Dark bg
    };

    /**
     * Initialize Web Audio API and connect to audio element
     */
    function init(audioElement) {
        if (isInitialized.value) {
            console.log("Visualizer already initialized, skipping");
            return true;
        }

        if (!audioElement) {
            console.warn(
                "Cannot initialize visualizer: no audio element provided",
            );
            return false;
        }

        try {
            console.log("Initializing audio visualizer...");

            // Create audio context if it doesn't exist (singleton)
            if (!audioContext) {
                audioContext = new (window.AudioContext ||
                    window.webkitAudioContext)();
                console.log("Created new AudioContext");
            } else {
                console.log("Reusing existing AudioContext");
            }

            // Create analyser node (singleton)
            if (!analyser) {
                analyser = audioContext.createAnalyser();
                analyser.fftSize = config.fftSize;
                analyser.smoothingTimeConstant = 0.8;
                console.log("Created new AnalyserNode");
            } else {
                console.log("Reusing existing AnalyserNode");
            }

            // Create buffer for frequency data
            const bufferLength = analyser.frequencyBinCount;
            dataArray = new Uint8Array(bufferLength);

            // Create source from audio element (only once, singleton)
            if (!source) {
                console.log("Creating MediaElementSource from audio element");
                source = audioContext.createMediaElementSource(audioElement);

                // Connect: source -> analyser -> destination (only once)
                source.connect(analyser);
                analyser.connect(audioContext.destination);
                console.log(
                    "Connected audio graph: source -> analyser -> destination",
                );
            } else {
                console.log("Reusing existing MediaElementSource");
            }

            // Initialize particles
            initParticles();

            isInitialized.value = true;
            console.log("Visualizer initialized successfully");

            return true;
        } catch (error) {
            console.error("Failed to initialize visualizer:", error);
            return false;
        }
    }

    /**
     * Set up canvas for rendering
     */
    function setupCanvas(canvasElement) {
        if (!canvasElement) {
            console.warn("Cannot setup canvas: no canvas element provided");
            return false;
        }

        console.log("Setting up canvas for visualizer");
        canvas.value = canvasElement;
        canvasContext.value = canvas.value.getContext("2d");

        // Set canvas size to match container
        resizeCanvas();

        // Handle window resize
        window.addEventListener("resize", resizeCanvas);

        console.log(
            "Canvas setup complete:",
            canvas.value.width,
            "x",
            canvas.value.height,
        );
        return true;
    }

    /**
     * Resize canvas to match container
     */
    function resizeCanvas() {
        if (!canvas.value) return;

        const rect = canvas.value.parentElement.getBoundingClientRect();
        canvas.value.width = rect.width;
        canvas.value.height = rect.height;
    }

    /**
     * Initialize particles for visualization
     */
    function initParticles() {
        particles.value = [];

        for (let i = 0; i < config.particleCount; i++) {
            particles.value.push({
                x: Math.random(),
                y: Math.random(),
                vx: (Math.random() - 0.5) * config.speed,
                vy: (Math.random() - 0.5) * config.speed,
                size:
                    config.minParticleSize +
                    Math.random() *
                        (config.maxParticleSize - config.minParticleSize),
                frequency: Math.floor(
                    Math.random() *
                        (analyser ? analyser.frequencyBinCount : 128),
                ),
                hue: Math.random() * 60 - 30, // Variation around primary color hue
            });
        }
    }

    /**
     * Start animation loop
     */
    function start() {
        if (!canvasContext.value) {
            console.warn(
                "Cannot start visualizer: canvas context not available",
            );
            return;
        }

        if (animationId.value) {
            console.log("Visualizer already running");
            return;
        }

        console.log("Starting visualizer animation");
        animate();
    }

    /**
     * Stop animation loop
     */
    function stop() {
        if (animationId.value) {
            console.log("Stopping visualizer animation");
            window.cancelAnimationFrame(animationId.value);
            animationId.value = null;
        }
    }

    /**
     * Main animation loop
     */
    function animate() {
        animationId.value = window.requestAnimationFrame(animate);

        if (!analyser || !canvasContext.value || !canvas.value) {
            return;
        }

        // Get frequency data
        analyser.getByteFrequencyData(dataArray);

        // Calculate average amplitude for global effects
        const average = dataArray.reduce((a, b) => a + b, 0) / dataArray.length;
        const normalizedAverage = average / 255;

        // Clear canvas with fade effect
        canvasContext.value.fillStyle = `${config.colorBackground}22`;
        canvasContext.value.fillRect(
            0,
            0,
            canvas.value.width,
            canvas.value.height,
        );

        // Update and draw particles
        drawParticles(normalizedAverage);
    }

    /**
     * Draw particles that respond to audio
     */
    function drawParticles(globalAmplitude) {
        const ctx = canvasContext.value;
        const width = canvas.value.width;
        const height = canvas.value.height;

        particles.value.forEach((particle) => {
            // Get frequency data for this particle
            const frequencyValue = dataArray[particle.frequency] / 255;

            // Update position
            particle.x += particle.vx * 0.001;
            particle.y += particle.vy * 0.001;

            // Wrap around edges
            if (particle.x < 0) particle.x = 1;
            if (particle.x > 1) particle.x = 0;
            if (particle.y < 0) particle.y = 1;
            if (particle.y > 1) particle.y = 0;

            // Calculate screen position
            const x = particle.x * width;
            const y = particle.y * height;

            // Calculate size based on frequency and global amplitude
            const size =
                particle.size *
                (1 + frequencyValue * 3) *
                (1 + globalAmplitude * 0.5);

            // Color based on frequency intensity
            const alpha = 0.3 + frequencyValue * 0.7;
            const primaryAmount = frequencyValue;

            // Blend between primary and secondary color
            const r = Math.floor(
                255 * primaryAmount + 184 * (1 - primaryAmount),
            );
            const g = Math.floor(
                105 * primaryAmount + 188 * (1 - primaryAmount),
            );
            const b = Math.floor(
                180 * primaryAmount + 200 * (1 - primaryAmount),
            );

            // Draw particle with glow
            ctx.shadowBlur = 20 + frequencyValue * 30;
            ctx.shadowColor = `rgba(${r}, ${g}, ${b}, ${alpha})`;

            ctx.beginPath();
            ctx.arc(x, y, size, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${alpha})`;
            ctx.fill();

            // Draw connection lines to nearby particles (creates web effect)
            particles.value.forEach((other) => {
                const dx = (other.x - particle.x) * width;
                const dy = (other.y - particle.y) * height;
                const distance = Math.sqrt(dx * dx + dy * dy);

                if (distance < 100 && distance > 0) {
                    const lineAlpha =
                        (1 - distance / 100) * 0.2 * frequencyValue;

                    ctx.shadowBlur = 0;
                    ctx.beginPath();
                    ctx.moveTo(x, y);
                    ctx.lineTo(other.x * width, other.y * height);
                    ctx.strokeStyle = `rgba(${r}, ${g}, ${b}, ${lineAlpha})`;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            });
        });

        ctx.shadowBlur = 0;
    }

    /**
     * Resume audio context (required by browser autoplay policies)
     */
    async function resumeContext() {
        if (audioContext && audioContext.state === "suspended") {
            await audioContext.resume();
        }
    }

    /**
     * Cleanup - but keep audio context and source alive for reuse
     */
    function cleanup() {
        stop();

        // Don't disconnect anything or null out references
        // The audio element, source, and context are shared and need to persist
        // Just stop the animation and mark as not initialized
        window.removeEventListener("resize", resizeCanvas);

        isInitialized.value = false;
    }

    // Cleanup on unmount
    onUnmounted(cleanup);

    return {
        // State
        isInitialized,

        // Methods
        init,
        setupCanvas,
        start,
        stop,
        resumeContext,
        cleanup,
    };
}
