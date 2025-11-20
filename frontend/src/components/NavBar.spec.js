/* global Event, KeyboardEvent */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
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
                    name: "THEBOOSH.ZONE",
                    component: { template: "<div>THEBOOSH.ZONE</div>" },
                },
                {
                    path: "/about",
                    name: "ABOUT",
                    component: { template: "<div>ABOUT</div>" },
                },
                {
                    path: "/articles",
                    name: "ARTICLES",
                    component: { template: "<div>ARTICLES</div>" },
                },
                {
                    path: "/radio",
                    name: "RADIO",
                    component: { template: "<div>RADIO</div>" },
                },
                {
                    path: "/admin",
                    name: "ADMIN",
                    component: { template: "<div>ADMIN</div>" },
                },
                {
                    path: "/admin/login",
                    name: "ADMIN_LOGIN",
                    component: { template: "<div>LOGIN</div>" },
                },
                {
                    path: "/admin/media",
                    name: "ADMIN_MEDIA",
                    component: { template: "<div>MEDIA</div>" },
                },
                {
                    path: "/admin/radio",
                    name: "ADMIN_RADIO",
                    component: { template: "<div>RADIO CONFIG</div>" },
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

        // Reset window innerWidth to desktop by default
        Object.defineProperty(window, "innerWidth", {
            writable: true,
            configurable: true,
            value: 1024,
        });
    });

    afterEach(() => {
        vi.clearAllMocks();
    });

    describe("Basic Navigation", () => {
        it("renders all public navigation links", async () => {
            config.enableSwagger = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
            });

            expect(wrapper.text()).toContain("THEBOOSH.ZONE");
            expect(wrapper.text()).toContain("ABOUT");
            expect(wrapper.text()).toContain("ARTICLES");
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
            expect(adminLink.text()).toBe("ADMIN");
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
            expect(logoutButton.text()).toBe("LOGOUT");
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
            expect(swaggerLink.text()).toBe("SWAGGER");
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

    describe("Mobile Detection", () => {
        it("detects mobile viewport on mount when width <= 768px", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            expect(wrapper.vm.isMobile).toBe(true);
            wrapper.unmount();
        });

        it("detects desktop viewport on mount when width > 768px", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 1024,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            expect(wrapper.vm.isMobile).toBe(false);
            wrapper.unmount();
        });

        it("updates mobile state on window resize", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 1024,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();
            expect(wrapper.vm.isMobile).toBe(false);

            // Simulate resize to mobile
            window.innerWidth = 375;
            window.dispatchEvent(new Event("resize"));
            await flushPromises();

            expect(wrapper.vm.isMobile).toBe(true);
            wrapper.unmount();
        });

        it("closes mobile menu when resizing from mobile to desktop", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            // Open mobile menu
            wrapper.vm.isMobileMenuOpen = true;
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(true);

            // Resize to desktop
            window.innerWidth = 1024;
            window.dispatchEvent(new Event("resize"));
            await flushPromises();

            expect(wrapper.vm.isMobile).toBe(false);
            expect(wrapper.vm.isMobileMenuOpen).toBe(false);
            wrapper.unmount();
        });
    });

    describe("Hamburger Menu - Rendering", () => {
        it("shows hamburger button on mobile viewport", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            expect(hamburgerButton.exists()).toBe(true);
            wrapper.unmount();
        });

        it("hides hamburger button on desktop viewport", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 1024,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            expect(hamburgerButton.exists()).toBe(false);
            wrapper.unmount();
        });

        it("shows mobile logo on mobile viewport", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const mobileLogo = wrapper.find(".mobile-logo");
            expect(mobileLogo.exists()).toBe(true);
            expect(mobileLogo.text()).toBe("THEBOOSH.ZONE");
            wrapper.unmount();
        });

        it("hides desktop nav-links on mobile viewport", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const navLinks = wrapper.find(".nav-links");
            expect(navLinks.exists()).toBe(false);
            wrapper.unmount();
        });
    });

    describe("Hamburger Menu - Accessibility", () => {
        it("has proper aria-label on hamburger button", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            expect(hamburgerButton.attributes("aria-label")).toBe(
                "Toggle navigation menu",
            );
            wrapper.unmount();
        });

        it("has aria-expanded='false' when menu is closed", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            expect(hamburgerButton.attributes("aria-expanded")).toBe("false");
            wrapper.unmount();
        });

        it("has aria-expanded='true' when menu is open", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();

            expect(hamburgerButton.attributes("aria-expanded")).toBe("true");
            wrapper.unmount();
        });

        it("has aria-controls linking to mobile menu", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            expect(hamburgerButton.attributes("aria-controls")).toBe(
                "mobile-nav-menu",
            );
            wrapper.unmount();
        });

        it("mobile menu has correct id attribute", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();

            const mobileMenu = wrapper.find("#mobile-nav-menu");
            expect(mobileMenu.exists()).toBe(true);
            wrapper.unmount();
        });

        it("mobile menu has aria-label", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();

            const mobileMenu = wrapper.find("#mobile-nav-menu");
            expect(mobileMenu.attributes("aria-label")).toBe(
                "Mobile navigation",
            );
            wrapper.unmount();
        });
    });

    describe("Mobile Menu - Functionality", () => {
        it("opens mobile menu when hamburger button is clicked", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            expect(wrapper.vm.isMobileMenuOpen).toBe(false);

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();

            expect(wrapper.vm.isMobileMenuOpen).toBe(true);
            wrapper.unmount();
        });

        it("closes mobile menu when hamburger button is clicked again", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(true);

            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(false);

            wrapper.unmount();
        });

        it("displays all navigation links in mobile menu", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            config.enableSwagger = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();

            const mobileMenu = wrapper.find("#mobile-nav-menu");
            expect(mobileMenu.text()).toContain("ABOUT");
            expect(mobileMenu.text()).toContain("ARTICLES");
            expect(mobileMenu.text()).toContain("RADIO");
            expect(mobileMenu.text()).toContain("SWAGGER");

            wrapper.unmount();
        });

        it("displays admin links in mobile menu when authenticated", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            mockIsAuthenticated.value = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();

            const mobileMenu = wrapper.find("#mobile-nav-menu");
            expect(mobileMenu.text()).toContain("ADMIN");
            expect(mobileMenu.text()).toContain("MEDIA");
            expect(mobileMenu.text()).toContain("RADIO CONFIG");

            wrapper.unmount();
        });

        it("closes mobile menu when clicking on a link", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(true);

            const aboutLink = wrapper.find('#mobile-nav-menu a[href="/about"]');
            await aboutLink.trigger("click");
            await wrapper.vm.$nextTick();

            expect(wrapper.vm.isMobileMenuOpen).toBe(false);

            wrapper.unmount();
        });

        it("closes mobile menu when clicking on backdrop", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(true);

            const backdrop = wrapper.find(".mobile-menu-backdrop");
            await backdrop.trigger("click");
            await wrapper.vm.$nextTick();

            expect(wrapper.vm.isMobileMenuOpen).toBe(false);

            wrapper.unmount();
        });

        it("closes mobile menu when pressing Escape key", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(true);

            // Simulate Escape key press
            const escapeEvent = new KeyboardEvent("keydown", { key: "Escape" });
            document.dispatchEvent(escapeEvent);
            await flushPromises();

            expect(wrapper.vm.isMobileMenuOpen).toBe(false);

            wrapper.unmount();
        });

        it("closes mobile menu on route change", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(true);

            // Navigate to another route
            await router.push("/about");
            await flushPromises();

            expect(wrapper.vm.isMobileMenuOpen).toBe(false);

            wrapper.unmount();
        });

        it("logout button remains visible in navbar on mobile when authenticated", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            mockIsAuthenticated.value = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const logoutButton = wrapper.find(".logout-button");
            expect(logoutButton.exists()).toBe(true);
            expect(logoutButton.text()).toBe("LOGOUT");

            wrapper.unmount();
        });

        it("logout button closes mobile menu when clicked", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            mockIsAuthenticated.value = true;

            await router.push("/");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(true);

            const logoutButton = wrapper.find(".logout-button");
            await logoutButton.trigger("click");
            await flushPromises();

            expect(wrapper.vm.isMobileMenuOpen).toBe(false);
            expect(mockLogout).toHaveBeenCalledWith("/admin/login");

            wrapper.unmount();
        });

        it("mobile logo closes menu when clicked", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/about");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();
            expect(wrapper.vm.isMobileMenuOpen).toBe(true);

            const mobileLogo = wrapper.find(".mobile-logo");
            await mobileLogo.trigger("click");
            await wrapper.vm.$nextTick();

            expect(wrapper.vm.isMobileMenuOpen).toBe(false);

            wrapper.unmount();
        });
    });

    describe("Mobile Menu - Active Route Highlighting", () => {
        it("highlights active route in mobile menu", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 375,
            });

            await router.push("/about");
            await router.isReady();

            const wrapper = mount(NavBar, {
                global: { plugins: [router] },
                attachTo: document.body,
            });

            await flushPromises();

            const hamburgerButton = wrapper.find(".hamburger-button");
            await hamburgerButton.trigger("click");
            await wrapper.vm.$nextTick();

            const aboutLink = wrapper.find('#mobile-nav-menu a[href="/about"]');
            expect(aboutLink.classes()).toContain("active");

            wrapper.unmount();
        });
    });
});
