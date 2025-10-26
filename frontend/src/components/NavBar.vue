<template>
    <div class="nav-bar">
        <nav class="nav-links" aria-label="Main navigation">
            <router-link to="/" :class="{ active: $route.path === '/' }">
                Home
            </router-link>
            <router-link
                to="/about"
                :class="{ active: $route.path === '/about' }"
            >
                About
            </router-link>
            <router-link
                to="/articles"
                :class="{ active: $route.path.startsWith('/articles') }"
            >
                Articles
            </router-link>
            <a
                v-if="config.enableSwagger"
                href="/swagger"
                target="_blank"
                aria-label="View API documentation in Swagger UI (opens in new tab)"
                rel="noopener noreferrer"
                >Swagger</a
            >
            <router-link
                v-if="isAuthenticated"
                to="/admin"
                :class="{ active: $route.path.startsWith('/admin') }"
            >
                Admin
            </router-link>
        </nav>
        <div class="nav-title" aria-label="Site name">TheBoosh.Zone</div>
        <div class="nav-spacer" />

        <!-- Admin Logout Button (only visible when authenticated) -->
        <div v-if="isAuthenticated" class="nav-actions">
            <button class="logout-button" title="Logout" @click="handleLogout">
                Logout
            </button>
        </div>
    </div>
</template>

<script setup>
import { onMounted } from "vue";
import { useAuth } from "../composables/useAuth";
import { config } from "../config";

const { isAuthenticated, checkAuth, logout } = useAuth();

// Handle logout
async function handleLogout() {
    await logout("/admin/login");
}

// Check auth on mount
onMounted(() => {
    checkAuth();
});
</script>

<style scoped>
.nav-bar {
    display: flex;
    align-items: center;
    padding: var(--spacing-sm) var(--spacing-lg);
    background: var(--gradient-metallic); /* Retro-futuristic metallic gradient */
    border-bottom: 3px solid var(--primary-color);
    box-shadow: var(--shadow-lg);
    position: relative;
    overflow: hidden;
}

/* Subtle geometric grid pattern overlay */
.nav-bar::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-image:
        linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px),
        linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px);
    background-size: 20px 20px;
    pointer-events: none;
}

.nav-links {
    display: flex;
    gap: var(--spacing-md);
    position: relative;
    z-index: 1;
}

.nav-links a {
    text-decoration: none;
    color: var(--light-text);
    font-weight: 600;
    padding: var(--spacing-xs) var(--spacing-sm);
    border-radius: var(--radius-sm);
    transition: all var(--transition-fast);
    cursor: pointer;
    border: 1px solid transparent;
    position: relative;
    overflow: hidden;
}

/* Hover effect with retro-futuristic glow */
.nav-links a:hover {
    background-color: rgba(0, 206, 209, 0.1);
    color: var(--accent-cyan);
    border-color: var(--accent-cyan);
    box-shadow: 0 0 10px rgba(0, 206, 209, 0.3);
    transform: translateY(-1px);
}

.nav-links a.active {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    border: 1px solid var(--primary-color);
}

.nav-title {
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    font-size: 1.75rem;
    font-weight: 700;
    color: var(--light-text);
    letter-spacing: 1px;
    text-transform: uppercase;
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    text-shadow: 0 0 20px rgba(255, 215, 0, 0.3);
    z-index: 1;
}

.nav-spacer {
    flex: 1;
}

.nav-actions {
    display: flex;
    align-items: center;
    gap: var(--spacing-md);
    position: relative;
    z-index: 1;
}

.logout-button {
    padding: var(--spacing-xs) var(--spacing-md);
    border: 1px solid var(--accent-orange);
    background: rgba(255, 69, 0, 0.1);
    color: var(--light-text);
    border-radius: var(--radius-md);
    font-weight: 600;
    font-size: 0.875rem;
    cursor: pointer;
    transition: all var(--transition-fast);
    white-space: nowrap;
    position: relative;
    overflow: hidden;
}

.logout-button:hover {
    background: rgba(255, 69, 0, 0.2);
    border-color: var(--accent-orange);
    transform: translateY(-1px);
    box-shadow: 0 0 10px rgba(255, 69, 0, 0.4);
    color: var(--accent-orange);
}

.logout-button:active {
    transform: translateY(0);
}

/* Responsive design for smaller screens */
@media (max-width: 768px) {
    .nav-title {
        position: static;
        transform: none;
        font-size: 1.25rem;
        margin-left: var(--spacing-md);
    }

    .nav-links {
        gap: var(--spacing-sm);
    }

    .nav-links a {
        padding: var(--spacing-xs);
        font-size: 0.875rem;
    }
}
</style>
