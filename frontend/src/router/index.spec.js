import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { createRouter, createMemoryHistory } from "vue-router";
import axios from "axios";

// Mock axios
vi.mock("axios");

// Import routes configuration (we'll recreate router for testing)
const createTestRouter = () => {
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
                path: "/articles/:slug",
                name: "Article",
                component: { template: "<div>Article</div>" },
                props: true,
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
        ],
    });
};

// Apply the beforeEach guard that checks authentication
const applyAuthGuard = (router) => {
    router.beforeEach(async (to, from, next) => {
        if (to.meta.requiresAuth) {
            try {
                const response = await axios.get("/api/auth/status");

                if (response.data.authenticated) {
                    next();
                } else {
                    next({
                        name: "AdminLogin",
                        query: { redirect: to.fullPath },
                    });
                }
            } catch (error) {
                console.error("Auth check failed:", error);
                next({
                    name: "AdminLogin",
                    query: { redirect: to.fullPath },
                });
            }
        } else {
            next();
        }
    });
};

describe("Router", () => {
    let router;

    beforeEach(() => {
        router = createTestRouter();
        vi.clearAllMocks();
    });

    afterEach(() => {
        vi.restoreAllMocks();
    });

    describe("Route Definitions", () => {
        it("has all required routes defined", () => {
            const routes = router.getRoutes();
            const routeNames = routes.map((r) => r.name);

            expect(routeNames).toContain("Home");
            expect(routeNames).toContain("About");
            expect(routeNames).toContain("Articles");
            expect(routeNames).toContain("Article");
            expect(routeNames).toContain("AdminLogin");
            expect(routeNames).toContain("AdminDashboard");
            expect(routeNames).toContain("AdminMedia");
            expect(routeNames).toContain("NotFound");
        });

        it("has correct paths for all routes", () => {
            const routes = router.getRoutes();

            const homeRoute = routes.find((r) => r.name === "Home");
            const aboutRoute = routes.find((r) => r.name === "About");
            const articlesRoute = routes.find((r) => r.name === "Articles");
            const articleRoute = routes.find((r) => r.name === "Article");
            const loginRoute = routes.find((r) => r.name === "AdminLogin");
            const adminRoute = routes.find((r) => r.name === "AdminDashboard");
            const mediaRoute = routes.find((r) => r.name === "AdminMedia");

            expect(homeRoute.path).toBe("/");
            expect(aboutRoute.path).toBe("/about");
            expect(articlesRoute.path).toBe("/articles");
            expect(articleRoute.path).toBe("/articles/:slug");
            expect(loginRoute.path).toBe("/admin/login");
            expect(adminRoute.path).toBe("/admin");
            expect(mediaRoute.path).toBe("/admin/media");
        });

        it("Article route passes slug as prop", () => {
            const routes = router.getRoutes();
            const articleRoute = routes.find((r) => r.name === "Article");

            expect(articleRoute.props.default).toBe(true);
        });

        it("admin routes have requiresAuth meta", () => {
            const routes = router.getRoutes();

            const adminRoute = routes.find((r) => r.name === "AdminDashboard");
            const mediaRoute = routes.find((r) => r.name === "AdminMedia");

            expect(adminRoute.meta.requiresAuth).toBe(true);
            expect(mediaRoute.meta.requiresAuth).toBe(true);
        });

        it("public routes do not have requiresAuth meta", () => {
            const routes = router.getRoutes();

            const homeRoute = routes.find((r) => r.name === "Home");
            const aboutRoute = routes.find((r) => r.name === "About");
            const loginRoute = routes.find((r) => r.name === "AdminLogin");

            expect(homeRoute.meta.requiresAuth).toBeUndefined();
            expect(aboutRoute.meta.requiresAuth).toBeUndefined();
            expect(loginRoute.meta.requiresAuth).toBeUndefined();
        });
    });

    describe("Public Route Navigation", () => {
        it("navigates to home page", async () => {
            await router.push("/");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("Home");
            expect(router.currentRoute.value.path).toBe("/");
        });

        it("navigates to about page", async () => {
            await router.push("/about");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("About");
            expect(router.currentRoute.value.path).toBe("/about");
        });

        it("navigates to articles page", async () => {
            await router.push("/articles");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("Articles");
            expect(router.currentRoute.value.path).toBe("/articles");
        });

        it("navigates to individual article page with slug", async () => {
            await router.push("/articles/test-article");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("Article");
            expect(router.currentRoute.value.params.slug).toBe("test-article");
        });

        it("navigates to admin login page", async () => {
            await router.push("/admin/login");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("AdminLogin");
            expect(router.currentRoute.value.path).toBe("/admin/login");
        });

        it("handles 404 for unknown routes", async () => {
            await router.push("/this-does-not-exist");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("NotFound");
        });
    });

    describe("Navigation Guards - Authenticated", () => {
        beforeEach(() => {
            applyAuthGuard(router);
        });

        it("allows access to admin dashboard when authenticated", async () => {
            axios.get.mockResolvedValueOnce({
                data: { authenticated: true, user: { username: "admin" } },
            });

            await router.push("/admin");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("AdminDashboard");
            expect(axios.get).toHaveBeenCalledWith("/api/auth/status");
        });

        it("allows access to admin media when authenticated", async () => {
            axios.get.mockResolvedValueOnce({
                data: { authenticated: true, user: { username: "admin" } },
            });

            await router.push("/admin/media");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("AdminMedia");
            expect(axios.get).toHaveBeenCalledWith("/api/auth/status");
        });
    });

    describe("Navigation Guards - Unauthenticated", () => {
        beforeEach(() => {
            applyAuthGuard(router);
        });

        it("redirects to login when accessing admin dashboard unauthenticated", async () => {
            axios.get.mockResolvedValueOnce({
                data: { authenticated: false },
            });

            await router.push("/admin");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("AdminLogin");
            expect(router.currentRoute.value.query.redirect).toBe("/admin");
        });

        it("redirects to login when accessing admin media unauthenticated", async () => {
            axios.get.mockResolvedValueOnce({
                data: { authenticated: false },
            });

            await router.push("/admin/media");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("AdminLogin");
            expect(router.currentRoute.value.query.redirect).toBe(
                "/admin/media",
            );
        });

        it("redirects to login when auth check fails with error", async () => {
            axios.get.mockRejectedValueOnce(new Error("Network error"));

            await router.push("/admin");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("AdminLogin");
            expect(router.currentRoute.value.query.redirect).toBe("/admin");
        });

        it("allows access to public routes without auth check", async () => {
            await router.push("/");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("Home");
            expect(axios.get).not.toHaveBeenCalled();
        });

        it("allows access to login page without auth check", async () => {
            await router.push("/admin/login");
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("AdminLogin");
            expect(axios.get).not.toHaveBeenCalled();
        });
    });

    describe("Query Parameters", () => {
        it("preserves query parameters on articles page", async () => {
            await router.push("/articles?tag=tech&page=2");
            await router.isReady();

            expect(router.currentRoute.value.query.tag).toBe("tech");
            expect(router.currentRoute.value.query.page).toBe("2");
        });

        it("preserves redirect query parameter on login page", async () => {
            await router.push("/admin/login?redirect=/admin/media");
            await router.isReady();

            expect(router.currentRoute.value.query.redirect).toBe(
                "/admin/media",
            );
        });
    });

    describe("Programmatic Navigation", () => {
        it("navigates using push with route name", async () => {
            await router.push({ name: "About" });
            await router.isReady();

            expect(router.currentRoute.value.name).toBe("About");
        });

        it("navigates to article with params", async () => {
            await router.push({
                name: "Article",
                params: { slug: "my-article" },
            });
            await router.isReady();

            expect(router.currentRoute.value.params.slug).toBe("my-article");
        });

        it("navigates with query parameters", async () => {
            await router.push({
                name: "Articles",
                query: { tag: "javascript", page: "1" },
            });
            await router.isReady();

            expect(router.currentRoute.value.query.tag).toBe("javascript");
            expect(router.currentRoute.value.query.page).toBe("1");
        });
    });
});
