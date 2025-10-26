<template>
  <!-- v-html is safe here: content is sanitized with DOMPurify -->
  <!-- eslint-disable vue/no-v-html -->
  <div
    class="markdown-content"
    @click="handleLinkClick"
    v-html="renderedContent"
  />
  <!-- eslint-enable vue/no-v-html -->
</template>

<script setup>
import { computed, onMounted, onUpdated } from "vue";
import { useRouter } from "vue-router";
import { marked } from "marked";
import DOMPurify from "dompurify";
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
        } catch {
            // Syntax highlighting failed, fall back to escaped code
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
            } catch {
                // Syntax highlighting failed, return plain code
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

        // Sanitize with DOMPurify if enabled
        if (props.sanitize) {
            html = DOMPurify.sanitize(html, {
                ALLOWED_TAGS: [
                    // Typography
                    "p",
                    "br",
                    "strong",
                    "em",
                    "u",
                    "s",
                    "del",
                    "ins",
                    "sub",
                    "sup",
                    // Headings
                    "h1",
                    "h2",
                    "h3",
                    "h4",
                    "h5",
                    "h6",
                    // Lists
                    "ul",
                    "ol",
                    "li",
                    // Links and media
                    "a",
                    "img",
                    // Code
                    "code",
                    "pre",
                    "span",
                    // Quotes and blocks
                    "blockquote",
                    "hr",
                    // Tables
                    "table",
                    "thead",
                    "tbody",
                    "tfoot",
                    "tr",
                    "th",
                    "td",
                    // Divs for error messages and structure
                    "div",
                ],
                ALLOWED_ATTR: [
                    // Link attributes
                    "href",
                    "target",
                    "rel",
                    // Image attributes
                    "src",
                    "alt",
                    "title",
                    "loading",
                    // Code highlighting classes (critical!)
                    "class",
                    // Table alignment
                    "align",
                ],
                /*eslint-disable no-useless-escape*/
                ALLOWED_URI_REGEXP:
                    /^(?:(?:(?:f|ht)tps?|mailto|tel|callto|sms|cid|xmpp|data):|[^a-z]|[a-z+.\-]+(?:[^a-z+.\-:]|$))/i,
                /*eslint-enable no-useless-escape*/
                KEEP_CONTENT: true,
                RETURN_TRUSTED_TYPE: false,
            });
        }

        return html;
    } catch {
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
    color: var(--text-primary);
}

/* Typography - Retro-Futuristic */
.markdown-content h1,
.markdown-content h2,
.markdown-content h3,
.markdown-content h4,
.markdown-content h5,
.markdown-content h6 {
    margin-top: 2rem;
    margin-bottom: 1rem;
    font-weight: 700;
    line-height: 1.25;
    background: var(--gradient-retro-secondary);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
    text-shadow: 0 0 20px rgba(184, 188, 200, 0.3);
    position: relative;
}

.markdown-content h1 {
    font-size: 2.25rem;
    border-bottom: 3px solid transparent;
    background-image: var(--gradient-retro-secondary), var(--gradient-retro-primary);
    background-origin: border-box;
    background-clip: text, border-box;
    padding-bottom: 0.5rem;
    margin-bottom: 1.5rem;
}

.markdown-content h2 {
    font-size: 1.875rem;
    border-bottom: 2px solid transparent;
    background-image: var(--gradient-retro-secondary), linear-gradient(90deg, var(--primary-color), transparent);
    background-origin: border-box;
    background-clip: text, border-box;
    padding-bottom: 0.25rem;
    margin-bottom: 1.25rem;
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
    transition: all var(--transition-fast);
    position: relative;
    padding: 0.125rem 0.25rem;
    border-radius: var(--radius-sm);
}

.markdown-content a::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(90deg, transparent, rgba(255, 105, 180, 0.1), transparent);
    border-radius: var(--radius-sm);
    opacity: 0;
    transition: opacity var(--transition-fast);
    z-index: -1;
}

.markdown-content a:hover {
    border-bottom-color: var(--primary-color);
    color: var(--primary-color);
    text-shadow: 0 0 10px rgba(255, 105, 180, 0.5);
}

.markdown-content a:hover::before {
    opacity: 1;
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
    border-left: 4px solid transparent;
    background: var(--light-bg);
    padding: 1.5rem;
    margin: 1.5rem 0;
    font-style: italic;
    position: relative;
    border-radius: 0 var(--radius-md) var(--radius-md) 0;
    overflow: hidden;
}

.markdown-content blockquote::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    width: 4px;
    height: 100%;
    background: var(--gradient-retro-primary);
    border-radius: var(--radius-sm);
}

.markdown-content blockquote::after {
    content: '"';
    position: absolute;
    top: 0.5rem;
    right: 1rem;
    font-size: 3rem;
    color: var(--primary-color);
    opacity: 0.3;
    font-family: serif;
    line-height: 1;
}

.markdown-content blockquote p:last-child {
    margin-bottom: 0;
}

.markdown-content blockquote:hover {
    background: rgba(255, 105, 180, 0.05);
    box-shadow: 0 0 20px rgba(255, 105, 180, 0.1);
}

/* Tables */
.markdown-content table {
    border-collapse: collapse;
    width: 100%;
    margin: 1.5rem 0;
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    overflow: hidden;
    box-shadow: var(--shadow-sm);
    position: relative;
}

.markdown-content table::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--gradient-retro-primary);
}

.markdown-content th,
.markdown-content td {
    border: 1px solid var(--border-color);
    padding: 0.875rem 1rem;
    text-align: left;
    transition: background-color var(--transition-fast);
}

.markdown-content th {
    background: var(--light-bg);
    font-weight: 600;
    color: var(--text-primary);
    text-transform: uppercase;
    letter-spacing: 0.025em;
    font-size: 0.875rem;
    position: relative;
}

.markdown-content th::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 1px;
    background: linear-gradient(90deg, var(--primary-color), transparent, var(--primary-color));
}

.markdown-content tbody tr:nth-child(even) {
    background-color: var(--light-bg);
}

.markdown-content tbody tr:hover {
    background-color: rgba(255, 105, 180, 0.05);
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
    height: 3px;
    background: var(--gradient-retro-primary);
    margin: 3rem 0;
    border-radius: var(--radius-full);
    position: relative;
    overflow: hidden;
}

.markdown-content hr::after {
    content: '';
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.4), transparent);
    animation: shimmer 3s ease-in-out infinite;
}

@keyframes shimmer {
    0% { left: -100%; }
    100% { left: 100%; }
}

/* Error state */
.markdown-content .error {
    background: var(--error-bg);
    color: var(--error-text);
    padding: 1.5rem;
    border-radius: var(--radius-md);
    border: 1px solid var(--error-border);
    margin: 1.5rem 0;
    position: relative;
    overflow: hidden;
    box-shadow: 0 0 20px rgba(255, 69, 0, 0.2);
}

.markdown-content .error::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(90deg, var(--accent-orange), #FF8C00, var(--accent-orange));
    animation: errorPulse 2s ease-in-out infinite;
}

.markdown-content .error::after {
    content: '⚠';
    position: absolute;
    top: 1rem;
    right: 1rem;
    font-size: 1.5rem;
    color: var(--accent-orange);
    opacity: 0.6;
}

@keyframes errorPulse {
    0%, 100% { opacity: 0.7; }
    50% { opacity: 1; }
}
</style>
