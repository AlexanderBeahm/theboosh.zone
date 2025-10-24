import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import { ref } from "vue";
import NavBar from "./NavBar.vue";

// Mock the useAuth composable
vi.mock("../composables/useAuth", () => ({
    useAuth: vi.fn(),
}));

// Mock the config
vi.mock("../config", () => ({
    config: {
        apiUrl: "http://localhost:3000",
        environment: "test",
        isDevelopment: false,
        isProduction: false,
        enableDebug: false,
        enableSwagger: true, // Default to true for most tests
    },
}));

import { useAuth } from "../composables/useAuth";
import { config } from "../config";

describe("NavBar", () => {
    let router;
    let mockCheckAuth;
    let mockLogout;
    let mockIsAuthenticated;

    const createRouterInstance = () => {
        return createRouter({
            history: createMemoryHistory(),
            routes: [
                {
                    path: "/",
                    name: "Home",
                    component: { template: "<div>Home</div>" },
                },
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
                    path: "/admin",
                    name: "Admin",
                    component: { template: "<div>Admin</div>" },
                },
                {
                    path: "/admin/login",
                    name: "AdminLogin",
                    component: { template: "<div>Login</div>" },
                },
            ],
        });
    };

    beforeEach(() => {
        router = createRouterInstance();
        mockCheckAuth = vi.fn();
        mockLogout = vi.fn();
        mockIsAuthenticated = ref(false);

        useAuth.mockReturnValue({
            isAuthenticated: mockIsAuthenticated,
            checkAuth: mockCheckAuth,
            logout: mockLogout,
            user: ref(null),
            isChecking: ref(false),
        });
    });

    describe("Basic Navigation", () => {
        it("renders all public navigation links", async () => {
            config.enableSwagger = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            expect(wrapper.text()).toContain("Home");
            expect(wrapper.text()).toContain("About");
            expect(wrapper.text()).toContain("Articles");
            expect(wrapper.text()).toContain("TheBoosh.Zone");
        });

        it("renders site title", async () => {
            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const title = wrapper.find(".nav-title");
            expect(title.exists()).toBe(true);
            expect(title.text()).toBe("TheBoosh.Zone");
        });

        it("contains router-links for internal pages", async () => {
            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const homeLink = wrapper.find('a[href="/"]');
            const aboutLink = wrapper.find('a[href="/about"]');
            const articlesLink = wrapper.find('a[href="/articles"]');

            expect(homeLink.exists()).toBe(true);
            expect(aboutLink.exists()).toBe(true);
            expect(articlesLink.exists()).toBe(true);
        });
    });

    describe("Active Route Highlighting", () => {
        it("highlights Home link when on home page", async () => {
            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const homeLink = wrapper.find('a[href="/"]');
            expect(homeLink.classes()).toContain("active");
        });

        it("highlights About link when on about page", async () => {
            await router.push("/about");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const aboutLink = wrapper.find('a[href="/about"]');
            expect(aboutLink.classes()).toContain("active");
        });

        it("highlights Articles link when on articles pages", async () => {
            await router.push("/articles");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const articlesLink = wrapper.find('a[href="/articles"]');
            expect(articlesLink.classes()).toContain("active");
        });
    });

    describe("Authentication - Unauthenticated State", () => {
        it("does not show Admin link when not authenticated", async () => {
            mockIsAuthenticated.value = false;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const adminLink = wrapper.find('a[href="/admin"]');
            expect(adminLink.exists()).toBe(false);
        });

        it("does not show logout button when not authenticated", async () => {
            mockIsAuthenticated.value = false;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const logoutButton = wrapper.find(".logout-button");
            expect(logoutButton.exists()).toBe(false);
        });

        it("calls checkAuth on mount", async () => {
            await router.push("/");
            await router.isReady();

            mount(NavBar, {
                global: { plugins: [router] },
            });

            await flushPromises();

            expect(mockCheckAuth).toHaveBeenCalled();
        });
    });

    describe("Authentication - Authenticated State", () => {
        it("shows Admin link when authenticated", async () => {
            mockIsAuthenticated.value = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const adminLink = wrapper.find('a[href="/admin"]');
            expect(adminLink.exists()).toBe(true);
            expect(adminLink.text()).toBe("Admin");
        });

        it("highlights Admin link when on admin pages", async () => {
            mockIsAuthenticated.value = true;

            await router.push("/admin");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const adminLink = wrapper.find('a[href="/admin"]');
            expect(adminLink.classes()).toContain("active");
        });

        it("shows logout button when authenticated", async () => {
            mockIsAuthenticated.value = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const logoutButton = wrapper.find(".logout-button");
            expect(logoutButton.exists()).toBe(true);
            expect(logoutButton.text()).toBe("Logout");
        });

        it("calls logout with redirect path when logout button is clicked", async () => {
            mockIsAuthenticated.value = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const logoutButton = wrapper.find(".logout-button");
            await logoutButton.trigger("click");

            expect(mockLogout).toHaveBeenCalledWith("/admin/login");
        });
    });

    describe("Accessibility", () => {
        it("has aria-label on main navigation", async () => {
            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const nav = wrapper.find("nav");
            expect(nav.attributes("aria-label")).toBe("Main navigation");
        });

        it("has aria-label on site title", async () => {
            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const title = wrapper.find(".nav-title");
            expect(title.attributes("aria-label")).toBe("Site name");
        });

        it("has title attribute on logout button", async () => {
            mockIsAuthenticated.value = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const logoutButton = wrapper.find(".logout-button");
            expect(logoutButton.attributes("title")).toBe("Logout");
        });
    });

    describe("Styling Classes", () => {
        it("applies correct styling classes to navbar", async () => {
            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            expect(wrapper.find(".nav-bar").exists()).toBe(true);
            expect(wrapper.find(".nav-links").exists()).toBe(true);
            expect(wrapper.find(".nav-title").exists()).toBe(true);
            expect(wrapper.find(".nav-spacer").exists()).toBe(true);
        });

        it("shows nav-actions when authenticated", async () => {
            mockIsAuthenticated.value = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            expect(wrapper.find(".nav-actions").exists()).toBe(true);
        });
    });

    describe("Swagger Link Visibility", () => {
        it("shows Swagger link when enableSwagger is true", async () => {
            config.enableSwagger = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const swaggerLink = wrapper.find('a[href="/swagger"]');
            expect(swaggerLink.exists()).toBe(true);
            expect(swaggerLink.text()).toBe("Swagger");
        });

        it("hides Swagger link when enableSwagger is false", async () => {
            config.enableSwagger = false;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const swaggerLink = wrapper.find('a[href="/swagger"]');
            expect(swaggerLink.exists()).toBe(false);
            expect(wrapper.text()).not.toContain("Swagger");
        });

        it("Swagger link has correct attributes when enabled", async () => {
            config.enableSwagger = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            const swaggerLink = wrapper.find('a[href="/swagger"]');
            expect(swaggerLink.exists()).toBe(true);
            expect(swaggerLink.attributes("target")).toBe("_blank");
            expect(swaggerLink.attributes("rel")).toBe("noopener noreferrer");
            expect(swaggerLink.attributes("aria-label")).toContain(
                "API documentation",
            );
        });
    });
});
