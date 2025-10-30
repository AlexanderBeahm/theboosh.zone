<template>
    <div class="hero-burst" :class="sizeClass">
        <div class="burst-container">
            <div class="burst-image" />
            <div class="burst-glow" />
        </div>
    </div>
</template>

<script setup>
import { computed } from "vue";
import spaceartImage from "@/assets/images/spaceart_small.png";

// Props for customization
const props = defineProps({
    intensity: {
        type: Number,
        default: 1,
        validator: (value) => value >= 0 && value <= 2,
    },
    size: {
        type: String,
        default: "medium",
        validator: (value) => ["small", "medium", "large"].includes(value),
    },
    animationSpeed: {
        type: Number,
        default: 4,
        validator: (value) => value > 0 && value <= 10,
    },
});

// Computed class for size variants
const sizeClass = computed(() => `hero-burst--${props.size}`);

// Computed background image URL
const backgroundImageUrl = computed(() => `url(${spaceartImage})`);
</script>

<style scoped>
.hero-burst {
    position: absolute;
    top: -60%;
    left: 50%;
    transform: translateX(-50%);
    z-index: 1;
    pointer-events: none;
    width: 80%;
    aspect-ratio: 2.5 / 1;
}

.burst-container {
    position: relative;
    width: 100%;
    height: 100%;
    overflow: hidden;
}

/* Partial arc/dome shape using clip-path */
.burst-image {
    position: absolute;
    top: -10%;
    left: 0;
    width: 100%;
    height: 200%;
    background-image: v-bind("backgroundImageUrl");
    background-size: cover;
    background-position: center;
    background-repeat: no-repeat;
    clip-path: ellipse(100% 80% at 50% 100%);
    animation: burstFloat var(--animation-speed, 4s) ease-in-out infinite
        alternate;
    transition: all var(--transition-fast);
}

/* Pink glow effect layers */
.burst-glow {
    position: absolute;
    top: -10px;
    left: -10px;
    right: -10px;
    bottom: -10px;
    clip-path: ellipse(100% 80% at 50% 100%);
    background: transparent;
    box-shadow:
        0 0 20px rgba(255, 105, 180, calc(0.3 * var(--glow-intensity, 1))),
        0 0 40px rgba(255, 105, 180, calc(0.2 * var(--glow-intensity, 1))),
        0 0 60px rgba(255, 105, 180, calc(0.1 * var(--glow-intensity, 1))),
        inset 0 0 30px rgba(255, 105, 180, calc(0.1 * var(--glow-intensity, 1)));
    animation: burstGlow calc(var(--animation-speed, 4s) * 1.2) ease-in-out
        infinite alternate;
    opacity: var(--glow-intensity, 1);
}

/* Size variants */
.hero-burst--small {
    width: 60%;
    top: -45%;
    aspect-ratio: 2.2 / 1;
}

.hero-burst--medium {
    width: 80%;
    top: -50%;
    aspect-ratio: 2.5 / 1;
}

.hero-burst--large {
    width: 100%;
    top: -60%;
    aspect-ratio: 3 / 1;
}

/* Animation keyframes */
@keyframes burstFloat {
    0% {
        transform: scale(0.98) translateY(0px) translate3d(0, 0, 0);
    }
    100% {
        transform: scale(1.02) translateY(-5px) translate3d(0, 0, 0);
    }
}

@keyframes burstGlow {
    0% {
        opacity: calc(0.6 * var(--glow-intensity, 1));
        box-shadow:
            0 0 15px rgba(255, 105, 180, calc(0.25 * var(--glow-intensity, 1))),
            0 0 30px rgba(255, 105, 180, calc(0.15 * var(--glow-intensity, 1))),
            0 0 45px rgba(255, 105, 180, calc(0.08 * var(--glow-intensity, 1))),
            inset 0 0 20px
                rgba(255, 105, 180, calc(0.08 * var(--glow-intensity, 1)));
    }
    100% {
        opacity: calc(1 * var(--glow-intensity, 1));
        box-shadow:
            0 0 25px rgba(255, 105, 180, calc(0.4 * var(--glow-intensity, 1))),
            0 0 50px rgba(255, 105, 180, calc(0.25 * var(--glow-intensity, 1))),
            0 0 75px rgba(255, 105, 180, calc(0.15 * var(--glow-intensity, 1))),
            inset 0 0 40px
                rgba(255, 105, 180, calc(0.15 * var(--glow-intensity, 1)));
    }
}

/* CSS custom properties for dynamic values */
.hero-burst {
    --animation-speed: v-bind('props.animationSpeed + "s"');
    --glow-intensity: v-bind("props.intensity");
}

/* Responsive design */
@media (max-width: 768px) {
    .hero-burst {
        width: 90%;
        top: -30%;
    }

    .hero-burst--small {
        width: 70%;
        top: -25%;
    }

    .hero-burst--large {
        width: 95%;
        top: -35%;
    }

    .burst-image {
        height: 180%;
    }
}

@media (max-width: 480px) {
    .hero-burst {
        width: 95%;
        top: -25%;
        aspect-ratio: 2.2 / 1;
    }

    .hero-burst--small {
        width: 75%;
        top: -20%;
    }

    .hero-burst--large {
        width: 100%;
        top: -30%;
    }

    .burst-image {
        height: 160%;
    }

    /* Reduce glow intensity on mobile for performance */
    .burst-glow {
        box-shadow:
            0 0 15px rgba(255, 105, 180, calc(0.2 * var(--glow-intensity, 1))),
            0 0 30px rgba(255, 105, 180, calc(0.1 * var(--glow-intensity, 1))),
            inset 0 0 20px
                rgba(255, 105, 180, calc(0.08 * var(--glow-intensity, 1)));
    }
}

/* Performance optimizations */
.hero-burst {
    will-change: transform;
}

.burst-image {
    will-change: transform;
    backface-visibility: hidden;
}

.burst-glow {
    will-change: opacity, box-shadow;
    backface-visibility: hidden;
}

/* Reduced motion support */
@media (prefers-reduced-motion: reduce) {
    .burst-image,
    .burst-glow {
        animation: none;
    }
}
</style>
