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
  background: var(--card-bg);
  border: 1px solid var(--border-color);
  border-radius: var(--radius-lg);
  overflow: hidden;
  cursor: pointer;
  transition: all var(--transition-fast);
  box-shadow: var(--shadow-sm);
  position: relative;
}

/* Subtle retro-futuristic border glow */
.article-card::before {
  content: '';
  position: absolute;
  top: -1px;
  left: -1px;
  right: -1px;
  bottom: -1px;
  background: var(--gradient-retro-secondary);
  border-radius: var(--radius-lg);
  opacity: 0;
  transition: opacity var(--transition-fast);
  z-index: -1;
}

.article-card:hover {
  transform: translateY(-4px);
  box-shadow:
    var(--shadow-lg),
    0 0 20px rgba(255, 105, 180, 0.1);
}

.article-card:hover::before {
  opacity: 0.3;
}

.article-image {
  width: 100%;
  height: 200px;
  overflow: hidden;
  position: relative;
}

.article-image::after {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(135deg,
    rgba(255, 105, 180, 0.1) 0%,
    transparent 50%,
    rgba(0, 206, 209, 0.1) 100%);
  opacity: 0;
  transition: opacity var(--transition-fast);
}

.article-card:hover .article-image::after {
  opacity: 1;
}

.article-image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transition: transform var(--transition-fast);
}

.article-card:hover .article-image img {
  transform: scale(1.08);
}

.article-content {
  padding: var(--spacing-lg);
  position: relative;
  z-index: 1;
}

.article-meta {
  display: flex;
  align-items: center;
  gap: var(--spacing-sm);
  font-size: 0.875rem;
  color: var(--text-secondary);
  margin-bottom: var(--spacing-sm);
  font-weight: 500;
}

.article-meta time {
  color: var(--accent-cyan);
}

.article-meta::after {
  content: '•';
  color: var(--border-color);
}

.article-meta .author:last-child ~ ::after {
  content: none;
}

.article-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--text-primary);
  margin-bottom: var(--spacing-md);
  line-height: 1.3;
  transition: color var(--transition-fast);
}

.article-card:hover .article-title {
  color: var(--accent-cyan);
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
  color: var(--accent-cyan);
  background: rgba(0, 206, 209, 0.1);
  border: 1px solid rgba(0, 206, 209, 0.3);
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-full);
  cursor: pointer;
  transition: all var(--transition-fast);
  font-weight: 600;
  position: relative;
  overflow: hidden;
}

.article-tag::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(0, 206, 209, 0.2), transparent);
  transition: left 0.6s;
}

.article-tag:hover {
  background: var(--accent-cyan);
  color: var(--bg-color);
  border-color: var(--accent-cyan);
  box-shadow: 0 0 10px rgba(0, 206, 209, 0.4);
  transform: translateY(-1px);
}

.article-tag:hover::before {
  left: 100%;
}

.article-footer {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  padding-top: var(--spacing-sm);
  border-top: 1px solid var(--border-color);
}

.read-more {
  color: var(--primary-color);
  font-weight: 600;
  font-size: 0.875rem;
  display: flex;
  align-items: center;
  gap: var(--spacing-xs);
  transition: all var(--transition-fast);
}

.article-card:hover .read-more {
  color: var(--accent-yellow);
  transform: translateX(4px);
}

/* Responsive Design - Retro-Futuristic Theme */
@media (max-width: 768px) {
  .article-title {
    font-size: 1.25rem;
  }

  .article-content {
    padding: var(--spacing-md);
  }

  .article-image {
    height: 160px;
  }

  .article-card:hover {
    transform: translateY(-2px);
  }
}

@media (max-width: 480px) {
  .article-meta {
    font-size: 0.8rem;
  }

  .article-tags {
    gap: var(--spacing-xs);
  }

  .article-tag {
    font-size: 0.7rem;
    padding: calc(var(--spacing-xs) * 0.75) var(--spacing-xs);
  }
}
</style>
