<template>
  <div class="nav-bar">
    <!-- Mobile hamburger button (visible ≤768px) -->
    <button
      v-if="isMobile"
      class="hamburger-button"
      aria-label="Toggle navigation menu"
      :aria-expanded="isMobileMenuOpen"
      aria-controls="mobile-nav-menu"
      @click="toggleMobileMenu"
    >
      <span
        class="hamburger-icon"
        :class="{ open: isMobileMenuOpen }"
      >
        <span class="bar" />
        <span class="bar" />
        <span class="bar" />
      </span>
    </button>

    <!-- Site title (mobile only) -->
    <router-link
      v-if="isMobile"
      to="/"
      class="mobile-logo"
      @click="closeMobileMenu"
    >
      THEBOOSH.ZONE
    </router-link>

    <!-- Desktop navigation (hidden on mobile) -->
    <nav
      v-if="!isMobile"
      class="nav-links"
      aria-label="Main navigation"
    >
      <router-link
        to="/"
        :class="{ active: $route.path === '/' }"
      >
        THEBOOSH.ZONE
      </router-link>
      <router-link
        to="/about"
        :class="{ active: $route.path === '/about' }"
      >
        ABOUT
      </router-link>
      <router-link
        to="/articles"
        :class="{ active: $route.path.startsWith('/articles') }"
      >
        ARTICLES
      </router-link>
      <router-link
        to="/radio"
        :class="{ active: $route.path === '/radio' }"
      >
        RADIO
      </router-link>
      <a
        v-if="config.enableSwagger"
        href="/swagger"
        target="_blank"
        aria-label="View API documentation in Swagger UI (opens in new tab)"
        rel="noopener noreferrer"
      >SWAGGER</a>
      <router-link
        v-if="isAuthenticated"
        to="/admin"
        :class="{ active: $route.path.endsWith('/admin') }"
      >
        ADMIN
      </router-link>
      <router-link
        v-if="isAuthenticated"
        to="/admin/media"
        :class="{ active: $route.path.startsWith('/admin/media') }"
      >
        MEDIA
      </router-link>
      <router-link
        v-if="isAuthenticated"
        to="/admin/radio"
        :class="{ active: $route.path.startsWith('/admin/radio') }"
      >
        RADIO CONFIG
      </router-link>
    </nav>
    <div class="nav-spacer" />

    <!-- Admin Logout Button (only visible when authenticated) -->
    <div
      v-if="isAuthenticated"
      class="nav-actions"
    >
      <button
        class="logout-button"
        title="Logout"
        @click="handleLogout"
      >
        LOGOUT
      </button>
    </div>
  </div>

  <!-- Mobile dropdown menu (positioned below navbar) -->
  <Transition name="slide-down">
    <nav
      v-if="isMobile && isMobileMenuOpen"
      id="mobile-nav-menu"
      class="mobile-menu"
      aria-label="Mobile navigation"
    >
      <router-link
        to="/about"
        :class="{ active: $route.path === '/about' }"
        @click="closeMobileMenu"
      >
        ABOUT
      </router-link>
      <router-link
        to="/articles"
        :class="{ active: $route.path.startsWith('/articles') }"
        @click="closeMobileMenu"
      >
        ARTICLES
      </router-link>
      <router-link
        to="/radio"
        :class="{ active: $route.path === '/radio' }"
        @click="closeMobileMenu"
      >
        RADIO
      </router-link>
      <a
        v-if="config.enableSwagger"
        href="/swagger"
        target="_blank"
        aria-label="View API documentation in Swagger UI (opens in new tab)"
        rel="noopener noreferrer"
        @click="closeMobileMenu"
      >SWAGGER</a>
      <div
        v-if="isAuthenticated"
        class="mobile-menu-divider"
      />
      <router-link
        v-if="isAuthenticated"
        to="/admin"
        :class="{ active: $route.path.endsWith('/admin') }"
        @click="closeMobileMenu"
      >
        ADMIN
      </router-link>
      <router-link
        v-if="isAuthenticated"
        to="/admin/media"
        :class="{ active: $route.path.startsWith('/admin/media') }"
        @click="closeMobileMenu"
      >
        MEDIA
      </router-link>
      <router-link
        v-if="isAuthenticated"
        to="/admin/radio"
        :class="{ active: $route.path.startsWith('/admin/radio') }"
        @click="closeMobileMenu"
      >
        RADIO CONFIG
      </router-link>
    </nav>
  </Transition>

  <!-- Backdrop overlay -->
  <Transition name="fade">
    <div
      v-if="isMobile && isMobileMenuOpen"
      class="mobile-menu-backdrop"
      @click="closeMobileMenu"
    />
  </Transition>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import { useAuth } from "../composables/useAuth";
import { config } from "../config";

const router = useRouter();
const { isAuthenticated, checkAuth, logout } = useAuth();

// Mobile menu state
const isMobileMenuOpen = ref(false);
const isMobile = ref(false);

// Check if viewport is mobile size
function checkMobile() {
    isMobile.value = window.innerWidth <= 768;
    // Close menu when switching to desktop
    if (!isMobile.value) {
        isMobileMenuOpen.value = false;
    }
}

// Toggle mobile menu
function toggleMobileMenu() {
    isMobileMenuOpen.value = !isMobileMenuOpen.value;
}

// Close mobile menu
function closeMobileMenu() {
    isMobileMenuOpen.value = false;
}

// Handle click outside menu
function handleClickOutside(event) {
    if (!isMobile.value || !isMobileMenuOpen.value) return;

    const mobileMenu = document.getElementById("mobile-nav-menu");
    const hamburgerButton = event.target.closest(".hamburger-button");

    // Close if clicking outside menu and not on hamburger button
    if (mobileMenu && !mobileMenu.contains(event.target) && !hamburgerButton) {
        closeMobileMenu();
    }
}

// Handle escape key
function handleEscapeKey(event) {
    if (event.key === "Escape" && isMobileMenuOpen.value) {
        closeMobileMenu();
    }
}

// Handle logout
async function handleLogout() {
    closeMobileMenu();
    await logout("/admin/login");
}

// Close menu on route change
router.afterEach(() => {
    closeMobileMenu();
});

// Lifecycle hooks
onMounted(() => {
    checkAuth();
    checkMobile();
    window.addEventListener("resize", checkMobile);
    document.addEventListener("click", handleClickOutside);
    document.addEventListener("keydown", handleEscapeKey);
});

onUnmounted(() => {
    window.removeEventListener("resize", checkMobile);
    document.removeEventListener("click", handleClickOutside);
    document.removeEventListener("keydown", handleEscapeKey);
});
</script>

<style scoped>
.nav-bar {
    display: flex;
    align-items: center;
    padding: var(--spacing-sm) var(--spacing-lg);
    background: var(--gradient-retro-primary-reverse);
    border-bottom: 3px solid var(--primary-color);
    box-shadow: var(--shadow-lg);
    position: relative;
    overflow: hidden;
    z-index: 1000;
}

/* Subtle geometric grid pattern overlay */
.nav-bar::before {
    content: "";
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
    z-index: 10;
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
    background-color: rgba(255, 105, 180, 0.1);
    color: var(--primary-color);
    border-color: var(--primary-color);
    box-shadow: 0 0 10px rgba(255, 105, 180, 0.3);
    transform: translateY(-1px);
}

.nav-links a.active {
    background: var(--gradient-retro-primary);
    color: var(--light-text);
    box-shadow: 0 0 15px rgba(255, 105, 180, 0.4);
    border: 1px solid var(--primary-color);
}

.nav-spacer {
    flex: 1;
}

.nav-actions {
    display: flex;
    align-items: center;
    gap: var(--spacing-md);
    position: relative;
    z-index: 10;
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

/* Mobile-specific styles */
.hamburger-button {
    display: none;
    background: none;
    border: none;
    cursor: pointer;
    padding: var(--spacing-xs);
    z-index: 10;
    position: relative;
    width: 44px;
    height: 44px;
    align-items: center;
    justify-content: center;
}

.hamburger-icon {
    display: flex;
    flex-direction: column;
    gap: 4px;
    width: 24px;
    height: 18px;
    position: relative;
}

.hamburger-icon .bar {
    display: block;
    width: 100%;
    height: 2px;
    background-color: var(--light-text);
    border-radius: 2px;
    transition: all 0.3s ease-in-out;
    transform-origin: center;
}

/* Hamburger animation to X */
.hamburger-icon.open .bar:nth-child(1) {
    transform: translateY(6px) rotate(45deg);
}

.hamburger-icon.open .bar:nth-child(2) {
    opacity: 0;
}

.hamburger-icon.open .bar:nth-child(3) {
    transform: translateY(-6px) rotate(-45deg);
}

.hamburger-button:hover .bar {
    box-shadow: 0 0 8px rgba(255, 105, 180, 0.5);
    background-color: var(--primary-color);
}

.mobile-logo {
    text-decoration: none;
    color: var(--light-text);
    font-weight: 700;
    font-size: 1rem;
    white-space: nowrap;
    position: relative;
    z-index: 10;
    margin-left: var(--spacing-sm);
}

.mobile-menu {
    position: fixed;
    top: calc(3px + 56px); /* Below navbar height + border */
    left: 0;
    right: 0;
    background: var(--gradient-retro-primary-reverse);
    border-bottom: 2px solid var(--primary-color);
    box-shadow: var(--shadow-xl);
    z-index: 999;
    display: flex;
    flex-direction: column;
    padding: var(--spacing-sm) 0;
}

.mobile-menu a {
    text-decoration: none;
    color: var(--light-text);
    font-weight: 600;
    padding: var(--spacing-sm) var(--spacing-lg);
    min-height: 44px;
    display: flex;
    align-items: center;
    transition: all var(--transition-fast);
    border-left: 3px solid transparent;
}

.mobile-menu a:hover {
    background-color: rgba(255, 105, 180, 0.1);
    color: var(--primary-color);
    border-left-color: var(--primary-color);
}

.mobile-menu a.active {
    background: rgba(255, 105, 180, 0.2);
    color: var(--primary-color);
    border-left-color: var(--primary-color);
    box-shadow: inset 0 0 10px rgba(255, 105, 180, 0.2);
}

.mobile-menu-divider {
    height: 1px;
    background: linear-gradient(
        90deg,
        transparent,
        var(--primary-color),
        transparent
    );
    margin: var(--spacing-sm) var(--spacing-lg);
    opacity: 0.3;
}

.mobile-menu-backdrop {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.3);
    backdrop-filter: blur(2px);
    z-index: 998;
}

/* Slide-down transition for mobile menu */
.slide-down-enter-active,
.slide-down-leave-active {
    transition: all 0.3s ease-in-out;
}

.slide-down-enter-from {
    opacity: 0;
    transform: translateY(-10px);
}

.slide-down-leave-to {
    opacity: 0;
    transform: translateY(-10px);
}

/* Fade transition for backdrop */
.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.3s ease-in-out;
}

.fade-enter-from,
.fade-leave-to {
    opacity: 0;
}

/* Responsive design for mobile screens */
@media (max-width: 768px) {
    .nav-bar {
        padding: var(--spacing-xs) var(--spacing-md);
    }

    .hamburger-button {
        display: flex;
    }

    .nav-links {
        display: none;
    }

    .logout-button {
        font-size: 0.75rem;
        padding: var(--spacing-xs) var(--spacing-sm);
    }
}
</style>
