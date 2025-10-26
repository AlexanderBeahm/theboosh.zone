<template>
  <div class="content about-page">
    <div class="page-header">
      <h1>TheBoosh.Zone</h1>
      <p class="subtitle">
        A retro-futuristic digital dimension
      </p>
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
                <span class="link-icon">⚡</span>
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

<style scoped>
.content {
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
        radial-gradient(circle at 30% 20%, rgba(255, 105, 180, 0.08) 0%, transparent 50%),
        radial-gradient(circle at 70% 80%, rgba(255, 105, 180, 0.08) 0%, transparent 50%);
    animation: float 25s ease-in-out infinite;
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
    background-size: 40px 40px;
    animation: slidePattern 35s linear infinite;
    z-index: 0;
}

@keyframes float {
    0%, 100% { transform: translate(0, 0) rotate(0deg); }
    25% { transform: translate(15px, -15px) rotate(0.5deg); }
    50% { transform: translate(-8px, 8px) rotate(-0.5deg); }
    75% { transform: translate(-15px, -8px) rotate(0.5deg); }
}

@keyframes slidePattern {
    0% { transform: translate(0, 0); }
    100% { transform: translate(40px, 40px); }
}

.about-page {
    position: relative;
    z-index: 1;
    padding: var(--spacing-xl) var(--spacing-lg);
    max-width: 900px;
    margin: 0 auto;
}

.page-header {
    text-align: center;
    margin-bottom: var(--spacing-xxl);
    position: relative;
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
    letter-spacing: 0.1em;
    text-shadow: 0 0 30px rgba(184, 188, 200, 0.3);
    animation: textGlow 4s ease-in-out infinite alternate;
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

.subtitle {
    font-size: 1.25rem;
    color: var(--text-secondary);
    font-weight: 500;
    font-style: italic;
    letter-spacing: 0.05em;
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
    content: '';
    position: absolute;
    top: -2px;
    left: -2px;
    right: -2px;
    bottom: -2px;
    background: var(--gradient-retro-primary);
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
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.4), transparent);
    animation: shimmer 2s ease-in-out infinite;
}

@keyframes shimmer {
    0% { left: -100%; }
    100% { left: 100%; }
}

.card-content {
    padding: 0 var(--spacing-lg) var(--spacing-lg);
}

.social-links,
.tech-list {
    list-style: none;
    padding: 0;
    margin: 0;
}

.social-links li,
.tech-list li {
    margin-bottom: var(--spacing-md);
    transition: transform var(--transition-fast);
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
}

.social-links a::before {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 105, 180, 0.1), transparent);
    transition: left 0.6s;
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

    .subtitle {
        font-size: 1rem;
    }
}
</style>
