<template>
  <div class="nav-bar">
    <nav class="nav-links" aria-label="Main navigation">
      <router-link to="/" :class="{ active: $route.path === '/' }">Home</router-link>
      <router-link to="/about" :class="{ active: $route.path === '/about' }">About</router-link>
      <router-link to="/articles" :class="{ active: $route.path.startsWith('/articles') }">Articles</router-link>
      <a
        href="/swagger"
        target="_blank"
        aria-label="View API documentation in Swagger UI (opens in new tab)"
        rel="noopener noreferrer"
      >Swagger</a>
    </nav>
    <div class="nav-title" aria-label="Site name">TheBoosh.Zone</div>
    <div class="nav-spacer"></div>
  </div>
</template>

<style scoped>
.nav-bar {
  display: flex;
  align-items: center;
  padding: var(--spacing-sm) var(--spacing-lg);
  background-color: var(--dark-bg);
  border-bottom: 3px solid var(--primary-color);
  box-shadow: var(--shadow-sm);
}

.nav-links {
  display: flex;
  gap: var(--spacing-md);
}

.nav-links a {
  text-decoration: none;
  color: var(--light-text);
  font-weight: 500;
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-sm);
  transition: all var(--transition-fast);
  cursor: pointer;
}

.nav-links a:hover {
  background-color: var(--darker-bg);
  color: var(--primary-color);
}

.nav-links a.active {
  background-color: var(--primary-color);
  color: #fff;
}

.nav-title {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  font-size: 1.5rem;
  font-weight: bold;
  color: var(--light-text);
  letter-spacing: 0.5px;
}

.nav-spacer {
  flex: 1;
}
</style>
