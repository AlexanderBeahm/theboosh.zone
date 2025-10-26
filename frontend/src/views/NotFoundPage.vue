<template>
    <div class="content not-found-page">
        <div class="error-container">
            <div class="glitch-wrapper">
                <h1 class="glitch-text" data-text="404">404</h1>
            </div>
            <h2>Page Not Found</h2>
            <p>The page you're looking for doesn't exist in this dimension.</p>
            <router-link to="/" class="home-link">
                <span>Return to Reality</span>
            </router-link>
        </div>
    </div>
</template>

<style scoped>
.content {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    background: var(--bg-color);
    position: relative;
    overflow: hidden;
}

/* Animated retro-futuristic background */
.content::before {
    content: '';
    position: absolute;
    top: -50%;
    left: -50%;
    right: -50%;
    bottom: -50%;
    background:
        radial-gradient(circle at 25% 25%, rgba(255, 105, 180, 0.1) 0%, transparent 50%),
        radial-gradient(circle at 75% 75%, rgba(0, 206, 209, 0.1) 0%, transparent 50%),
        radial-gradient(circle at 50% 50%, rgba(255, 215, 0, 0.05) 0%, transparent 50%);
    animation: float 20s ease-in-out infinite;
    z-index: 0;
}

.content::after {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background:
        linear-gradient(90deg, rgba(255, 105, 180, 0.02) 1px, transparent 1px),
        linear-gradient(rgba(255, 105, 180, 0.02) 1px, transparent 1px);
    background-size: 50px 50px;
    animation: slidePattern 30s linear infinite;
    z-index: 0;
}

@keyframes float {
    0%, 100% { transform: translate(0, 0) rotate(0deg); }
    25% { transform: translate(20px, -20px) rotate(1deg); }
    50% { transform: translate(-10px, 10px) rotate(-1deg); }
    75% { transform: translate(-20px, -10px) rotate(1deg); }
}

@keyframes slidePattern {
    0% { transform: translate(0, 0); }
    100% { transform: translate(50px, 50px); }
}

.error-container {
    text-align: center;
    position: relative;
    z-index: 1;
    background: var(--card-bg);
    padding: var(--spacing-xxl);
    border-radius: var(--radius-lg);
    border: 1px solid var(--border-color);
    box-shadow:
        var(--shadow-xl),
        0 0 50px rgba(255, 105, 180, 0.2);
    max-width: 600px;
    width: 90%;
}

.error-container::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 4px;
    background: var(--gradient-retro-secondary);
    border-radius: var(--radius-lg) var(--radius-lg) 0 0;
}

.glitch-wrapper {
    position: relative;
    margin-bottom: var(--spacing-lg);
}

.glitch-text {
    font-size: 8rem;
    font-weight: 900;
    margin: 0;
    line-height: 1;
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    position: relative;
    text-shadow: 0 0 50px rgba(255, 215, 0, 0.5);
    animation: textGlow 3s ease-in-out infinite alternate;
}

@keyframes textGlow {
    from {
        text-shadow:
            0 0 20px rgba(255, 215, 0, 0.4),
            0 0 40px rgba(0, 206, 209, 0.3);
    }
    to {
        text-shadow:
            0 0 30px rgba(255, 215, 0, 0.6),
            0 0 60px rgba(0, 206, 209, 0.5);
    }
}

.glitch-text::before {
    content: attr(data-text);
    position: absolute;
    top: 0;
    left: 0;
    color: var(--accent-orange);
    opacity: 0.8;
    animation: glitch1 2s infinite;
    clip-path: polygon(0 0, 100% 0, 100% 45%, 0 45%);
}

.glitch-text::after {
    content: attr(data-text);
    position: absolute;
    top: 0;
    left: 0;
    color: var(--accent-cyan);
    opacity: 0.8;
    animation: glitch2 2s infinite;
    clip-path: polygon(0 55%, 100% 55%, 100% 100%, 0 100%);
}

@keyframes glitch1 {
    0%, 14%, 15%, 49%, 50%, 99%, 100% {
        transform: translate(0);
    }
    15%, 49% {
        transform: translate(-2px, 2px);
    }
}

@keyframes glitch2 {
    0%, 20%, 21%, 62%, 63%, 99%, 100% {
        transform: translate(0);
    }
    21%, 62% {
        transform: translate(2px, -2px);
    }
}

.not-found-page h2 {
    font-size: 2.25rem;
    color: var(--text-primary);
    margin: var(--spacing-lg) 0 var(--spacing-md) 0;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.05em;
}

.not-found-page p {
    font-size: 1.25rem;
    color: var(--text-secondary);
    margin-bottom: var(--spacing-xl);
    line-height: 1.6;
}

.home-link {
    display: inline-block;
    padding: var(--spacing-md) var(--spacing-xl);
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    text-decoration: none;
    border: 1px solid var(--primary-color);
    border-radius: var(--radius-md);
    font-weight: 700;
    font-size: 1.125rem;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    transition: all var(--transition-fast);
    position: relative;
    overflow: hidden;
}

.home-link::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
    transition: left 0.6s;
}

.home-link:hover {
    transform: translateY(-3px);
    box-shadow:
        var(--shadow-lg),
        0 0 30px rgba(255, 105, 180, 0.4);
}

.home-link:hover::before {
    left: 100%;
}

/* Responsive Design */
@media (max-width: 768px) {
    .error-container {
        padding: var(--spacing-xl);
    }

    .glitch-text {
        font-size: 5rem;
    }

    .not-found-page h2 {
        font-size: 1.75rem;
    }

    .not-found-page p {
        font-size: 1rem;
    }

    .home-link {
        font-size: 1rem;
        padding: var(--spacing-sm) var(--spacing-lg);
    }
}

@media (max-width: 480px) {
    .glitch-text {
        font-size: 4rem;
    }

    .not-found-page h2 {
        font-size: 1.5rem;
    }
}
</style>
