import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import axios from "axios";
import HomePage from "./HomePage.vue";
import ArticleCard from "../components/ArticleCard.vue";

// Mock axios
vi.mock("axios");

// Mock router
const createMockRouter = () => {
    return createRouter({
        history: createMemoryHistory(),
        routes: [
            { path: "/", name: "Home", component: HomePage },
            {
                path: "/articles",
                name: "Articles",
                component: { template: "<div>Articles</div>" },
            },
            {
                path: "/articles/:slug",
                name: "Article",
                component: { template: "<div>Article</div>" },
            },
        ],
    });
};

// Mock article data
const createMockArticle = (id, overrides = {}) => ({
    id,
    title: `Test Article ${id}`,
    slug: `test-article-${id}`,
    content: "# Test Content",
    excerpt: "Test excerpt",
    author: "Test Author",
    published_at: "2025-01-01T00:00:00Z",
    is_published: true,
    tags: [{ id: 1, name: "Test", slug: "test" }],
    ...overrides,
});

describe("HomePage", () => {
    let router;

    beforeEach(() => {
        router = createMockRouter();
        vi.clearAllMocks();
    });

    afterEach(() => {
        vi.restoreAllMocks();
    });

    describe("Initial Rendering", () => {
        it("renders the main heading", async () => {
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [],
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: { plugins: [router] },
            });

            await flushPromises();

            expect(wrapper.find("h1").text()).toBe("TheBoosh.Zone");
        });

        it("has correct page structure", async () => {
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [],
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: { plugins: [router] },
            });

            await flushPromises();

            expect(wrapper.find(".home-page").exists()).toBe(true);
            expect(wrapper.find(".hero-header").exists()).toBe(true);
            expect(wrapper.find(".articles-feed").exists()).toBe(true);
        });
    });

    describe("Initial Loading State", () => {
        it("shows loading spinner on mount", () => {
            axios.get.mockImplementation(() => new Promise(() => {})); // Never resolves

            const wrapper = mount(HomePage, {
                global: { plugins: [router] },
            });

            expect(wrapper.find(".loading-container").exists()).toBe(true);
            expect(wrapper.find(".loading-spinner").exists()).toBe(true);
            expect(wrapper.text()).toContain("Loading articles...");
        });

        it("fetches articles on mount with correct parameters", async () => {
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [],
                    pagination: { has_next: false },
                },
            });

            mount(HomePage, {
                global: { plugins: [router] },
            });

            await flushPromises();

            expect(axios.get).toHaveBeenCalledWith("/api/articles", {
                params: {
                    page: 1,
                    limit: 5,
                },
            });
        });
    });

    describe("Articles Display", () => {
        it("renders article cards when articles are loaded", async () => {
            const mockArticles = [
                createMockArticle(1),
                createMockArticle(2),
                createMockArticle(3),
            ];

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: mockArticles,
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            const articleCards = wrapper.findAllComponents(ArticleCard);
            expect(articleCards).toHaveLength(3);
        });

        it("passes correct props to ArticleCard", async () => {
            const mockArticle = createMockArticle(1);

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [mockArticle],
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            const articleCard = wrapper.findComponent(ArticleCard);
            expect(articleCard.props("article")).toEqual(mockArticle);
        });
    });

    describe("Empty State", () => {
        it("shows empty state when no articles exist", async () => {
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [],
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: { plugins: [router] },
            });

            await flushPromises();

            expect(wrapper.find(".empty-container").exists()).toBe(true);
            expect(wrapper.text()).toContain("No articles yet");
            expect(wrapper.text()).toContain(
                "Check back soon for new content!",
            );
        });
    });

    describe("Error State", () => {
        it("shows error message when fetch fails", async () => {
            const errorMessage = "Network error";
            axios.get.mockRejectedValueOnce({
                message: errorMessage,
            });

            const wrapper = mount(HomePage, {
                global: { plugins: [router] },
            });

            await flushPromises();

            expect(wrapper.find(".error-container").exists()).toBe(true);
            expect(wrapper.text()).toContain("Failed to load articles");
            expect(wrapper.text()).toContain(errorMessage);
        });

        it("shows error message from response data", async () => {
            const errorMessage = "Database connection failed";
            axios.get.mockRejectedValueOnce({
                response: {
                    data: {
                        error: errorMessage,
                    },
                },
            });

            const wrapper = mount(HomePage, {
                global: { plugins: [router] },
            });

            await flushPromises();

            expect(wrapper.text()).toContain(errorMessage);
        });

        it("allows retry after error", async () => {
            axios.get
                .mockRejectedValueOnce({ message: "Network error" })
                .mockResolvedValueOnce({
                    data: {
                        success: true,
                        articles: [createMockArticle(1)],
                        pagination: { has_next: false },
                    },
                });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            expect(wrapper.find(".error-container").exists()).toBe(true);

            const retryButton = wrapper.find(".retry-button");
            expect(retryButton.exists()).toBe(true);

            await retryButton.trigger("click");
            await flushPromises();

            expect(wrapper.find(".error-container").exists()).toBe(false);
            expect(wrapper.findAllComponents(ArticleCard)).toHaveLength(1);
            expect(axios.get).toHaveBeenCalledTimes(2);
        });
    });

    describe("Infinite Scroll", () => {
        it("shows loading more indicator when loading additional articles", async () => {
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [createMockArticle(1)],
                    pagination: { has_next: true },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            // Simulate intersection observer triggering
            wrapper.vm.isLoadingMore = true;
            await wrapper.vm.$nextTick();

            expect(wrapper.find(".loading-more").exists()).toBe(true);
            expect(wrapper.text()).toContain("Loading more articles...");
        });

        it("shows end message when no more articles", async () => {
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [createMockArticle(1)],
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            expect(wrapper.find(".end-message").exists()).toBe(true);
            expect(wrapper.text()).toContain(
                "You've reached the end of the articles",
            );
        });

        it("loads more articles when loadMoreArticles is called", async () => {
            const firstBatch = [createMockArticle(1), createMockArticle(2)];
            const secondBatch = [createMockArticle(3), createMockArticle(4)];

            axios.get
                .mockResolvedValueOnce({
                    data: {
                        success: true,
                        articles: firstBatch,
                        pagination: { has_next: true },
                    },
                })
                .mockResolvedValueOnce({
                    data: {
                        success: true,
                        articles: secondBatch,
                        pagination: { has_next: false },
                    },
                });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            expect(wrapper.findAllComponents(ArticleCard)).toHaveLength(2);

            // Manually call loadMoreArticles (simulating intersection observer)
            await wrapper.vm.loadMoreArticles();
            await flushPromises();

            expect(wrapper.findAllComponents(ArticleCard)).toHaveLength(4);
            expect(axios.get).toHaveBeenCalledTimes(2);
            expect(axios.get).toHaveBeenNthCalledWith(2, "/api/articles", {
                params: {
                    page: 2,
                    limit: 5,
                },
            });
        });

        it("does not load more when already loading", async () => {
            axios.get.mockResolvedValue({
                data: {
                    success: true,
                    articles: [createMockArticle(1)],
                    pagination: { has_next: true },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            wrapper.vm.isLoadingMore = true;
            await wrapper.vm.loadMoreArticles();

            // Should still only be called once (initial load)
            expect(axios.get).toHaveBeenCalledTimes(1);
        });

        it("does not load more when no more articles", async () => {
            axios.get.mockResolvedValue({
                data: {
                    success: true,
                    articles: [createMockArticle(1)],
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            await wrapper.vm.loadMoreArticles();

            // Should still only be called once (initial load)
            expect(axios.get).toHaveBeenCalledTimes(1);
        });
    });

    describe("Navigation", () => {
        it("navigates to article page when article is clicked", async () => {
            const mockArticle = createMockArticle(1);

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [mockArticle],
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            const pushSpy = vi.spyOn(router, "push");

            wrapper.vm.navigateToArticle("test-article-1");

            expect(pushSpy).toHaveBeenCalledWith({
                name: "Article",
                params: { slug: "test-article-1" },
            });
        });

        it("navigates to articles page with tag filter when tag is clicked", async () => {
            const mockArticle = createMockArticle(1);

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [mockArticle],
                    pagination: { has_next: false },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            const pushSpy = vi.spyOn(router, "push");

            wrapper.vm.navigateToTag("test-tag");

            expect(pushSpy).toHaveBeenCalledWith({
                name: "Articles",
                query: { tag: "test-tag" },
            });
        });
    });

    describe("Intersection Observer", () => {
        it("creates sentinel element for intersection observer", async () => {
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [createMockArticle(1)],
                    pagination: { has_next: true },
                },
            });

            const wrapper = mount(HomePage, {
                global: {
                    plugins: [router],
                    components: { ArticleCard },
                },
            });

            await flushPromises();

            expect(wrapper.find(".sentinel").exists()).toBe(true);
        });
    });
});
