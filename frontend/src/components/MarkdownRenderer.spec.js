import { describe, it, expect } from "vitest";
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
});
