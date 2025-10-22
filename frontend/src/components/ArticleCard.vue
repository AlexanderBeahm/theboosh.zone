<template>
  <article
    class="article-card"
    @click="$emit('click')"
  >
    <div
      v-if="article.featured_image"
      class="article-image"
    >
      <img
        :src="article.featured_image"
        :alt="article.title"
        loading="lazy"
      >
    </div>

    <div class="article-content">
      <div class="article-meta">
        <time :datetime="article.published_at || article.date_added">
          {{ formatDate(article.published_at || article.date_added) }}
        </time>
        <span
          v-if="article.author"
          class="author"
        >by {{ article.author }}</span>
      </div>

      <h2 class="article-title">
        {{ article.title }}
      </h2>

      <p
        v-if="article.excerpt"
        class="article-excerpt"
      >
        {{ article.excerpt }}
      </p>

      <div
        v-if="article.tags && article.tags.length > 0"
        class="article-tags"
      >
        <span
          v-for="tag in article.tags"
          :key="tag.id"
          class="article-tag"
          @click.stop="$emit('tag-click', tag.slug)"
        >
          #{{ tag.name }}
        </span>
      </div>

      <div class="article-footer">
        <span class="read-more">Read more →</span>
      </div>
    </div>
  </article>
</template>

<script setup>
defineProps({
  article: {
    type: Object,
    required: true
  }
})

defineEmits(['click', 'tag-click'])

function formatDate(dateString) {
  if (!dateString) return ''

  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}
</script>

<style scoped>
.article-card {
  background-color: var(--card-bg);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-lg);
  overflow: hidden;
  cursor: pointer;
  transition: all var(--transition-fast);
  box-shadow: var(--shadow-sm);
}

.article-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
  border-color: var(--primary-color-light);
}

.article-image {
  width: 100%;
  height: 200px;
  overflow: hidden;
}

.article-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform var(--transition-fast);
}

.article-card:hover .article-image img {
  transform: scale(1.05);
}

.article-content {
  padding: var(--spacing-lg);
}

.article-meta {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  font-size: 0.875rem;
  color: var(--text-secondary);
  margin-bottom: var(--spacing-sm);
}

.article-meta::after {
  content: '•';
  color: var(--text-secondary);
}

.article-meta .author:last-child ~ ::after {
  content: none;
}

.article-title {
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: var(--spacing-md);
  line-height: 1.3;
}

.article-excerpt {
  color: var(--text-secondary);
  line-height: 1.6;
  margin-bottom: var(--spacing-md);
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.article-tags {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-xs);
  margin-bottom: var(--spacing-md);
}

.article-tag {
  font-size: 0.75rem;
  color: var(--primary-color);
  background-color: var(--primary-color-light);
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all var(--transition-fast);
  font-weight: 500;
}

.article-tag:hover {
  background-color: var(--primary-color);
  color: white;
}

.article-footer {
  display: flex;
  justify-content: flex-end;
}

.read-more {
  color: var(--primary-color);
  font-weight: 500;
  font-size: 0.875rem;
}

/* Responsive Design */
@media (max-width: 768px) {
  .article-title {
    font-size: 1.25rem;
  }

  .article-content {
    padding: var(--spacing-md);
  }
}
</style>
