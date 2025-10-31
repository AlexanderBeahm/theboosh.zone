<template>
    <div class="about-page">
        <div class="page-header">
            <HeroBurst size="medium" />
            <h1>About</h1>
            <h3 class="page-description">About my zone.</h3>
        </div>

        <div class="about-content">
            <section class="info-card">
                <div class="card-header">
                    <h2>Alex Beahm</h2>
                    <div class="card-accent" />
                </div>
                <div class="card-content">
                    <ul class="social-links">
                        <li>
                            <a
                                href="https://github.com/AlexanderBeahm"
                                target="_blank"
                                rel="noopener noreferrer"
                                class="link-github"
                            >
                                <span class="link-icon">🖥️</span>
                                GitHub
                            </a>
                        </li>
                        <li>
                            <a
                                href="https://www.linkedin.com/in/alex-beahm-5bb7a89b/"
                                target="_blank"
                                rel="noopener noreferrer"
                                class="link-linkedin"
                            >
                                <span class="link-icon">💼</span>
                                LinkedIn
                            </a>
                        </li>
                        <li>
                            <a
                                href="https://x.com/BooshnawBeahm"
                                target="_blank"
                                rel="noopener noreferrer"
                                class="link-x"
                            >
                                <span class="link-icon">✖️</span>
                                X
                            </a>
                        </li>
                    </ul>
                </div>
            </section>

            <section class="info-card">
                <div class="card-header">
                    <h2>Technology Stack</h2>
                    <div class="card-accent" />
                </div>
                <div class="card-content">
                    <ul class="tech-list">
                        <li>
                            <span class="tech-icon">🐪</span>
                            Perl with Mojolicious framework
                        </li>
                        <li>
                            <span class="tech-icon">⚡</span>
                            Vue 3 for frontend interactivity
                        </li>
                        <li>
                            <span class="tech-icon">🐘</span>
                            PostgreSQL for database
                        </li>
                        <li>
                            <span class="tech-icon">🐳</span>
                            Docker for containerization
                        </li>
                    </ul>
                </div>
            </section>
        </div>
    </div>
</template>

<script setup>
import HeroBurst from "../components/HeroBurst.vue";
</script>

<style scoped>
.about-page {
    max-width: 1200px;
    margin: 0 auto;
    padding: var(--spacing-lg);
    background-color: var(--bg-color);
    min-height: 100vh;
}

.page-header {
    text-align: center;
    margin-bottom: var(--spacing-xl);
    position: relative;
    padding: var(--spacing-xl) 0;
}

.page-header::before {
    content: "";
    position: absolute;
    top: 50%;
    left: 50%;
    width: 200px;
    height: 200px;
    background: radial-gradient(
        circle,
        rgba(255, 105, 180, 0.1) 0%,
        transparent 70%
    );
    transform: translate(-50%, -50%);
    border-radius: 50%;
    animation: float 8s ease-in-out infinite;
}

.page-header h1 {
    font-size: 3.5rem;
    margin-bottom: var(--spacing-md);
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    text-shadow: 0 0 30px rgba(184, 188, 200, 0.3);
    animation: textGlow 4s ease-in-out infinite alternate;
    position: relative;
    z-index: 2;
    -webkit-text-stroke: 2px black; /* width and color */
}

@keyframes textGlow {
    from {
        text-shadow:
            0 0 20px rgba(184, 188, 200, 0.3),
            0 0 40px rgba(255, 105, 180, 0.2);
    }
    to {
        text-shadow:
            0 0 30px rgba(184, 188, 200, 0.5),
            0 0 60px rgba(255, 105, 180, 0.4);
    }
}

@keyframes float {
    0%,
    100% {
        transform: translate(-50%, -50%) translateY(0px);
    }
    50% {
        transform: translate(-50%, -50%) translateY(-10px);
    }
}

.page-description {
    font-size: 1.125rem;
    color: var(--text-secondary);
    max-width: 600px;
    margin: 0 auto;
    position: relative;
    z-index: 2;
    line-height: 1.6;
    text-shadow:
        1px 1px 0 #000,
        -1px 1px 0 #000,
        1px -1px 0 #000,
        -1px -1px 0 #000,
        0px 1px 0 #000,
        0px -1px 0 #000,
        -1px 0px 0 #000,
        1px 0px 0 #000,
        2px 2px 0 #000,
        -2px 2px 0 #000,
        2px -2px 0 #000,
        -2px -2px 0 #000,
        0px 2px 0 #000,
        0px -2px 0 #000,
        -2px 0px 0 #000,
        2px 0px 0 #000,
        1px 2px 0 #000,
        -1px 2px 0 #000,
        1px -2px 0 #000,
        -1px -2px 0 #000,
        2px 1px 0 #000,
        -2px 1px 0 #000,
        2px -1px 0 #000,
        -2px -1px 0 #000;
}

.about-content {
    display: grid;
    gap: var(--spacing-xl);
    grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
}

.info-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-lg);
    box-shadow: var(--shadow-lg);
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.info-card::before {
    content: "";
    position: absolute;
    top: -2px;
    left: -2px;
    right: -2px;
    bottom: -2px;
    border-radius: var(--radius-lg);
    opacity: 0;
    transition: opacity var(--transition-fast);
    z-index: -1;
}

.info-card:hover {
    transform: translateY(-4px);
    box-shadow:
        var(--shadow-xl),
        0 0 30px rgba(255, 105, 180, 0.2);
}

.info-card:hover::before {
    opacity: 0.1;
}

.card-header {
    padding: var(--spacing-lg) var(--spacing-lg) 0;
    position: relative;
    background: var(--card-bg);
}

.card-header h2 {
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    font-size: 1.75rem;
    font-weight: 700;
    margin-bottom: var(--spacing-sm);
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.card-accent {
    height: 3px;
    background: var(--gradient-retro-primary);
    border-radius: var(--radius-full);
    margin-bottom: var(--spacing-md);
    position: relative;
    overflow: hidden;
}

.card-accent::after {
    content: "";
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
        90deg,
        transparent,
        rgba(255, 255, 255, 0.4),
        transparent
    );
    animation: shimmer 2s ease-in-out infinite;
}

@keyframes shimmer {
    0% {
        left: -100%;
    }
    100% {
        left: 100%;
    }
}

.card-content {
    padding: 0 var(--spacing-lg) var(--spacing-lg);
    background: var(--card-bg);
}

.social-links,
.tech-list {
    list-style: none;
    padding: 0;
    margin: 0;
    background: var(--card-bg);
}

.social-links li,
.tech-list li {
    margin-bottom: var(--spacing-md);
    transition: transform var(--transition-fast);
    background: linear-gradient(
        90deg,
        transparent,
        rgba(255, 105, 180, 0.1),
        transparent
    );
}

.social-links li:hover,
.tech-list li:hover {
    transform: translateX(8px);
}

.social-links a {
    display: flex;
    align-items: center;
    gap: var(--spacing-sm);
    color: var(--text-primary);
    text-decoration: none;
    font-weight: 600;
    font-size: 1.125rem;
    padding: var(--spacing-sm) var(--spacing-md);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
    z-index: 10;
    cursor: pointer;
}

.social-links a::before {
    content: "";
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
        90deg,
        transparent,
        rgba(255, 105, 180, 0.1),
        transparent
    );
    transition: left 0.6s;
    pointer-events: none;
    z-index: -1;
}

.social-links a:hover {
    border-color: var(--primary-color);
    color: var(--primary-color);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.3);
}

.social-links a:hover::before {
    left: 100%;
}

.link-github:hover {
    border-color: var(--primary-color) !important;
    color: var(--primary-color) !important;
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.3) !important;
}

.link-linkedin:hover {
    border-color: var(--primary-color) !important;
    color: var(--primary-color) !important;
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.3) !important;
}

.link-icon {
    font-size: 1.25rem;
    filter: grayscale(0);
}

.tech-list li {
    display: flex;
    align-items: center;
    gap: var(--spacing-md);
    color: var(--text-primary);
    font-size: 1.125rem;
    font-weight: 500;
    padding: var(--spacing-sm) var(--spacing-md);
    border-radius: var(--radius-md);
    background: rgba(255, 105, 180, 0.05);
    border: 1px solid rgba(255, 105, 180, 0.2);
    transition: all var(--transition-fast);
}

.tech-list li:hover {
    background: rgba(255, 105, 180, 0.1);
    border-color: var(--primary-color);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.2);
}

.tech-icon {
    font-size: 1.5rem;
    filter: grayscale(0);
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    background: var(--darker-bg);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
}

/* Responsive Design */
@media (max-width: 768px) {
    .about-page {
        padding: var(--spacing-lg) var(--spacing-md);
    }

    .page-header h1 {
        font-size: 2.5rem;
    }

    .about-content {
        grid-template-columns: 1fr;
        gap: var(--spacing-lg);
    }

    .card-header h2 {
        font-size: 1.5rem;
    }

    .social-links a,
    .tech-list li {
        font-size: 1rem;
    }
}

@media (max-width: 480px) {
    .page-header h1 {
        font-size: 2rem;
    }

    .page-description {
        font-size: 1rem;
    }
}
</style>
