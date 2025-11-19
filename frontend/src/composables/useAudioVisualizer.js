import { ref, onUnmounted } from "vue";

/**
 * Composable for creating abstract audio visualizations using Web Audio API
 *
 * Features:
 * - Real-time frequency analysis
 * - Abstract particle-based visualization
 * - Retro-futuristic styling (pink/silver theme)
 * - Performance optimized with RequestAnimationFrame
 */
export function useAudioVisualizer() {
    // Audio context and analyzer
    const audioContext = ref(null);
    const analyser = ref(null);
    const dataArray = ref(null);
    const source = ref(null);

    // Canvas and rendering
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
            console.warn("Audio visualizer already initialized");
            return;
        }

        try {
            // Create audio context
            audioContext.value = new (window.AudioContext ||
                window.webkitAudioContext)();

            // Create analyser node
            analyser.value = audioContext.value.createAnalyser();
            analyser.value.fftSize = config.fftSize;
            analyser.value.smoothingTimeConstant = 0.8;

            // Create buffer for frequency data
            const bufferLength = analyser.value.frequencyBinCount;
            dataArray.value = new Uint8Array(bufferLength);

            // Create source from audio element
            source.value =
                audioContext.value.createMediaElementSource(audioElement);

            // Connect: source -> analyser -> destination
            source.value.connect(analyser.value);
            analyser.value.connect(audioContext.value.destination);

            // Initialize particles
            initParticles();

            isInitialized.value = true;

            return true;
        } catch (err) {
            console.error("Failed to initialize audio visualizer:", err);
            return false;
        }
    }

    /**
     * Set up canvas for rendering
     */
    function setupCanvas(canvasElement) {
        canvas.value = canvasElement;
        canvasContext.value = canvas.value.getContext("2d");

        // Set canvas size to match container
        resizeCanvas();

        // Handle window resize
        window.addEventListener("resize", resizeCanvas);
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
                        (analyser.value
                            ? analyser.value.frequencyBinCount
                            : 128),
                ),
                hue: Math.random() * 60 - 30, // Variation around primary color hue
            });
        }
    }

    /**
     * Start animation loop
     */
    function start() {
        if (!canvasContext.value || animationId.value) return;

        animate();
    }

    /**
     * Stop animation loop
     */
    function stop() {
        if (animationId.value) {
            cancelAnimationFrame(animationId.value);
            animationId.value = null;
        }
    }

    /**
     * Main animation loop
     */
    function animate() {
        animationId.value = requestAnimationFrame(animate);

        if (!analyser.value || !canvasContext.value || !canvas.value) {
            return;
        }

        // Get frequency data
        analyser.value.getByteFrequencyData(dataArray.value);

        // Calculate average amplitude for global effects
        const average =
            dataArray.value.reduce((a, b) => a + b, 0) / dataArray.value.length;
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
            const frequencyValue = dataArray.value[particle.frequency] / 255;

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
        if (audioContext.value && audioContext.value.state === "suspended") {
            await audioContext.value.resume();
        }
    }

    /**
     * Cleanup
     */
    function cleanup() {
        stop();

        if (source.value) {
            source.value.disconnect();
            source.value = null;
        }

        if (analyser.value) {
            analyser.value.disconnect();
            analyser.value = null;
        }

        if (audioContext.value) {
            audioContext.value.close();
            audioContext.value = null;
        }

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
