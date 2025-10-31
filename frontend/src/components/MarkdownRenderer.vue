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
import { computed, onMounted, onUpdated, onBeforeUnmount } from "vue";
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
    breaks: true, // Enable GFM line breaks (single newline = <br>)
    sanitize: false, // We'll handle sanitization if needed
    smartLists: true,
    smartypants: true,
    xhtml: false,
});

// Whitelist of trusted domains for iframe embeds
const TRUSTED_EMBED_DOMAINS = [
    "bandcamp.com",
    "youtube.com",
    "youtube-nocookie.com",
    "youtu.be",
    "vimeo.com",
    "player.vimeo.com",
    "spotify.com",
    "open.spotify.com",
    "soundcloud.com",
    "w.soundcloud.com",
    "codepen.io",
    "codesandbox.io",
    "jsfiddle.net",
];

// Per-domain sandbox configurations for iframe security
//
// SECURITY NOTE: allow-same-origin is included for trusted embed providers
// While combining allow-scripts + allow-same-origin reduces sandbox isolation,
// this is necessary for legitimate embed functionality (cookies, localStorage, cache).
// Security is maintained through:
// 1. Strict domain whitelist (only vetted, trusted providers)
// 2. Content blocklist (untrusted domains are removed entirely)
// 3. Regular security audits of whitelisted providers
//
// Embedded content from trusted providers needs same-origin access to:
// - Store player preferences and state
// - Access CDN-cached resources
// - Maintain playback position
// - Handle authentication for premium content
const IFRAME_SANDBOX_RULES = {
    // Video platforms - need same-origin for player functionality
    "youtube.com": "allow-scripts allow-same-origin allow-presentation",
    "youtube-nocookie.com": "allow-scripts allow-same-origin allow-presentation",
    "youtu.be": "allow-scripts allow-same-origin allow-presentation",
    "vimeo.com": "allow-scripts allow-same-origin allow-presentation",
    "player.vimeo.com": "allow-scripts allow-same-origin allow-presentation",

    // Audio/Music platforms - need same-origin for player functionality
    "bandcamp.com": "allow-scripts allow-same-origin allow-forms allow-popups allow-presentation", // allow-forms for player controls, allow-popups for purchase links
    "spotify.com": "allow-scripts allow-same-origin allow-presentation",
    "open.spotify.com": "allow-scripts allow-same-origin allow-presentation",
    "soundcloud.com": "allow-scripts allow-same-origin allow-presentation",
    "w.soundcloud.com": "allow-scripts allow-same-origin allow-presentation",

    // Code playgrounds - need same-origin for code execution and state
    "codepen.io": "allow-scripts allow-same-origin allow-presentation",
    "codesandbox.io": "allow-scripts allow-same-origin allow-presentation allow-popups", // allow-popups for "open in new window"
    "jsfiddle.net": "allow-scripts allow-same-origin allow-presentation",
};

// Safe CSS properties for style attribute filtering
// This whitelist is intentionally restrictive to prevent security issues:
//
// EXCLUDED PROPERTIES (and why):
// - position: Can be used to create clickjacking overlays that cover legitimate UI elements
// - z-index: Can interfere with site UI layering, placing malicious content above legitimate elements
// - opacity: Can create invisible clickjacking elements that users unknowingly interact with
// - visibility: Can hide malicious content or create deceptive UI patterns
// - overflow: Can hide content or create UI confusion by manipulating scroll behavior
//
// Only allow properties that control sizing, spacing, and basic styling without security implications
const SAFE_CSS_PROPERTIES = [
    "width",
    "height",
    "border",
    "border-width",
    "border-style",
    "border-color",
    "border-radius",
    "padding",
    "margin",
    "display",
    "max-width",
    "max-height",
    "min-width",
    "min-height",
];

// Store hook references for cleanup
let sanitizeElementHook;
let sanitizeAttributeHook;

// Configure DOMPurify hooks for iframe security
sanitizeElementHook = (node, data) => {
    // Validate iframe sources against whitelist
    if (data.tagName === "iframe") {
        const src = node.getAttribute("src");

        if (!src) {
            // Remove iframes without src
            node.parentNode?.removeChild(node);
            return;
        }

        try {
            const url = new URL(src);
            const hostname = url.hostname.toLowerCase();

            // Check if domain is in whitelist (including subdomains)
            const isWhitelisted = TRUSTED_EMBED_DOMAINS.some(
                (domain) =>
                    hostname === domain || hostname.endsWith("." + domain),
            );

            if (!isWhitelisted) {
                // Remove iframe from untrusted domain
                // eslint-disable-next-line no-console
                console.warn("Blocked iframe from untrusted domain:", hostname);
                node.parentNode?.removeChild(node);
                return;
            }

            // Remove any child content from iframes
            // Browsers ignore iframe content anyway (it's only for old browser fallback)
            // DOMPurify may reject iframes with child content as potentially malicious
            while (node.firstChild) {
                node.removeChild(node.firstChild);
            }

            // Apply domain-specific sandbox rules for enhanced security
            if (!node.hasAttribute("sandbox")) {
                // Find the base domain (e.g., "youtube.com" from "www.youtube.com")
                const baseDomain = TRUSTED_EMBED_DOMAINS.find(
                    (domain) =>
                        hostname === domain || hostname.endsWith("." + domain),
                );

                // Use domain-specific sandbox rules, or default restrictive rules
                const sandboxRules =
                    IFRAME_SANDBOX_RULES[baseDomain] ||
                    "allow-scripts allow-same-origin allow-presentation";

                node.setAttribute("sandbox", sandboxRules);
            }
        } catch {
            // Invalid URL - remove iframe
            // eslint-disable-next-line no-console
            console.warn("Blocked iframe with invalid URL:", src);
            node.parentNode?.removeChild(node);
        }
    }
};

sanitizeAttributeHook = (node, data) => {
    // Filter style attribute to only allow safe CSS properties
    if (data.attrName === "style" && data.attrValue) {
        const styles = data.attrValue.split(";").map((s) => s.trim());
        const safeStyles = styles.filter((style) => {
            const property = style.split(":")[0]?.trim().toLowerCase();
            return SAFE_CSS_PROPERTIES.includes(property);
        });

        // Update with filtered styles
        data.attrValue = safeStyles.join("; ");

        // If no safe styles remain, remove the attribute
        if (!data.attrValue) {
            data.keepAttr = false;
        }
    }
};

// Add hooks on mount
DOMPurify.addHook("uponSanitizeElement", sanitizeElementHook);
DOMPurify.addHook("uponSanitizeAttribute", sanitizeAttributeHook);

// Cache for processed content to avoid re-processing unchanged content
let lastProcessedContent = null;
let lastProcessedResult = null;

// Function to automatically wrap iframes in responsive containers
function wrapIframesInContainers(html) {
    if (!html || typeof html !== "string") return html;

    // Early exit if no iframes present
    if (!html.includes('<iframe')) return html;

    // Cache check - avoid re-processing the same content
    if (html === lastProcessedContent && lastProcessedResult) {
        return lastProcessedResult;
    }

    // Feature detection for DOMParser
    if (typeof DOMParser === 'undefined') {
        // eslint-disable-next-line no-console
        console.warn("DOMParser not available, skipping iframe wrapping");
        return html;
    }

    try {
        // Create a temporary DOM to parse and manipulate the HTML
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, "text/html");

        // Check if parsing was successful
        if (!doc || !doc.body) {
            // eslint-disable-next-line no-console
            console.warn("DOM parsing failed for iframe wrapping");
            return html;
        }

        // Find all iframe elements that aren't already wrapped
        const iframes = doc.querySelectorAll("iframe");

        // Early exit if no iframes found (shouldn't happen due to earlier check, but defensive)
        if (iframes.length === 0) return html;

        let hasChanges = false;

        iframes.forEach((iframe) => {
            // Check if iframe is already wrapped in embed-container
            const parent = iframe.parentElement;
            if (parent && parent.classList.contains("embed-container")) {
                return; // Already wrapped, skip
            }

            // Remove hardcoded width and height attributes to allow responsive CSS to work
            if (iframe.hasAttribute("width")) {
                iframe.removeAttribute("width");
                hasChanges = true;
            }
            if (iframe.hasAttribute("height")) {
                iframe.removeAttribute("height");
                hasChanges = true;
            }

            // Create wrapper div with embed-container class
            const wrapper = doc.createElement("div");
            wrapper.className = "embed-container";

            // Insert wrapper before iframe and move iframe into wrapper
            iframe.parentNode.insertBefore(wrapper, iframe);
            wrapper.appendChild(iframe);
            hasChanges = true;
        });

        // Return original HTML if no changes were made
        if (!hasChanges) return html;

        // Get the modified HTML (body content only)
        const result = doc.body.innerHTML;

        // Cache the result
        lastProcessedContent = html;
        lastProcessedResult = result;

        return result;
    } catch (error) {
        // If DOM parsing fails, return original HTML
        // eslint-disable-next-line no-console
        console.warn("Failed to wrap iframes in containers:", error);
        return html;
    }
}

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
                    "iframe", // Allow iframe embeds
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
                    // iframe attributes
                    "width",
                    "height",
                    "frameborder",
                    "allowfullscreen",
                    "allow",
                    "seamless",
                    "sandbox",
                    "style", // Filtered by hook to safe properties only
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

        // Post-process to automatically wrap iframes in responsive containers
        html = wrapIframesInContainers(html);

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

            // Enhanced security validation for internal navigation
            if (
                href.startsWith("/") &&
                !href.includes("//") &&
                isValidInternalUrl(href)
            ) {
                try {
                    const router = useRouter();
                    router.push(href);
                } catch {
                    // Router not available (likely in test environment)
                    // eslint-disable-next-line no-console
                    console.log(
                        "Router not available for navigation to:",
                        href,
                    );
                }
            }
        }
    }
}

// Validate that URL is safe for internal navigation
function isValidInternalUrl(href) {
    // Check for malicious patterns
    const maliciousPatterns = [
        /javascript:/i, // JavaScript URLs
        /data:/i, // Data URLs
        /vbscript:/i, // VBScript URLs
        /about:/i, // About URLs
        /file:/i, // File URLs
        /ftp:/i, // FTP URLs
        /%2f%2f/i, // Double-encoded slashes
        /%252f%252f/i, // Triple-encoded slashes
        /\\/, // Backslashes (Windows paths)
        /#.*?javascript:/i, // Fragment with javascript
        /\?.*?javascript:/i, // Query with javascript
    ];

    // Check against malicious patterns
    for (const pattern of maliciousPatterns) {
        if (pattern.test(href)) {
            // eslint-disable-next-line no-console
            console.warn("Blocked potentially malicious URL:", href);
            return false;
        }
    }

    // Additional validation: ensure it's a valid Vue Router path
    try {
        // Basic path validation - should be alphanumeric, slashes, hyphens, underscores, and common URL characters
        const validPathPattern = /^\/[a-zA-Z0-9/_\-.~!$&'()*+,;=:@%]*$/;
        return validPathPattern.test(href);
    } catch (error) {
        // eslint-disable-next-line no-console
        console.warn("URL validation error:", error);
        return false;
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

// Clean up DOMPurify hooks and cache to prevent memory leaks
onBeforeUnmount(() => {
    DOMPurify.removeHook("uponSanitizeElement");
    DOMPurify.removeHook("uponSanitizeAttribute");

    // Clear iframe wrapping cache
    lastProcessedContent = null;
    lastProcessedResult = null;
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
    background-image:
        var(--gradient-retro-secondary), var(--gradient-retro-primary);
    background-origin: border-box;
    background-clip: text, border-box;
    padding-bottom: 0.5rem;
    margin-bottom: 1.5rem;
}

.markdown-content h2 {
    font-size: 1.875rem;
    border-bottom: 2px solid transparent;
    background-image:
        var(--gradient-retro-secondary),
        linear-gradient(90deg, var(--primary-color), transparent);
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
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: linear-gradient(
        90deg,
        transparent,
        rgba(255, 105, 180, 0.1),
        transparent
    );
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
    content: "";
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
    content: "";
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
    content: "";
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 1px;
    background: linear-gradient(
        90deg,
        var(--primary-color),
        transparent,
        var(--primary-color)
    );
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

/* Iframe Embeds - Retro-Futuristic (fallback for unwrapped iframes) */
.markdown-content iframe {
    width: 100%;
    max-width: 700px; /* Match embed container width */
    aspect-ratio: 16 / 9; /* Modern CSS aspect ratio */
    height: 394px; /* Fallback for older browsers (16:9 ratio for 700px width) */
    border: 1px solid var(--border-color);
    border-radius: var(--radius-md);
    margin: 2rem auto; /* Center standalone iframes */
    box-shadow: var(--shadow-md);
    display: block; /* Ensure block display for centering */
    position: relative;
    background: var(--light-bg);
    transition: all var(--transition-fast);
}

/* Modern browsers that support aspect-ratio don't need hardcoded height */
@supports (aspect-ratio: 16 / 9) {
    .markdown-content iframe {
        height: auto;
    }
}

.markdown-content iframe:hover {
    box-shadow:
        var(--shadow-lg),
        0 0 25px rgba(255, 105, 180, 0.2);
    transform: translateY(-2px);
}

/* Removed duplicate embed container styles - now handled in global styles below */

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
    content: "";
    position: absolute;
    top: 0;
    left: -100%;
    width: 100%;
    height: 100%;
    background: linear-gradient(
        90deg,
        transparent,
        rgba(255, 255, 255, 0.4),
        transparent
    );
    animation: shimmer 3s ease-in-out infinite;
}

@keyframes shimmer {
    0% {
        left: -100%;
    }
    100% {
        left: 100%;
    }
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
    content: "";
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: linear-gradient(
        90deg,
        var(--accent-orange),
        #ff8c00,
        var(--accent-orange)
    );
    animation: errorPulse 2s ease-in-out infinite;
}

.markdown-content .error::after {
    content: "⚠";
    position: absolute;
    top: 1rem;
    right: 1rem;
    font-size: 1.5rem;
    color: var(--accent-orange);
    opacity: 0.6;
}

@keyframes errorPulse {
    0%,
    100% {
        opacity: 0.7;
    }
    50% {
        opacity: 1;
    }
}

</style>

<!-- Global CSS for dynamically created embed containers (not scoped) -->
<style>
/* Global embed container styles - must not be scoped for dynamic content */
.embed-container {
    position: relative;
    padding-bottom: 56.25%; /* 16:9 aspect ratio */
    height: 0;
    overflow: hidden;
    width: 100%;
    max-width: 700px; /* Optimal viewing width for YouTube videos */
    margin: 2rem auto; /* Center the container with more vertical spacing */
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    background: var(--light-bg);
    border: 1px solid var(--border-color);
    transition: all var(--transition-fast);
    display: block;
}

.embed-container:hover {
    box-shadow: var(--shadow-lg), 0 0 25px rgba(255, 105, 180, 0.2);
    transform: translateY(-2px);
}

.embed-container iframe {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    margin: 0;
    border-radius: var(--radius-md);
    border: none; /* Remove default iframe border */
}

/* Responsive adjustments for global embed containers */
@media (max-width: 768px) {
    .embed-container {
        max-width: 100%;
        margin: 1.5rem auto;
    }
}

@media (max-width: 480px) {
    .embed-container {
        margin: 1rem auto;
    }
}
</style>
