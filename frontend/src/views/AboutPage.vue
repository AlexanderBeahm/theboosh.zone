<template>
  <div class="about-page">
    <div class="page-header">
      <HeroBurst size="medium" />
      <h1>About</h1>
      <h2 class="page-description">
        About my zone.
      </h2>
    </div>

    <div class="about-content">
      <section class="info-card">
        <div class="card-header">
          <h2>Contact</h2>
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
                <IconGithub class="link-icon" />
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
                <IconLinkedin class="link-icon" />
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
                <IconX class="link-icon" />
                X
              </a>
            </li>
            <li>
              <a
                href="https://discord.com/users/232161007366176769"
                target="_blank"
                rel="noopener noreferrer"
                class="link-discord"
              >
                <IconDiscord class="link-icon" />
                Discord
              </a>
            </li>
            <li>
              <a
                href="https://rateyourmusic.com/~The_Booshnaw"
                target="_blank"
                rel="noopener noreferrer"
                class="link-rym"
              >
                <IconRYM class="link-icon" />
                RateYourMusic
              </a>
            </li>
            <li>
              <a
                href="https://letterboxd.com/Booshnaw/"
                target="_blank"
                rel="noopener noreferrer"
                class="link-letterboxd"
              >
                <IconLetterboxd class="link-icon" />
                Letterboxd
              </a>
            </li>
            <li>
              <a
                href="https://backloggd.com/u/Booshnaw/"
                target="_blank"
                rel="noopener noreferrer"
                class="link-backloggd"
              >
                <IconBackloggd class="link-icon" />
                Backloggd
              </a>
            </li>
            <li>
              <a
                href="https://dropkickd.com/user/Booshnaw"
                target="_blank"
                rel="noopener noreferrer"
                class="link-dropkickd"
              >
                <IconDropkickd class="link-icon" />
                Dropkickd
              </a>
            </li>
            <li>
              <a
                href="https://www.goodreads.com/user/show/189992282-alex-beahm"
                target="_blank"
                rel="noopener noreferrer"
                class="link-goodreads"
              >
                <IconGoodreads class="link-icon" />
                Goodreads
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
              <span class="tech-icon-wrapper">
                <IconPerl class="tech-icon" />
              </span>
              Perl with Mojolicious framework
            </li>
            <li>
              <span class="tech-icon-wrapper">
                <IconVue class="tech-icon" />
              </span>
              Vue 3 for frontend interactivity
            </li>
            <li>
              <span class="tech-icon-wrapper">
                <IconPostgresql class="tech-icon" />
              </span>
              PostgreSQL for database
            </li>
            <li>
              <span class="tech-icon-wrapper">
                <IconNginx class="tech-icon" />
              </span>
              Nginx for reverse-proxy
            </li>
            <li>
              <span class="tech-icon-wrapper">
                <IconDocker class="tech-icon" />
              </span>
              Docker for containerization
            </li>
            <li>
              <span class="tech-icon-wrapper">
                <IconDigitalOcean class="tech-icon" />
              </span>
              DigitalOcean for hosting
            </li>
            <li>
              <span class="tech-icon-wrapper">
                <IconGithub class="tech-icon" />
              </span>
              Github for version control and CI/CD
            </li>
            <li>
              <span class="tech-icon-wrapper">
                <IconClaude class="tech-icon" />
              </span>
              Claude Code for AI agent assitance
            </li>
          </ul>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import HeroBurst from "../components/HeroBurst.vue";

// Import local icon components
import IconGithub from "../components/icons/IconGithub.vue";
import IconLinkedin from "../components/icons/IconLinkedin.vue";
import IconX from "../components/icons/IconX.vue";
import IconLetterboxd from "../components/icons/IconLetterboxd.vue";
import IconDropkickd from "../components/icons/IconDropkickd.vue";
import IconGoodreads from "../components/icons/IconGoodreads.vue";
import IconDiscord from "../components/icons/IconDiscord.vue";
import IconRYM from "../components/icons/IconRYM.vue";
import IconBackloggd from "../components/icons/IconBackloggd.vue";
import IconPerl from "../components/icons/IconPerl.vue";
import IconVue from "../components/icons/IconVue.vue";
import IconPostgresql from "../components/icons/IconPostgresql.vue";
import IconDocker from "../components/icons/IconDocker.vue";
import IconNginx from "../components/icons/IconNginx.vue";
import IconDigitalOcean from "../components/icons/IconDigitalOcean.vue";
import IconClaude from "../components/icons/IconClaude.vue";
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
    font-size: clamp(2rem, 4vw + 1rem, 3.5rem);
    margin-bottom: var(--spacing-md);
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: clamp(0.02em, 0.05em, 0.08em);
    text-shadow: 0 0 clamp(20px, 2vw, 30px) rgba(184, 188, 200, 0.3);
    animation: textGlow 4s ease-in-out infinite alternate;
    position: relative;
    z-index: 2;
    -webkit-text-stroke: clamp(1px, 0.15vw, 2px) black; /* width and color */
}

@keyframes textGlow {
    from {
        text-shadow:
            0 0 clamp(15px, 1.5vw, 20px) rgba(184, 188, 200, 0.3),
            0 0 clamp(30px, 3vw, 40px) rgba(255, 105, 180, 0.2);
    }
    to {
        text-shadow:
            0 0 clamp(20px, 2vw, 30px) rgba(184, 188, 200, 0.5),
            0 0 clamp(45px, 4.5vw, 60px) rgba(255, 105, 180, 0.4);
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
    font-size: clamp(1rem, 2vw + 0.5rem, 1.125rem);
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
    width: 1.25rem;
    height: 1.25rem;
    display: inline-block;
    vertical-align: middle;
    flex-shrink: 0;
    transition: transform var(--transition-fast);
}

.social-links a:hover .link-icon {
    transform: scale(1.1);
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

.tech-icon-wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 32px;
    height: 32px;
    background: var(--darker-bg);
    border-radius: var(--radius-md);
    border: 1px solid var(--border-color);
    transition: all var(--transition-fast);
    flex-shrink: 0;
}

.tech-list li:hover .tech-icon-wrapper {
    background: var(--card-bg);
    border-color: var(--primary-color);
    box-shadow: 0 0 10px rgba(255, 105, 180, 0.3);
}

.tech-icon {
    width: 1.5rem;
    height: 1.5rem;
    display: block;
    color: var(--text-primary);
    transition: color var(--transition-fast);
}

.tech-list li:hover .tech-icon {
    color: var(--primary-color);
}

/* Responsive Design */
@media (max-width: 768px) {
    .about-page {
        padding: var(--spacing-lg) var(--spacing-md);
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
</style>
