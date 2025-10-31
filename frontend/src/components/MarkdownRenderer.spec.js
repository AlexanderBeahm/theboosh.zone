import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import MarkdownRenderer from "./MarkdownRenderer.vue";

describe("MarkdownRenderer", () => {
    it("renders markdown content as HTML", () => {
        const wrapper = mount(MarkdownRenderer, {
            props: {
                content: "# Hello World\n\nThis is **bold** text.",
            },
        });

        expect(wrapper.html()).toContain("<h1");
        expect(wrapper.html()).toContain("Hello World");
        expect(wrapper.html()).toContain("<strong>");
        expect(wrapper.html()).toContain("bold");
    });

    it("renders code blocks with syntax highlighting", () => {
        const wrapper = mount(MarkdownRenderer, {
            props: {
                content: "```javascript\nconst x = 42;\n```",
            },
        });

        // Get the rendered HTML from the markdown-content div
        const markdownDiv = wrapper.find(".markdown-content");
        const innerHTML = markdownDiv.element.innerHTML;

        expect(innerHTML).toContain("<pre");
        expect(innerHTML).toContain("<code");
    });

    it("renders lists correctly", () => {
        const wrapper = mount(MarkdownRenderer, {
            props: {
                content: "- Item 1\n- Item 2\n- Item 3",
            },
        });

        expect(wrapper.html()).toContain("<ul");
        expect(wrapper.html()).toContain("<li");
        expect(wrapper.text()).toContain("Item 1");
    });

    it("renders links", () => {
        const wrapper = mount(MarkdownRenderer, {
            props: {
                content: "[Link text](https://example.com)",
            },
        });

        // Get the rendered HTML from v-html content
        const markdownDiv = wrapper.find(".markdown-content");
        const innerHTML = markdownDiv.element.innerHTML;

        // Check for link in the HTML
        expect(innerHTML).toContain("<a");
        expect(innerHTML).toContain('href="https://example.com"');
        expect(innerHTML).toContain("Link text");
    });

    it('adds target="_blank" to external links', () => {
        const wrapper = mount(MarkdownRenderer, {
            props: {
                content: "[External](https://example.com)",
            },
        });

        // Get the rendered HTML from v-html content
        const markdownDiv = wrapper.find(".markdown-content");
        const innerHTML = markdownDiv.element.innerHTML;

        // Check for target and rel attributes in the HTML
        expect(innerHTML).toContain('target="_blank"');
        expect(innerHTML).toContain("noopener");
    });

    it("handles empty content", () => {
        const wrapper = mount(MarkdownRenderer, {
            props: {
                content: "",
            },
        });

        expect(wrapper.html()).toBeTruthy();
    });

    // Security tests for XSS prevention
    describe("XSS Prevention", () => {
        it("blocks javascript: URLs in internal navigation", async () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content: "[Evil Link](/javascript:alert('xss'))",
                },
            });

            // Find the link and simulate a click
            const markdownDiv = wrapper.find(".markdown-content");
            const link = markdownDiv.find("a");

            // Mock console.warn to check if warning is logged
            const consoleWarnSpy = vi
                .spyOn(console, "warn")
                .mockImplementation(() => {});

            // Trigger click event
            await link.trigger("click");

            // Verify that the malicious URL was blocked (warning should be logged)
            expect(consoleWarnSpy).toHaveBeenCalledWith(
                "Blocked potentially malicious URL:",
                expect.any(String),
            );

            consoleWarnSpy.mockRestore();
        });

        it("blocks data: URLs in internal navigation", async () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content:
                        "[Data URL](/data:text/html,<script>alert('xss')</script>)",
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const link = markdownDiv.find("a");

            const consoleWarnSpy = vi
                .spyOn(console, "warn")
                .mockImplementation(() => {});

            await link.trigger("click");

            expect(consoleWarnSpy).toHaveBeenCalledWith(
                "Blocked potentially malicious URL:",
                expect.any(String),
            );

            consoleWarnSpy.mockRestore();
        });

        it("blocks URLs with double slashes in internal navigation", async () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content: "[Double Slash](//evil.com/path)",
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const link = markdownDiv.find("a");

            // This should not trigger our XSS validation since it doesn't start with /
            // But it also won't be processed as internal navigation
            await link.trigger("click");

            // The link should be treated as external (not prevented)
            expect(link.attributes("href")).toBe("//evil.com/path");
        });

        it("allows safe internal URLs", async () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content: "[Safe Link](/articles/my-post)",
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const link = markdownDiv.find("a");

            const consoleWarnSpy = vi
                .spyOn(console, "warn")
                .mockImplementation(() => {});
            const consoleLogSpy = vi
                .spyOn(console, "log")
                .mockImplementation(() => {});

            await link.trigger("click");

            // No warning should be logged for safe URLs
            expect(consoleWarnSpy).not.toHaveBeenCalledWith(
                "Blocked potentially malicious URL:",
                expect.any(String),
            );

            // Should log router not available in test environment
            expect(consoleLogSpy).toHaveBeenCalledWith(
                "Router not available for navigation to:",
                "/articles/my-post",
            );

            consoleWarnSpy.mockRestore();
            consoleLogSpy.mockRestore();
        });

        it("sanitizes malicious content through DOMPurify", () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content: '<script>alert("xss")</script><p>Safe content</p>',
                    sanitize: true,
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const innerHTML = markdownDiv.element.innerHTML;

            // Script tags should be removed by DOMPurify
            expect(innerHTML).not.toContain("<script>");
            expect(innerHTML).not.toContain("alert");
            // Safe content should remain
            expect(innerHTML).toContain("Safe content");
        });
    });

    // Iframe embed security tests
    describe("Iframe Embeds", () => {
        it("allows iframes from whitelisted domains (YouTube)", () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content:
                        '<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"></iframe>',
                    sanitize: true,
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const innerHTML = markdownDiv.element.innerHTML;

            // Iframe should be present
            expect(innerHTML).toContain("<iframe");
            expect(innerHTML).toContain("youtube.com");
        });

        it("blocks iframes from non-whitelisted domains", () => {
            const consoleWarnSpy = vi
                .spyOn(console, "warn")
                .mockImplementation(() => {});

            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content: '<iframe src="https://evil.com/embed"></iframe>',
                    sanitize: true,
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const innerHTML = markdownDiv.element.innerHTML;

            // Warning should be logged
            expect(consoleWarnSpy).toHaveBeenCalledWith(
                "Blocked iframe from untrusted domain:",
                "evil.com",
            );

            // Iframe should be removed
            expect(innerHTML).not.toContain("evil.com");

            consoleWarnSpy.mockRestore();
        });

        it("applies correct sandbox attributes for YouTube", () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content:
                        '<iframe src="https://www.youtube.com/embed/test"></iframe>',
                    sanitize: true,
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const innerHTML = markdownDiv.element.innerHTML;

            // Should have sandbox with necessary permissions for YouTube player
            expect(innerHTML).toContain("sandbox=");
            expect(innerHTML).toContain("allow-scripts");
            expect(innerHTML).toContain("allow-same-origin");
            expect(innerHTML).toContain("allow-presentation");
        });

        it("applies correct sandbox attributes for Bandcamp", () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content:
                        '<iframe src="https://bandcamp.com/EmbeddedPlayer/album=1234"></iframe>',
                    sanitize: true,
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const innerHTML = markdownDiv.element.innerHTML;

            // Bandcamp should have allow-forms for player controls, allow-popups for purchase links, and allow-same-origin for player
            expect(innerHTML).toContain("sandbox=");
            expect(innerHTML).toContain("allow-scripts");
            expect(innerHTML).toContain("allow-same-origin");
            expect(innerHTML).toContain("allow-forms");
            expect(innerHTML).toContain("allow-popups");
            expect(innerHTML).toContain("allow-presentation");
        });

        it("blocks iframes with invalid URLs", () => {
            const consoleWarnSpy = vi
                .spyOn(console, "warn")
                .mockImplementation(() => {});

            // eslint-disable-next-line no-unused-vars
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content: '<iframe src="not-a-valid-url"></iframe>',
                    sanitize: true,
                },
            });

            // Warning should be logged for invalid URL
            expect(consoleWarnSpy).toHaveBeenCalledWith(
                "Blocked iframe with invalid URL:",
                "not-a-valid-url",
            );

            consoleWarnSpy.mockRestore();
        });
    });

    // Line breaks test
    describe("Line Breaks", () => {
        it("renders single newlines as <br> with breaks: true", () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content: "Line 1\nLine 2",
                    sanitize: true,
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const innerHTML = markdownDiv.element.innerHTML;

            // Single newline should create a <br> tag with GFM breaks enabled
            expect(innerHTML).toContain("Line 1");
            expect(innerHTML).toContain("Line 2");
        });
    });

    // Style attribute filtering tests
    describe("Style Attribute Filtering", () => {
        it("keeps safe CSS properties in style attribute", () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content:
                        '<div style="width: 100px; height: 50px; padding: 10px;">Safe styles</div>',
                    sanitize: true,
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const innerHTML = markdownDiv.element.innerHTML;

            // Safe properties should be kept
            expect(innerHTML).toContain("width");
            expect(innerHTML).toContain("height");
            expect(innerHTML).toContain("padding");
        });

        it("removes dangerous CSS properties from style attribute", () => {
            const wrapper = mount(MarkdownRenderer, {
                props: {
                    content:
                        '<div style="width: 100px; position: absolute; z-index: 9999; opacity: 0;">Dangerous styles</div>',
                    sanitize: true,
                },
            });

            const markdownDiv = wrapper.find(".markdown-content");
            const innerHTML = markdownDiv.element.innerHTML;

            // Safe property should be kept
            expect(innerHTML).toContain("width");

            // Dangerous properties should be removed
            expect(innerHTML).not.toContain("position");
            expect(innerHTML).not.toContain("z-index");
            expect(innerHTML).not.toContain("opacity: 0");
        });
    });
});
