import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import { ref } from "vue";
import AdminLogin from "./AdminLogin.vue";

vi.mock("../composables/useAuth");
import { useAuth } from "../composables/useAuth";

describe("AdminLogin", () => {
    let router;
    let mockLogin;
    let mockCheckAuth;

    beforeEach(() => {
        router = createRouter({
            history: createMemoryHistory(),
            routes: [
                {
                    path: "/admin/login",
                    name: "AdminLogin",
                    component: AdminLogin,
                },
                {
                    path: "/admin",
                    name: "AdminDashboard",
                    component: { template: "<div>Dashboard</div>" },
                },
            ],
        });

        mockLogin = vi.fn();
        mockCheckAuth = vi.fn().mockResolvedValue(false);
        useAuth.mockReturnValue({
            login: mockLogin,
            checkAuth: mockCheckAuth,
            isAuthenticated: ref(false),
            isChecking: ref(false),
        });
    });

    it("renders login form", async () => {
        await router.push("/admin/login");
        await router.isReady();

        const wrapper = mount(AdminLogin, {
            global: { plugins: [router] },
        });

        expect(wrapper.find('input[type="text"]').exists()).toBe(true);
        expect(wrapper.find('input[type="password"]').exists()).toBe(true);
        expect(wrapper.find('button[type="submit"]').exists()).toBe(true);
    });

    it("validates required fields", async () => {
        await router.push("/admin/login");
        await router.isReady();

        const wrapper = mount(AdminLogin, {
            global: { plugins: [router] },
        });

        const submitButton = wrapper.find('button[type="submit"]');
        const usernameInput = wrapper.find('input[type="text"]');
        const passwordInput = wrapper.find('input[type="password"]');

        expect(usernameInput.attributes("required")).toBeDefined();
        expect(passwordInput.attributes("required")).toBeDefined();
    });

    it("submits login with credentials", async () => {
        mockLogin.mockResolvedValueOnce({
            success: true,
            user: { username: "admin" },
        });

        await router.push("/admin/login");
        await router.isReady();

        const wrapper = mount(AdminLogin, {
            global: { plugins: [router] },
        });

        await wrapper.find('input[type="text"]').setValue("admin");
        await wrapper.find('input[type="password"]').setValue("password123");
        await wrapper.find("form").trigger("submit.prevent");

        await flushPromises();

        expect(mockLogin).toHaveBeenCalledWith("admin", "password123");
    });

    it("displays error message on login failure", async () => {
        mockLogin.mockRejectedValueOnce({ message: "Invalid credentials" });

        await router.push("/admin/login");
        await router.isReady();

        const wrapper = mount(AdminLogin, {
            global: { plugins: [router] },
        });

        await wrapper.find('input[type="text"]').setValue("admin");
        await wrapper.find('input[type="password"]').setValue("wrong");
        await wrapper.find("form").trigger("submit.prevent");

        await flushPromises();

        expect(wrapper.text()).toContain("Invalid credentials");
    });
});
