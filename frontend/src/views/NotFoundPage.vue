<template>
  <div class="content not-found-page">
    <h1>404</h1>
    <h2>Page Not Found</h2>
    <p>The page you're looking for doesn't exist.</p>
    <router-link
      to="/"
      class="home-link"
    >
      Go back home
    </router-link>
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
  color: #3498db;
  margin: 0;
  line-height: 1;
}

.not-found-page h2 {
  font-size: 36px;
  color: #2c3e50;
  margin: 1rem 0;
}

.not-found-page p {
  font-size: 18px;
  color: #666;
  margin-bottom: 2rem;
}

.home-link {
  display: inline-block;
  padding: 0.75rem 1.5rem;
  background-color: #3498db;
  color: white;
  text-decoration: none;
  border-radius: 4px;
  font-weight: 500;
  transition: background-color 0.2s;
}

.home-link:hover {
  background-color: #2980b9;
}
</style>
