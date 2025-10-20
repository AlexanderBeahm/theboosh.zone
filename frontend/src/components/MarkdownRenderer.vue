<template>
    <div
        class="markdown-content"
        v-html="renderedContent"
        @click="handleLinkClick"
    ></div>
</template>

<script setup>
import { computed, onMounted, onUpdated } from "vue";
import { marked } from "marked";
import hljs from "highlight.js/lib/core";

// Import commonly used languages for syntax highlighting
import javascript from "highlight.js/lib/languages/javascript";
import typescript from "highlight.js/lib/languages/typescript";
import python from "highlight.js/lib/languages/python";
import bash from "highlight.js/lib/languages/bash";
import json from "highlight.js/lib/languages/json";
import xml from "highlight.js/lib/languages/xml";
import css from "highlight.js/lib/languages/css";
import sql from "highlight.js/lib/languages/sql";
import perl from "highlight.js/lib/languages/perl";
import markdown from "highlight.js/lib/languages/markdown";

// Import highlight.js theme
import "highlight.js/styles/github-dark.css";

// Register languages
hljs.registerLanguage("javascript", javascript);
hljs.registerLanguage("js", javascript);
hljs.registerLanguage("typescript", typescript);
hljs.registerLanguage("ts", typescript);
hljs.registerLanguage("python", python);
hljs.registerLanguage("bash", bash);
hljs.registerLanguage("shell", bash);
hljs.registerLanguage("json", json);
hljs.registerLanguage("xml", xml);
hljs.registerLanguage("html", xml);
hljs.registerLanguage("css", css);
hljs.registerLanguage("sql", sql);
hljs.registerLanguage("perl", perl);
hljs.registerLanguage("markdown", markdown);
hljs.registerLanguage("md", markdown);

// Props
const props = defineProps({
    content: {
        type: String,
        required: true,
    },
    sanitize: {
        type: Boolean,
        default: true,
    },
});

// Configure marked
const renderer = new marked.Renderer();

// Custom renderer for code blocks with syntax highlighting
// Note: marked.js passes a token object in newer versions
renderer.code = function (token) {
    // Handle both old (string) and new (object) formats
    const code = typeof token === "string" ? token : token.text;
    const language = typeof token === "string" ? arguments[1] : token.lang;

    if (language && hljs.getLanguage(language)) {
        try {
            const highlighted = hljs.highlight(code, { language }).value;
            return `<pre><code class="hljs language-${language}">${highlighted}</code></pre>`;
        } catch (err) {
            console.warn("Syntax highlighting failed:", err);
        }
    }

    // Fallback for unknown languages or highlighting errors
    const escaped = code.replace(/[&<>"']/g, (char) => {
        const entities = {
            "&": "&amp;",
            "<": "&lt;",
            ">": "&gt;",
            '"': "&quot;",
            "'": "&#x27;",
        };
        return entities[char];
    });

    return `<pre><code class="hljs">${escaped}</code></pre>`;
};

// Custom renderer for links to handle external links properly
// Note: marked.js passes a token object in newer versions
renderer.link = function (token) {
    // Handle both old (string) and new (object) formats
    const href = typeof token === "string" ? token : token.href;
    const title = typeof token === "string" ? arguments[1] : token.title;
    const text = typeof token === "string" ? arguments[2] : token.text;

    let linkTarget = "";
    let linkRel = "";

    // Check if it's an external link
    if (href && (href.startsWith("http://") || href.startsWith("https://"))) {
        linkTarget = ' target="_blank"';
        linkRel = ' rel="noopener noreferrer"';
    }

    const titleAttr = title ? ` title="${title}"` : "";
    return `<a href="${href}"${titleAttr}${linkTarget}${linkRel}>${text}</a>`;
};

// Custom renderer for images with better handling
// Note: marked.js passes a token object in newer versions
renderer.image = function (token) {
    // Handle both old (string) and new (object) formats
    const href = typeof token === "string" ? token : token.href;
    const title = typeof token === "string" ? arguments[1] : token.title;
    const text = typeof token === "string" ? arguments[2] : token.text;

    const titleAttr = title ? ` title="${title}"` : "";
    const altAttr = text ? ` alt="${text}"` : "";
    return `<img src="${href}"${altAttr}${titleAttr} loading="lazy" class="article-image" />`;
};

// Configure marked options
marked.setOptions({
    renderer: renderer,
    highlight: function (code, language) {
        if (language && hljs.getLanguage(language)) {
            try {
                return hljs.highlight(code, { language }).value;
            } catch (err) {
                console.warn("Syntax highlighting failed:", err);
            }
        }
        return code;
    },
    langPrefix: "hljs language-",
    pedantic: false,
    gfm: true, // GitHub Flavored Markdown
    breaks: false,
    sanitize: false, // We'll handle sanitization if needed
    smartLists: true,
    smartypants: true,
    xhtml: false,
});

// Computed property for rendered content
const renderedContent = computed(() => {
    if (!props.content) return "";

    try {
        let html = marked(props.content);

        // Basic sanitization if enabled
        if (props.sanitize) {
            // Remove potentially dangerous elements and attributes
            html = html.replace(
                /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
                "",
            );
            html = html.replace(
                /<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi,
                "",
            );
            html = html.replace(/on\w+="[^"]*"/gi, ""); // Remove event handlers
            html = html.replace(/javascript:/gi, ""); // Remove javascript: urls
        }

        return html;
    } catch (error) {
        console.error("Markdown rendering failed:", error);
        return `<div class="error">Failed to render markdown content</div>`;
    }
});

// Handle link clicks for internal navigation
function handleLinkClick(event) {
    const target = event.target;

    if (target.tagName === "A") {
        const href = target.getAttribute("href");

        // Handle internal links (relative URLs)
        if (
            href &&
            !href.startsWith("http://") &&
            !href.startsWith("https://") &&
            !href.startsWith("mailto:")
        ) {
            event.preventDefault();

            // Use Vue Router for internal navigation
            if (href.startsWith("/")) {
                // Import router and navigate
                const router = useRouter();
                router.push(href);
            }
        }
    }
}

// Apply syntax highlighting after component mounts and updates
function highlightCode() {
    // Find all code blocks and apply highlighting
    const codeBlocks = document.querySelectorAll(
        ".markdown-content pre code:not(.hljs)",
    );
    codeBlocks.forEach((block) => {
        hljs.highlightElement(block);
    });
}

onMounted(() => {
    highlightCode();
});

onUpdated(() => {
    highlightCode();
});
</script>

<style scoped>
.markdown-content {
    line-height: 1.6;
    color: var(--text-color);
}

/* Typography */
.markdown-content h1,
.markdown-content h2,
.markdown-content h3,
.markdown-content h4,
.markdown-content h5,
.markdown-content h6 {
    margin-top: 2rem;
    margin-bottom: 1rem;
    font-weight: 600;
    line-height: 1.25;
    color: var(--primary-color);
}

.markdown-content h1 {
    font-size: 2.25rem;
    border-bottom: 2px solid var(--border-color);
    padding-bottom: 0.5rem;
}

.markdown-content h2 {
    font-size: 1.875rem;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 0.25rem;
}

.markdown-content h3 {
    font-size: 1.5rem;
}

.markdown-content h4 {
    font-size: 1.25rem;
}

.markdown-content h5 {
    font-size: 1.125rem;
}

.markdown-content h6 {
    font-size: 1rem;
}

/* Paragraphs and text */
.markdown-content p {
    margin-bottom: 1rem;
}

.markdown-content strong {
    font-weight: 600;
}

.markdown-content em {
    font-style: italic;
}

/* Links */
.markdown-content a {
    color: var(--primary-color);
    text-decoration: none;
    border-bottom: 1px solid transparent;
    transition: border-bottom-color var(--transition-fast);
}

.markdown-content a:hover {
    border-bottom-color: var(--primary-color);
}

/* Lists */
.markdown-content ul,
.markdown-content ol {
    margin-bottom: 1rem;
    padding-left: 2rem;
}

.markdown-content li {
    margin-bottom: 0.5rem;
}

.markdown-content li > ul,
.markdown-content li > ol {
    margin-top: 0.5rem;
    margin-bottom: 0.5rem;
}

/* Code */
.markdown-content code {
    background-color: var(--code-bg);
    color: var(--code-text);
    padding: 0.125rem 0.25rem;
    border-radius: var(--radius-sm);
    font-family: "Monaco", "Menlo", "Ubuntu Mono", monospace;
    font-size: 0.875rem;
}

.markdown-content pre {
    background-color: var(--code-bg);
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    overflow-x: auto;
    padding: 1rem;
    margin: 1rem 0;
}

.markdown-content pre code {
    background-color: transparent;
    padding: 0;
    border-radius: 0;
    font-size: 0.875rem;
    line-height: 1.45;
}

/* Blockquotes */
.markdown-content blockquote {
    border-left: 4px solid var(--primary-color);
    background-color: var(--light-bg);
    padding: 1rem;
    margin: 1rem 0;
    font-style: italic;
}

.markdown-content blockquote p:last-child {
    margin-bottom: 0;
}

/* Tables */
.markdown-content table {
    border-collapse: collapse;
    width: 100%;
    margin: 1rem 0;
    border: 1px solid var(--border-color);
}

.markdown-content th,
.markdown-content td {
    border: 1px solid var(--border-color);
    padding: 0.75rem;
    text-align: left;
}

.markdown-content th {
    background-color: var(--light-bg);
    font-weight: 600;
}

.markdown-content tbody tr:nth-child(even) {
    background-color: var(--light-bg);
}

/* Images */
.markdown-content .article-image {
    max-width: 100%;
    height: auto;
    border-radius: var(--radius-md);
    margin: 1rem 0;
    box-shadow: var(--shadow-sm);
}

/* Horizontal rules */
.markdown-content hr {
    border: none;
    border-top: 2px solid var(--border-color);
    margin: 2rem 0;
}

/* Error state */
.markdown-content .error {
    background-color: var(--error-bg);
    color: var(--error-text);
    padding: 1rem;
    border-radius: var(--radius-md);
    border: 1px solid var(--error-border);
    margin: 1rem 0;
}
</style>

<style>
/* Global styles for syntax highlighting (not scoped) */
.hljs {
    background: #0d1117 !important;
    color: #c9d1d9 !important;
    border-radius: 6px;
}

/* Ensure code blocks have proper styling */
.markdown-content pre.hljs {
    background: #0d1117;
    border: 1px solid #30363d;
}
</style>
