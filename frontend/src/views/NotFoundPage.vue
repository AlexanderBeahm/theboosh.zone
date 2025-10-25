<template>
    <div class="content not-found-page">
        <h1>404</h1>
        <h2>Page Not Found</h2>
        <p>The page you're looking for doesn't exist.</p>
        <router-link to="/" class="home-link"> Go back home </router-link>
    </div>
</template>

<style scoped>
.content {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-height: 80vh;
}

.not-found-page h1 {
    font-size: 96px;
    font-weight: bold;
    color: var(--primary-color);
    margin: 0;
    line-height: 1;
}

.not-found-page h2 {
    font-size: 36px;
    color: var(--dark-text);
    margin: var(--spacing-sm) 0;
}

.not-found-page p {
    font-size: 18px;
    color: var(--text-secondary);
    margin-bottom: var(--spacing-lg);
}

.home-link {
    display: inline-block;
    padding: var(--spacing-sm) var(--spacing-md);
    background-color: var(--primary-color);
    color: white;
    text-decoration: none;
    border-radius: var(--radius-sm);
    font-weight: 500;
    transition: background-color var(--transition-fast);
}

.home-link:hover {
    background-color: var(--primary-dark);
}
</style>
