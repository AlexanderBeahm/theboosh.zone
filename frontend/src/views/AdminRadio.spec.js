import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import { ref } from "vue";
import AdminRadio from "./AdminRadio.vue";
import axios from "axios";

vi.mock("axios");

// Mock useAuth composable
vi.mock("../composables/useAuth", () => ({
    useAuth: () => ({
        requireAuth: vi.fn(),
        isAuthenticated: ref(true),
    }),
}));

// Mock useCSRF composable
vi.mock("../composables/useCSRF", () => ({
    useCSRF: () => ({
        getToken: vi.fn().mockResolvedValue("mock-csrf-token"),
    }),
}));

describe("AdminRadio", () => {
    let router;
    let wrapper;

    beforeEach(() => {
        router = createRouter({
            history: createMemoryHistory(),
            routes: [
                {
                    path: "/admin/radio",
                    name: "AdminRadio",
                    component: AdminRadio,
                },
            ],
        });

        vi.clearAllMocks();
    });

    afterEach(() => {
        if (wrapper) {
            wrapper.unmount();
        }
    });

    it("renders the admin radio page", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        expect(wrapper.find(".admin-radio-page").exists()).toBe(true);
        expect(wrapper.find("h1").text()).toBe("Radio Configuration");
    });

    it("loads and displays current configuration", async () => {
        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                config: [
                    {
                        config_key: "playlist_url",
                        config_value: "https://example.com/playlist.m3u",
                    },
                ],
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        expect(wrapper.find(".current-config-card").exists()).toBe(true);
        expect(wrapper.find(".config-value").text()).toBe(
            "https://example.com/playlist.m3u",
        );
    });

    it("shows form when no playlist is configured", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        expect(wrapper.find(".config-form-card").exists()).toBe(true);
        expect(wrapper.find("#playlist-url").exists()).toBe(true);
    });

    it("validates required fields in form", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const input = wrapper.find("#playlist-url");
        expect(input.attributes("required")).toBeDefined();
    });

    it("submits playlist URL successfully", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        axios.post.mockResolvedValueOnce({
            data: {
                success: true,
                message: "Playlist URL updated successfully",
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const input = wrapper.find("#playlist-url");
        await input.setValue("https://example.com/playlist.m3u");

        const form = wrapper.find("form");
        await form.trigger("submit.prevent");
        await flushPromises();

        expect(axios.post).toHaveBeenCalledWith(
            "/api/admin/radio/playlist",
            { playlist_url: "https://example.com/playlist.m3u" },
            {
                headers: {
                    "X-CSRF-Token": "mock-csrf-token",
                },
            },
        );
    });

    it("displays success toast after saving", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        axios.post.mockResolvedValueOnce({
            data: {
                success: true,
                message: "Playlist URL updated successfully",
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const input = wrapper.find("#playlist-url");
        await input.setValue("https://example.com/playlist.m3u");

        const form = wrapper.find("form");
        await form.trigger("submit.prevent");
        await flushPromises();

        expect(wrapper.find(".success-toast").exists()).toBe(true);
    });

    it("displays error message on save failure", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        axios.post.mockRejectedValueOnce({
            response: {
                data: { error: "Invalid URL format" },
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const input = wrapper.find("#playlist-url");
        await input.setValue("invalid-url");

        const form = wrapper.find("form");
        await form.trigger("submit.prevent");
        await flushPromises();

        expect(wrapper.find(".error-message").exists()).toBe(true);
        expect(wrapper.find(".error-message").text()).toContain(
            "Invalid URL format",
        );
    });

    it("enters edit mode when update button is clicked", async () => {
        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                config: [
                    {
                        config_key: "playlist_url",
                        config_value: "https://example.com/playlist.m3u",
                    },
                ],
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const editButton = wrapper.find(".btn-edit");
        await editButton.trigger("click");
        await flushPromises();

        expect(wrapper.find(".config-form-card").exists()).toBe(true);
        expect(wrapper.find("#playlist-url").element.value).toBe(
            "https://example.com/playlist.m3u",
        );
    });

    it("cancels editing when cancel button is clicked", async () => {
        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                config: [
                    {
                        config_key: "playlist_url",
                        config_value: "https://example.com/playlist.m3u",
                    },
                ],
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        // Enter edit mode
        const editButton = wrapper.find(".btn-edit");
        await editButton.trigger("click");
        await flushPromises();

        // Cancel editing
        const cancelButton = wrapper.find(".btn-secondary");
        await cancelButton.trigger("click");
        await flushPromises();

        expect(wrapper.find(".config-form-card").exists()).toBe(false);
        expect(wrapper.find(".current-config-card").exists()).toBe(true);
    });

    it("shows delete confirmation dialog", async () => {
        const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(false);

        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                config: [
                    {
                        config_key: "playlist_url",
                        config_value: "https://example.com/playlist.m3u",
                    },
                ],
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const deleteButton = wrapper.find(".btn-delete");
        await deleteButton.trigger("click");

        expect(confirmSpy).toHaveBeenCalled();
        confirmSpy.mockRestore();
    });

    it("deletes playlist successfully", async () => {
        const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(true);

        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                config: [
                    {
                        config_key: "playlist_url",
                        config_value: "https://example.com/playlist.m3u",
                    },
                ],
            },
        });

        axios.delete.mockResolvedValueOnce({
            data: {
                success: true,
                message: "Playlist deleted successfully",
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const deleteButton = wrapper.find(".btn-delete");
        await deleteButton.trigger("click");
        await flushPromises();

        expect(axios.delete).toHaveBeenCalledWith("/api/admin/radio/playlist", {
            headers: {
                "X-CSRF-Token": "mock-csrf-token",
            },
        });

        expect(wrapper.find(".success-toast").exists()).toBe(true);
        confirmSpy.mockRestore();
    });

    it("loads and displays playlist preview", async () => {
        axios.get
            .mockResolvedValueOnce({
                data: {
                    success: true,
                    config: [
                        {
                            config_key: "playlist_url",
                            config_value: "https://example.com/playlist.m3u",
                        },
                    ],
                },
            })
            .mockResolvedValueOnce({
                data: {
                    success: true,
                    playlist: {
                        tracks: [
                            {
                                title: "Track 1",
                                artist: "Artist 1",
                                duration: 180,
                            },
                            {
                                title: "Track 2",
                                artist: "Artist 2",
                                duration: 240,
                            },
                        ],
                    },
                },
            });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        expect(wrapper.find(".preview-card").exists()).toBe(true);
        expect(wrapper.find(".track-item").exists()).toBe(true);
    });

    it("formats duration correctly", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const vm = wrapper.vm;

        expect(vm.formatDuration(0)).toBe("0:00");
        expect(vm.formatDuration(59)).toBe("0:59");
        expect(vm.formatDuration(60)).toBe("1:00");
        expect(vm.formatDuration(125)).toBe("2:05");
        expect(vm.formatDuration(-1)).toBe("");
    });

    it("disables save button while saving", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        let resolvePost;
        const postPromise = new Promise((resolve) => {
            resolvePost = resolve;
        });
        axios.post.mockReturnValue(postPromise);

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const input = wrapper.find("#playlist-url");
        await input.setValue("https://example.com/playlist.m3u");

        const form = wrapper.find("form");
        await form.trigger("submit.prevent");
        await flushPromises();

        const submitButton = wrapper.find('button[type="submit"]');
        expect(submitButton.attributes("disabled")).toBeDefined();
        expect(submitButton.text()).toContain("Saving...");

        resolvePost({ data: { success: true } });
        await flushPromises();
    });

    it("disables delete button while deleting", async () => {
        const confirmSpy = vi.spyOn(window, "confirm").mockReturnValue(true);

        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                config: [
                    {
                        config_key: "playlist_url",
                        config_value: "https://example.com/playlist.m3u",
                    },
                ],
            },
        });

        let resolveDelete;
        const deletePromise = new Promise((resolve) => {
            resolveDelete = resolve;
        });
        axios.delete.mockReturnValue(deletePromise);

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const deleteButton = wrapper.find(".btn-delete");
        await deleteButton.trigger("click");
        await flushPromises();

        expect(deleteButton.attributes("disabled")).toBeDefined();
        expect(deleteButton.text()).toContain("Deleting...");

        resolveDelete({ data: { success: true } });
        await flushPromises();

        confirmSpy.mockRestore();
    });

    it("shows help text for playlist URL input", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const helpText = wrapper.find(".help-text");
        expect(helpText.exists()).toBe(true);
        expect(helpText.text()).toContain(".m3u");
    });

    it("handles load configuration error", async () => {
        axios.get.mockRejectedValueOnce(new Error("Network error"));

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        // Should still render but show error
        expect(wrapper.find(".admin-radio-page").exists()).toBe(true);
    });

    it("updates configuration and reloads preview", async () => {
        axios.get.mockResolvedValueOnce({
            data: { success: true, config: [] },
        });

        axios.post.mockResolvedValueOnce({
            data: { success: true },
        });

        axios.get.mockResolvedValueOnce({
            data: {
                success: true,
                playlist: {
                    tracks: [
                        {
                            title: "New Track",
                            artist: "New Artist",
                            duration: 200,
                        },
                    ],
                },
            },
        });

        await router.push("/admin/radio");
        await router.isReady();

        wrapper = mount(AdminRadio, {
            global: { plugins: [router] },
        });

        await flushPromises();

        const input = wrapper.find("#playlist-url");
        await input.setValue("https://example.com/new-playlist.m3u");

        const form = wrapper.find("form");
        await form.trigger("submit.prevent");
        await flushPromises();

        // Should reload preview after save
        expect(axios.get).toHaveBeenCalledWith("/api/radio/playlist", {
            params: { parse: 1 },
        });
    });
});
