# Icon System

This project uses **unplugin-icons** with **Iconify** for a comprehensive, tree-shaken icon system.

## Using Icons

### Direct Import (Recommended)
```vue
<script setup>
import IconGithub from '~icons/simple-icons/github';
import IconUser from '~icons/heroicons/user';
</script>

<template>
  <IconGithub class="w-6 h-6" />
  <IconUser class="text-primary" />
</template>
```

### With BaseIcon Wrapper
```vue
<script setup>
import BaseIcon from '@/components/icons/BaseIcon.vue';
import IconGithub from '~icons/simple-icons/github';
</script>

<template>
  <BaseIcon :icon="IconGithub" size="lg" color="var(--primary-color)" />
</template>
```

## Available Icon Collections

- **`simple-icons/*`** - Brand logos (GitHub, LinkedIn, X, Vue, Docker, etc.)
- **`heroicons/*`** - UI icons (outline/solid variants)
- **`lucide/*`** - General purpose icons

## BaseIcon Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `icon` | Object | required | The imported icon component |
| `size` | String | 'md' | Size: 'xs', 'sm', 'md', 'lg', 'xl' |
| `color` | String | 'currentColor' | Icon color (CSS value) |
| `customClass` | String | '' | Additional CSS classes |

## Size Reference

- **xs**: 0.75rem (12px)
- **sm**: 1rem (16px)
- **md**: 1.25rem (20px)
- **lg**: 1.5rem (24px)
- **xl**: 2rem (32px)

## Finding Icons

Browse available icons at:
- [Simple Icons](https://icon-sets.iconify.design/simple-icons/) - Brand logos
- [Heroicons](https://icon-sets.iconify.design/heroicons/) - UI icons
- [Lucide](https://icon-sets.iconify.design/lucide/) - General icons
- [All Iconify Collections](https://icon-sets.iconify.design/)

## Current Project Icons

### Social Media
- GitHub: `~icons/simple-icons/github`
- LinkedIn: `~icons/simple-icons/linkedin`
- X (Twitter): `~icons/simple-icons/x`

### Technology Stack
- Perl: `~icons/simple-icons/perl`
- Vue.js: `~icons/simple-icons/vuedotjs`
- PostgreSQL: `~icons/simple-icons/postgresql`
- Docker: `~icons/simple-icons/docker`

## Adding New Icons

1. Find the icon at [Iconify](https://icon-sets.iconify.design/)
2. Import in your component:
   ```vue
   import IconName from '~icons/collection-name/icon-name';
   ```
3. Use directly or with BaseIcon wrapper
4. Icons are automatically tree-shaken - only used icons are bundled

## CSS Integration

Icons inherit CSS custom properties from the project theme:

```css
/* Use theme colors */
.icon-primary { color: var(--primary-color); }
.icon-secondary { color: var(--text-secondary); }

/* Custom hover effects */
.icon-hover:hover {
  transform: scale(1.1);
  transition: transform var(--transition-fast);
}
```

## Bundle Size

- **Base overhead**: ~2KB (icon system)
- **Per icon**: ~300 bytes - 1KB
- **Tree-shaking**: Only used icons are bundled
- **Zero runtime**: Icons compiled at build time

## Examples

### Social Link with Icon
```vue
<template>
  <a href="https://github.com/username" class="social-link">
    <IconGithub class="link-icon" />
    GitHub
  </a>
</template>

<script setup>
import IconGithub from '~icons/simple-icons/github';
</script>

<style scoped>
.social-link {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.link-icon {
  width: 1.25rem;
  height: 1.25rem;
  transition: transform var(--transition-fast);
}

.social-link:hover .link-icon {
  transform: scale(1.1);
}
</style>
```

### Technology Badge
```vue
<template>
  <div class="tech-badge">
    <div class="tech-icon-wrapper">
      <IconVue class="tech-icon" />
    </div>
    <span>Vue 3</span>
  </div>
</template>

<script setup>
import IconVue from '~icons/simple-icons/vuedotjs';
</script>

<style scoped>
.tech-badge {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem 1rem;
  background: rgba(255, 105, 180, 0.1);
  border-radius: var(--radius-md);
  border: 1px solid rgba(255, 105, 180, 0.2);
}

.tech-icon-wrapper {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  background: var(--darker-bg);
  border-radius: var(--radius-md);
}

.tech-icon {
  width: 1.5rem;
  height: 1.5rem;
  color: var(--primary-color);
}
</style>
```