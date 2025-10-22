<template>
  <div class="content about-page">
    <h1>TheBoosh.Zone</h1>
    <div class="about-content">
      <section>
        <h2>Alex Beahm</h2>
        <ul>
          <li>
            <a
              href="https://github.com/AlexanderBeahm"
              target="_blank"
              rel="noopener noreferrer"
            >GitHub</a>
          </li>
          <li>
            <a
              href="https://www.linkedin.com/in/alex-beahm-5bb7a89b/"
              target="_blank"
              rel="noopener noreferrer"
            >LinkedIn</a>
          </li>
        </ul>
      </section>
      <section>
        <h2>Technology Stack</h2>
        <ul>
          <li>Perl with Mojolicious framework</li>
          <li>Vue 3 for frontend interactivity</li>
          <li>PostgreSQL for database</li>
          <li>Docker for containerization</li>
        </ul>
      </section>
    </div>
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

.about-page {
  align-items: flex-start;
  padding: var(--spacing-lg);
  max-width: 800px;
  margin: 0 auto;
}

.about-page h1 {
  font-size: 36px;
  margin-bottom: var(--spacing-lg);
  align-self: center;
  color: black;
}

.about-content {
  width: 100%;
}

.about-content section {
  margin-bottom: var(--spacing-lg);
}

.about-content h2 {
  color: var(--dark-bg);
  font-size: 24px;
  margin-bottom: var(--spacing-sm);
  border-bottom: 2px solid var(--primary-color);
  padding-bottom: var(--spacing-xs);
}

.about-content p {
  color: var(--text-primary);
  line-height: 1.6;
  margin-bottom: var(--spacing-sm);
}

.about-content ul {
  list-style: none;
  padding-left: 0;
}

.about-content ul li {
  color: var(--text-primary);
  line-height: 1.8;
  padding-left: var(--spacing-md);
  position: relative;
}

.about-content ul li:before {
  content: "▸";
  color: var(--primary-color);
  position: absolute;
  left: 0;
  font-weight: bold;
}
</style>
