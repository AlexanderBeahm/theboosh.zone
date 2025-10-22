import { mount } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import { vi } from "vitest";

/**
 * Create a mock axios instance for testing
 * @param {Object} customResponses - Custom responses for specific endpoints
 * @returns {Object} Mock axios instance
 */
export function createMockAxios(customResponses = {}) {
    const defaultResponses = {
        "/api/auth/status": { data: { authenticated: false } },
        "/api/auth/login": {
            data: { success: true, user: { username: "testuser" } },
        },
        "/api/auth/logout": { data: { success: true } },
        "/api/articles": {
            data: { articles: [], total: 0, page: 1, per_page: 10 },
        },
        "/api/tags": { data: { tags: [] } },
        "/api/admin/articles": { data: { articles: [], total: 0 } },
        "/api/admin/media": { data: { media: [], total: 0 } },
        ...customResponses,
    };

    const mockAxios = {
        get: vi.fn((url) => {
            const response = defaultResponses[url] || { data: {} };
            return Promise.resolve(response);
        }),
        post: vi.fn((url) => {
            const response = defaultResponses[url] || {
                data: { success: true },
            };
            return Promise.resolve(response);
        }),
        put: vi.fn((url) => {
            const response = defaultResponses[url] || {
                data: { success: true },
            };
            return Promise.resolve(response);
        }),
        delete: vi.fn(() => {
            return Promise.resolve({ data: { success: true } });
        }),
        // Method to simulate network errors
        simulateError: (statusCode = 500, message = "Network Error") => {
            const error = new Error(message);
            error.response = { status: statusCode, data: { error: message } };
            mockAxios.get.mockRejectedValueOnce(error);
            mockAxios.post.mockRejectedValueOnce(error);
            mockAxios.put.mockRejectedValueOnce(error);
            mockAxios.delete.mockRejectedValueOnce(error);
            return error;
        },
        // Reset all mocks
        reset: () => {
            mockAxios.get.mockClear();
            mockAxios.post.mockClear();
            mockAxios.put.mockClear();
            mockAxios.delete.mockClear();
        },
    };

    return mockAxios;
}

/**
 * Create a mock router for testing
 * @param {Array} routes - Optional custom routes
 * @param {string} initialPath - Initial route path
 * @returns {Object} Mock router instance
 */
export function createMockRouter(routes = [], initialPath = "/") {
    const defaultRoutes = [
        { path: "/", name: "Home", component: { template: "<div>Home</div>" } },
        {
            path: "/about",
            name: "About",
            component: { template: "<div>About</div>" },
        },
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
        {
            path: "/admin/login",
            name: "AdminLogin",
            component: { template: "<div>Login</div>" },
        },
        {
            path: "/admin",
            name: "AdminDashboard",
            component: { template: "<div>Dashboard</div>" },
            meta: { requiresAuth: true },
        },
        {
            path: "/admin/media",
            name: "AdminMedia",
            component: { template: "<div>Media</div>" },
            meta: { requiresAuth: true },
        },
        {
            path: "/:pathMatch(.*)*",
            name: "NotFound",
            component: { template: "<div>Not Found</div>" },
        },
    ];

    const router = createRouter({
        history: createMemoryHistory(),
        routes: routes.length > 0 ? routes : defaultRoutes,
    });

    // Navigate to initial path
    router.push(initialPath);

    return router;
}

/**
 * Create mock authentication state
 * @param {boolean} isAuthenticated - Initial auth state
 * @param {Object} user - User object
 * @returns {Object} Mock auth state and methods
 */
export function createMockAuthState(isAuthenticated = false, user = null) {
    return {
        isAuthenticated: { value: isAuthenticated },
        user: { value: user },
        isChecking: { value: false },
        checkAuth: vi.fn().mockResolvedValue(isAuthenticated),
        login: vi.fn().mockResolvedValue({ success: true, user }),
        logout: vi.fn().mockResolvedValue(undefined),
        requireAuth: vi.fn().mockResolvedValue(isAuthenticated),
    };
}

/**
 * Mount a component with common providers (router, axios mocks)
 * @param {Object} component - Vue component to mount
 * @param {Object} options - Mount options
 * @param {Object} options.props - Component props
 * @param {Object} options.data - Component data
 * @param {Object} options.global - Global configuration
 * @param {Object} options.mockAxios - Custom axios mock responses
 * @param {Object} options.mockRouter - Custom router instance
 * @param {Object} options.mockAuth - Custom auth state
 * @returns {Object} Wrapper and mocks
 */
export function mountWithProviders(component, options = {}) {
    const {
        props = {},
        data = {},
        global = {},
        mockAxios = null,
        mockRouter = null,
        mockAuth = null,
        ...otherOptions
    } = options;

    const axiosMock = mockAxios || createMockAxios();
    const routerMock = mockRouter || createMockRouter();
    const authMock = mockAuth || createMockAuthState();

    // Setup global plugins and mocks
    const globalConfig = {
        plugins: [routerMock],
        mocks: {
            axios: axiosMock,
            ...global.mocks,
        },
        stubs: {
            RouterLink: true,
            RouterView: true,
            ...global.stubs,
        },
        ...global,
    };

    const wrapper = mount(component, {
        props,
        data: () => data,
        global: globalConfig,
        ...otherOptions,
    });

    return {
        wrapper,
        mocks: {
            axios: axiosMock,
            router: routerMock,
            auth: authMock,
        },
    };
}

/**
 * Wait for async updates and nextTick
 * @param {number} ms - Milliseconds to wait
 * @returns {Promise}
 */
export function flushPromises(ms = 0) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Create mock article data
 * @param {Object} overrides - Property overrides
 * @returns {Object} Mock article
 */
export function createMockArticle(overrides = {}) {
    return {
        id: 1,
        title: "Test Article",
        slug: "test-article",
        content: "# Test Content\n\nThis is a test article.",
        excerpt: "Test excerpt",
        author: "Test Author",
        published_at: "2025-01-01T00:00:00Z",
        date_added: "2025-01-01T00:00:00Z",
        date_updated: "2025-01-01T00:00:00Z",
        is_published: true,
        meta_description: "Test meta description",
        featured_image: "/uploads/2025/01/test.jpg",
        tags: [{ id: 1, name: "Test", slug: "test" }],
        ...overrides,
    };
}

/**
 * Create mock tag data
 * @param {Object} overrides - Property overrides
 * @returns {Object} Mock tag
 */
export function createMockTag(overrides = {}) {
    return {
        id: 1,
        name: "Test Tag",
        slug: "test-tag",
        date_added: "2025-01-01T00:00:00Z",
        ...overrides,
    };
}

/**
 * Create mock media data
 * @param {Object} overrides - Property overrides
 * @returns {Object} Mock media
 */
export function createMockMedia(overrides = {}) {
    return {
        id: 1,
        filename: "test-image.jpg",
        original_filename: "test-image.jpg",
        filepath: "/uploads/2025/01/test-image.jpg",
        mime_type: "image/jpeg",
        file_size: 102400,
        width: 1920,
        height: 1080,
        uploaded_by: 1,
        created_at: "2025-01-01T00:00:00Z",
        alt_text: "Test image",
        caption: "Test caption",
        ...overrides,
    };
}
