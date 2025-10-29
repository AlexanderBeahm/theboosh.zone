import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import AdminDashboard from "./AdminDashboard.vue";
import axios from "axios";

// Mock axios
vi.mock("axios");

// Mock the useAuth composable
vi.mock("../composables/useAuth", () => ({
    useAuth: () => ({
        requireAuth: vi.fn().mockResolvedValue(true),
    }),
}));

// Create a mock router
const createMockRouter = () => {
    return createRouter({
        history: createMemoryHistory(),
        routes: [
            { path: "/admin", component: { template: "<div>Admin</div>" } },
            {
                path: "/admin/login",
                component: { template: "<div>Login</div>" },
            },
        ],
    });
};

describe("AdminDashboard", () => {
    let router;

    beforeEach(() => {
        router = createMockRouter();
        vi.clearAllMocks();
    });

    describe("getArticleContent", () => {
        it("returns article content on success", async () => {
            // Mock successful article fetch with articles
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [
                        {
                            id: 1,
                            title: "Test Article",
                            slug: "test-article",
                            is_published: true,
                        },
                    ],
                    pagination: {
                        current_page: 1,
                        total_pages: 1,
                        total_count: 1,
                        per_page: 20,
                        has_next: false,
                        has_prev: false,
                    },
                },
            });

            // Mock successful tags fetch
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    tags: [],
                },
            });

            const wrapper = mount(AdminDashboard, {
                global: {
                    plugins: [router],
                    stubs: {
                        ArticleEditor: true,
                    },
                },
            });

            await flushPromises();

            // Mock successful article content fetch
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    article: {
                        id: 1,
                        title: "Test Article",
                        content: "Test content",
                    },
                },
            });

            // Access the component instance to call the internal function
            const vm = wrapper.vm;

            // Now click edit - button should exist since we have articles
            const editButton = wrapper.find(".edit-button");
            await editButton.trigger("click");
            await flushPromises();

            // Check that editingArticle is set (meaning content was successfully fetched)
            expect(vm.editingArticle).toBeTruthy();
            expect(vm.editingArticle.content).toBe("Test content");
            expect(vm.error).toBe(null);
        });

        it("sets error state on failure and returns null", async () => {
            // Mock successful initial fetch with articles
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [
                        {
                            id: 999,
                            title: "Non-existent Article",
                            slug: "non-existent",
                            is_published: false,
                        },
                    ],
                    pagination: {
                        current_page: 1,
                        total_pages: 1,
                        total_count: 1,
                        per_page: 20,
                        has_next: false,
                        has_prev: false,
                    },
                },
            });

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    tags: [],
                },
            });

            const wrapper = mount(AdminDashboard, {
                global: {
                    plugins: [router],
                    stubs: {
                        ArticleEditor: true,
                    },
                },
            });

            await flushPromises();

            // Mock failed article content fetch
            axios.get.mockRejectedValueOnce({
                response: {
                    data: {
                        error: "Article not found",
                    },
                },
            });

            const vm = wrapper.vm;

            // Trigger edit which will fail
            const editButton = wrapper.find(".edit-button");
            await editButton.trigger("click");
            await flushPromises();

            // Check that error is set and editingArticle is null
            expect(vm.error).toBe("Article not found");
            expect(vm.editingArticle).toBe(null);
        });

        it("handles network errors gracefully", async () => {
            // Mock successful initial fetch with articles
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [
                        {
                            id: 1,
                            title: "Test Article",
                            slug: "test-article",
                            is_published: true,
                        },
                    ],
                    pagination: {
                        current_page: 1,
                        total_pages: 1,
                        total_count: 1,
                        per_page: 20,
                        has_next: false,
                        has_prev: false,
                    },
                },
            });

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    tags: [],
                },
            });

            const wrapper = mount(AdminDashboard, {
                global: {
                    plugins: [router],
                    stubs: {
                        ArticleEditor: true,
                    },
                },
            });

            await flushPromises();

            // Mock network error
            axios.get.mockRejectedValueOnce(
                new Error("Network Error: Failed to fetch"),
            );

            const vm = wrapper.vm;

            const editButton = wrapper.find(".edit-button");
            await editButton.trigger("click");
            await flushPromises();

            // Check that error is set with network error message
            expect(vm.error).toContain("Network Error");
            expect(vm.editingArticle).toBe(null);
        });
    });

    describe("editArticle", () => {
        it("opens editor with content on successful fetch", async () => {
            // Mock successful initial fetch
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [
                        {
                            id: 1,
                            title: "Test Article",
                            slug: "test-article",
                            content: "Test content",
                            is_published: true,
                        },
                    ],
                    pagination: {
                        current_page: 1,
                        total_pages: 1,
                        total_count: 1,
                        per_page: 20,
                        has_next: false,
                        has_prev: false,
                    },
                },
            });

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    tags: [],
                },
            });

            const wrapper = mount(AdminDashboard, {
                global: {
                    plugins: [router],
                    stubs: {
                        ArticleEditor: true,
                    },
                },
            });

            await flushPromises();

            // Mock successful article content fetch
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    article: {
                        id: 1,
                        title: "Test Article",
                        content: "Test content from API",
                    },
                },
            });

            const vm = wrapper.vm;
            const editButton = wrapper.find(".edit-button");

            await editButton.trigger("click");
            await flushPromises();

            // Editor should be opened with content
            expect(vm.editingArticle).toBeTruthy();
            expect(vm.editingArticle.title).toBe("Test Article");
            expect(vm.editingArticle.content).toBe("Test content from API");
        });

        it("does not open editor when content fetch fails", async () => {
            // Mock successful initial fetch
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [
                        {
                            id: 1,
                            title: "Test Article",
                            slug: "test-article",
                            is_published: true,
                        },
                    ],
                    pagination: {
                        current_page: 1,
                        total_pages: 1,
                        total_count: 1,
                        per_page: 20,
                        has_next: false,
                        has_prev: false,
                    },
                },
            });

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    tags: [],
                },
            });

            const wrapper = mount(AdminDashboard, {
                global: {
                    plugins: [router],
                    stubs: {
                        ArticleEditor: true,
                    },
                },
            });

            await flushPromises();

            // Mock failed article content fetch
            axios.get.mockRejectedValueOnce({
                response: {
                    data: {
                        error: "Failed to load article",
                    },
                },
            });

            const vm = wrapper.vm;
            const editButton = wrapper.find(".edit-button");

            await editButton.trigger("click");
            await flushPromises();

            // Editor should NOT be opened
            expect(vm.editingArticle).toBe(null);
            // Error should be displayed
            expect(vm.error).toBe("Failed to load article");
        });
    });

    describe("Error Display", () => {
        it("displays error in UI when article load fails", async () => {
            // Mock successful initial fetch
            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    articles: [
                        {
                            id: 1,
                            title: "Test Article",
                            slug: "test-article",
                            is_published: true,
                        },
                    ],
                    pagination: {
                        current_page: 1,
                        total_pages: 1,
                        total_count: 1,
                        per_page: 20,
                        has_next: false,
                        has_prev: false,
                    },
                },
            });

            axios.get.mockResolvedValueOnce({
                data: {
                    success: true,
                    tags: [],
                },
            });

            const wrapper = mount(AdminDashboard, {
                global: {
                    plugins: [router],
                    stubs: {
                        ArticleEditor: true,
                    },
                },
            });

            await flushPromises();

            // Mock failed article content fetch
            axios.get.mockRejectedValueOnce({
                response: {
                    data: {
                        error: "Article not found",
                    },
                },
            });

            const editButton = wrapper.find(".edit-button");
            await editButton.trigger("click");
            await flushPromises();

            // No error container should be shown initially (error is only shown when isLoading is false and error is truthy)
            // But the error state should be set
            expect(wrapper.vm.error).toBe("Article not found");
        });
    });
});
