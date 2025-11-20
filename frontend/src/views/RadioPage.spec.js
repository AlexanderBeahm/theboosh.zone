import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount, flushPromises } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import { ref } from "vue";
import RadioPage from "./RadioPage.vue";

// Create a mock player factory function
const createMockPlayer = (overrides = {}) => ({
    init: vi.fn().mockResolvedValue(true),
    loadPlaylistWithSync: vi.fn().mockResolvedValue(true),
    play: vi.fn(),
    pause: vi.fn(),
    stop: vi.fn(),
    setVolume: vi.fn(),
    toggleMute: vi.fn(),
    seekTo: vi.fn(),
    nextTrack: vi.fn(),
    previousTrack: vi.fn(),
    cleanup: vi.fn(),
    isPlaying: ref(false),
    isPaused: ref(true),
    isMuted: ref(false),
    volume: ref(70),
    currentTime: ref(0),
    duration: ref(0),
    currentTrack: ref(null),
    playlist: ref([]),
    currentIndex: ref(0),
    isLoading: ref(false),
    error: ref(null),
    audio: ref(null),
    ...overrides,
});

// Mock the audio player composable
let mockPlayer = createMockPlayer();
vi.mock("../composables/useAudioPlayer", () => ({
    useAudioPlayer: () => mockPlayer,
}));

// Mock AudioVisualizer component
vi.mock("../components/AudioVisualizer.vue", () => ({
    default: {
        name: "AudioVisualizer",
        template: '<div class="audio-visualizer-mock"></div>',
        props: ["audioElement", "isPlaying"],
    },
}));

describe("RadioPage", () => {
    let router;
    let wrapper;

    beforeEach(() => {
        // Reset mock player before each test
        mockPlayer = createMockPlayer();

        router = createRouter({
            history: createMemoryHistory(),
            routes: [
                {
                    path: "/radio",
                    name: "Radio",
                    component: RadioPage,
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

    it("renders the radio page", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".radio-page").exists()).toBe(true);
    });

    it("shows 'Listen Live' overlay initially", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".listen-live-overlay").exists()).toBe(true);
        expect(wrapper.find(".listen-live-button").exists()).toBe(true);
    });

    it("hides 'Listen Live' overlay after clicking button", async () => {
        mockPlayer.loadPlaylistWithSync = vi.fn().mockResolvedValue(true);
        mockPlayer.play = vi.fn().mockResolvedValue(true);

        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        const listenButton = wrapper.find(".listen-live-button");
        await listenButton.trigger("click");
        await flushPromises();

        expect(wrapper.find(".listen-live-overlay").exists()).toBe(false);
    });

    it("displays station name", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".station-name").text()).toContain(
            "TheBoosh.Zone Radio",
        );
    });

    it("displays track info when track is playing", async () => {
        const mockTrack = {
            title: "Test Song",
            artist: "Test Artist",
            url: "https://example.com/song.mp3",
        };

        mockPlayer.currentTrack = ref(mockTrack);
        mockPlayer.isPlaying = ref(true);
        mockPlayer.isPaused = ref(false);

        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".track-title").text()).toBe("Test Song");
        expect(wrapper.find(".track-artist").text()).toBe("Test Artist");
    });

    it("formats time correctly", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        const vm = wrapper.vm;

        expect(vm.formatTime(0)).toBe("0:00");
        expect(vm.formatTime(59)).toBe("0:59");
        expect(vm.formatTime(60)).toBe("1:00");
        expect(vm.formatTime(125)).toBe("2:05");
        expect(vm.formatTime(3665)).toBe("61:05");
    });

    it("shows volume controls", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".volume-section").exists()).toBe(true);
        expect(wrapper.find(".volume-slider").exists()).toBe(true);
        expect(wrapper.find(".volume-button").exists()).toBe(true);
    });

    it("displays loading message when loading", async () => {
        mockPlayer.isLoading = ref(true);
        mockPlayer.currentTrack = ref(null);
        mockPlayer.error = ref(null);

        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".loading-message").exists()).toBe(true);
    });

    it("displays error message when error occurs", async () => {
        mockPlayer.error = ref("Failed to load audio");
        mockPlayer.currentTrack = ref(null);

        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".error-message").exists()).toBe(true);
        expect(wrapper.find(".error-message").text()).toContain(
            "Failed to load audio",
        );
    });

    it("starts listening when button is clicked and playlist is configured", async () => {
        mockPlayer.loadPlaylistWithSync = vi.fn().mockResolvedValue(true);
        mockPlayer.play = vi.fn().mockResolvedValue(true);

        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        const listenButton = wrapper.find(".listen-live-button");
        await listenButton.trigger("click");
        await flushPromises();

        expect(mockPlayer.loadPlaylistWithSync).toHaveBeenCalled();
        expect(mockPlayer.play).toHaveBeenCalled();
    });

    it("shows error when starting listening fails", async () => {
        mockPlayer.loadPlaylistWithSync = vi.fn().mockResolvedValue(false);
        mockPlayer.error = ref("No playlist configured");

        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        const listenButton = wrapper.find(".listen-live-button");
        await listenButton.trigger("click");
        await flushPromises();

        expect(wrapper.find(".listen-live-error").exists()).toBe(true);
    });

    it("has visualizer container", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".visualizer-container").exists()).toBe(true);
    });

    it("has playlist toggle button", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        expect(wrapper.find(".playlist-toggle").exists()).toBe(true);
    });

    it("shows playlist panel when toggle is clicked", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        // Initially hidden
        expect(wrapper.find(".playlist-panel").exists()).toBe(false);

        // Click toggle
        const toggleButton = wrapper.find(".playlist-toggle");
        await toggleButton.trigger("click");
        await flushPromises();

        // Now visible
        expect(wrapper.find(".playlist-panel").exists()).toBe(true);
    });

    it("keyboard controls are present", async () => {
        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        // Check that keyboard event listeners would be set up
        expect(wrapper.vm.handleKeyPress).toBeDefined();
    });

    it("cleans up on unmount", async () => {
        const mockCleanup = vi.fn();
        mockPlayer.cleanup = mockCleanup;

        await router.push("/radio");
        await router.isReady();

        wrapper = mount(RadioPage, {
            global: { plugins: [router] },
        });

        wrapper.unmount();

        // Cleanup should be called when component unmounts
        expect(mockCleanup).toHaveBeenCalled();
    });
});
