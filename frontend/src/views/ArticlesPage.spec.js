import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import axios from "axios";
import ArticlesPage from "./ArticlesPage.vue";

vi.mock("axios");

const mockArticles = [
    {
        id: 1,
        title: "Article 1",
        slug: "article-1",
        excerpt: "Excerpt 1",
        tags: [],
    },
    {
        id: 2,
        title: "Article 2",
        slug: "article-2",
        excerpt: "Excerpt 2",
        tags: [],
    },
];

describe("ArticlesPage", () => {
    let router;

    beforeEach(() => {
        router = createRouter({
            history: createMemoryHistory(),
            routes: [
                {
                    path: "/articles",
                    name: "Articles",
                    component: ArticlesPage,
                },
            ],
        });
        vi.clearAllMocks();
    });

    it("fetches and displays articles", async () => {
        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                articles: mockArticles,
                pagination: { has_next: false, has_prev: false },
            },
        });

        await router.push("/articles");
        await router.isReady();

        const wrapper = mount(ArticlesPage, {
            global: { plugins: [router] },
        });

        await flushPromises();

        expect(axios.get).toHaveBeenCalledWith(
            "/api/articles",
            expect.any(Object),
        );
        expect(wrapper.text()).toContain("Article 1");
        expect(wrapper.text()).toContain("Article 2");
    });

    it("shows loading state while fetching", () => {
        axios.get.mockImplementation(() => new Promise(() => {}));

        const wrapper = mount(ArticlesPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.text()).toMatch(/loading/i);
    });

    it("shows error state on fetch failure", async () => {
        axios.get.mockRejectedValueOnce(new Error("Network error"));

        await router.push("/articles");
        await router.isReady();

        const wrapper = mount(ArticlesPage, {
            global: { plugins: [router] },
        });

        await flushPromises();

        expect(wrapper.text()).toMatch(/error|failed/i);
    });

    it("filters articles by tag from query param", async () => {
        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                articles: [mockArticles[0]],
                pagination: { has_next: false, has_prev: false },
            },
        });

        await router.push("/articles?tag=javascript");
        await router.isReady();

        mount(ArticlesPage, {
            global: { plugins: [router] },
        });

        await flushPromises();

        expect(axios.get).toHaveBeenCalledWith(
            "/api/articles",
            expect.objectContaining({
                params: expect.objectContaining({ tag: "javascript" }),
            }),
        );
    });
});
