/* global KeyboardEvent */
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { mount } from "@vue/test-utils";
import { createRouter, createMemoryHistory } from "vue-router";
import { ref } from "vue";
import RadioWidget from "./RadioWidget.vue";

// Mock composables
vi.mock("../composables/useRadioStore", () => ({
    useRadioStore: vi.fn(),
}));

vi.mock("../composables/useDraggable", () => ({
    useDraggable: vi.fn(),
}));

import { useRadioStore } from "../composables/useRadioStore";
import { useDraggable } from "../composables/useDraggable";

describe("RadioWidget", () => {
    let router;
    let mockPlayer;
    let mockWidgetState;
    let mockUserState;
    let mockStore;
    let mockDraggable;

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
                    path: "/visualizer",
                    name: "Visualizer",
                    component: { template: "<div>Visualizer</div>" },
                },
            ],
        });
    };

    beforeEach(() => {
        router = createRouterInstance();

        // Mock player
        mockPlayer = {
            audio: ref(null),
            playlist: ref([
                {
                    title: "Track 1",
                    artist: "Artist 1",
                    url: "http://example.com/track1.mp3",
                    duration: 180,
                },
                {
                    title: "Track 2",
                    artist: "Artist 2",
                    url: "http://example.com/track2.mp3",
                    duration: 200,
                },
            ]),
            currentIndex: ref(0),
            currentTrack: ref({
                title: "Track 1",
                artist: "Artist 1",
                url: "http://example.com/track1.mp3",
                duration: 180,
            }),
            isPlaying: ref(false),
            isLoading: ref(false),
            duration: ref(180),
            currentTime: ref(0),
            volume: ref(70),
            isMuted: ref(false),
            error: ref(""),
            hasNext: ref(true),
            hasPrevious: ref(false),
            progress: ref(0),
            play: vi.fn().mockResolvedValue(undefined),
            pause: vi.fn(),
            togglePlay: vi.fn(),
            next: vi.fn(),
            previous: vi.fn(),
            seek: vi.fn(),
            setVolume: vi.fn(),
            toggleMute: vi.fn(),
            loadTrack: vi.fn().mockResolvedValue(undefined),
        };

        // Mock widget state
        mockWidgetState = {
            isVisible: true,
            isMinimized: false,
            position: { x: 100, y: 100 },
        };

        // Mock user state
        mockUserState = {
            hasListened: false,
            hasUserInteracted: false,
            savedUserVolume: 70,
        };

        // Mock store
        mockStore = {
            player: mockPlayer,
            widgetState: mockWidgetState,
            userState: mockUserState,
            setWidgetPosition: vi.fn(),
            toggleMinimize: vi.fn(),
            restoreUserVolume: vi.fn(),
        };

        useRadioStore.mockReturnValue(mockStore);

        // Mock draggable
        mockDraggable = {
            position: ref({ x: 100, y: 100 }),
            isDragging: ref(false),
            startDrag: vi.fn(),
            setPosition: vi.fn(),
        };

        useDraggable.mockReturnValue(mockDraggable);

        // Mock localStorage
        global.localStorage = {
            getItem: vi.fn(),
            setItem: vi.fn(),
            removeItem: vi.fn(),
            clear: vi.fn(),
        };

        // Mock window dimensions
        Object.defineProperty(window, "innerWidth", {
            writable: true,
            configurable: true,
            value: 1920,
        });
        Object.defineProperty(window, "innerHeight", {
            writable: true,
            configurable: true,
            value: 1080,
        });
    });

    afterEach(() => {
        vi.clearAllMocks();
    });

    describe("Rendering", () => {
        it("should render widget when not on visualizer page", async () => {
            await router.push("/");
            await router.isReady();

            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".radio-widget").exists()).toBe(true);
        });

        it("should not render widget on visualizer page", async () => {
            await router.push("/visualizer");
            await router.isReady();

            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".radio-widget").exists()).toBe(false);
        });

        it("should render widget header with title", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".widget-title").text()).toContain("Radio");
        });

        it("should display current track information", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".track-title").text()).toBe("Track 1");
            expect(wrapper.find(".track-artist").text()).toBe("Artist 1");
        });

        it("should show loading state", async () => {
            mockPlayer.isLoading.value = true;
            mockPlayer.currentTrack.value = null;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".loading-text").text()).toBe("Buffering...");
        });

        it("should show error state", async () => {
            mockPlayer.error.value = "Failed to load track";
            mockPlayer.currentTrack.value = null;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".error-text").text()).toBe(
                "Failed to load track",
            );
        });

        it("should show no track message when no track loaded", async () => {
            mockPlayer.currentTrack.value = null;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".no-track").text()).toBe(
                "No radio configured",
            );
        });
    });

    describe("Mobile Detection", () => {
        it("should detect mobile when window width <= 768", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 768,
            });

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            await wrapper.vm.$nextTick();
            const widget = wrapper.find(".radio-widget");
            expect(widget.classes()).toContain("is-mobile");
        });

        it("should not detect mobile when window width > 768", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 1024,
            });

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            await wrapper.vm.$nextTick();
            const widget = wrapper.find(".radio-widget");
            expect(widget.classes()).not.toContain("is-mobile");
        });
    });

    describe("Dragging", () => {
        it("should initialize draggable with widget position", async () => {
            await router.push("/");
            mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(useDraggable).toHaveBeenCalledWith(
                expect.objectContaining({
                    initialX: mockWidgetState.position.x,
                    initialY: mockWidgetState.position.y,
                }),
            );
        });

        it("should call setWidgetPosition on drag end", async () => {
            await router.push("/");
            mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            // Get the onDragEnd callback that was passed to useDraggable
            const onDragEnd = useDraggable.mock.calls[0][0].onDragEnd;
            onDragEnd(200, 300);

            expect(mockStore.setWidgetPosition).toHaveBeenCalledWith(200, 300);
        });

        it("should call handleMouseDown on desktop", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 1920,
            });

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const widget = wrapper.find(".radio-widget");
            await widget.trigger("mousedown");

            expect(mockDraggable.startDrag).toHaveBeenCalled();
        });

        it("should not call startDrag on mobile", async () => {
            Object.defineProperty(window, "innerWidth", {
                writable: true,
                configurable: true,
                value: 768,
            });

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            await wrapper.vm.$nextTick();
            const widget = wrapper.find(".radio-widget");
            await widget.trigger("mousedown");

            expect(mockDraggable.startDrag).not.toHaveBeenCalled();
        });
    });

    describe("Playback Controls", () => {
        it("should show Listen Live button when not playing", async () => {
            mockPlayer.isPlaying.value = false;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".listen-live").exists()).toBe(true);
        });

        it("should call restoreUserVolume and play on Listen Live click", async () => {
            mockPlayer.isPlaying.value = false;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            await wrapper.find(".listen-live").trigger("click");

            expect(mockStore.restoreUserVolume).toHaveBeenCalled();
            expect(mockPlayer.play).toHaveBeenCalled();
        });

        it("should show pause button when playing", async () => {
            mockPlayer.isPlaying.value = true;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const pauseButton = wrapper.findAll("button").find((btn) => {
                const svg = btn.find("svg");
                return svg.exists() && svg.html().includes("<rect");
            });

            expect(pauseButton.exists()).toBe(true);
        });

        it("should call pause when pause button clicked", async () => {
            mockPlayer.isPlaying.value = true;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const pauseButton = wrapper.findAll(".play-btn").find((btn) => {
                const svg = btn.find("svg");
                return svg.exists() && svg.html().includes("<rect");
            });

            await pauseButton.trigger("click");

            expect(mockPlayer.pause).toHaveBeenCalled();
        });

        it("should disable Listen Live button when loading", async () => {
            mockPlayer.isLoading.value = true;
            mockPlayer.isPlaying.value = false;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const button = wrapper.find(".listen-live");
            expect(button.attributes("disabled")).toBeDefined();
        });
    });

    describe("Volume Control", () => {
        it("should call setVolume on volume slider change", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const slider = wrapper.find(".volume-slider");
            await slider.setValue(80);

            expect(mockPlayer.setVolume).toHaveBeenCalledWith(80);
        });

        it("should toggle mute on mute button click", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const muteButton = wrapper.find(".mute-btn");
            await muteButton.trigger("click");

            expect(mockPlayer.setVolume).toHaveBeenCalled();
        });

        it("should show unmute icon when volume is 0", async () => {
            mockPlayer.volume.value = 0;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const muteButton = wrapper.find(".mute-btn svg");
            // Check for the X icon (muted state)
            expect(muteButton.html()).toContain("<line");
        });
    });

    describe("Playlist Panel", () => {
        it("should toggle playlist visibility", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".widget-playlist-panel").exists()).toBe(false);

            const playlistButton = wrapper.find(".playlist-btn");
            await playlistButton.trigger("click");
            await wrapper.vm.$nextTick();

            expect(wrapper.find(".widget-playlist-panel").exists()).toBe(true);
        });

        it("should display playlist tracks", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const playlistButton = wrapper.find(".playlist-btn");
            await playlistButton.trigger("click");
            await wrapper.vm.$nextTick();

            const tracks = wrapper.findAll(".playlist-track");
            expect(tracks.length).toBe(2);
        });

        it("should load track on playlist track click", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const playlistButton = wrapper.find(".playlist-btn");
            await playlistButton.trigger("click");
            await wrapper.vm.$nextTick();

            const tracks = wrapper.findAll(".playlist-track");
            await tracks[1].trigger("click");

            expect(mockPlayer.loadTrack).toHaveBeenCalledWith(1);
        });

        it("should highlight active track in playlist", async () => {
            mockPlayer.currentIndex.value = 0;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const playlistButton = wrapper.find(".playlist-btn");
            await playlistButton.trigger("click");
            await wrapper.vm.$nextTick();

            const tracks = wrapper.findAll(".playlist-track");
            expect(tracks[0].classes()).toContain("active");
        });
    });

    describe("Minimize/Maximize", () => {
        it("should show minimize button", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".widget-btn").exists()).toBe(true);
        });

        it("should call toggleMinimize on button click", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const minimizeButton = wrapper.find(".widget-btn");
            await minimizeButton.trigger("click");

            expect(mockStore.toggleMinimize).toHaveBeenCalled();
        });

        it("should apply is-minimized class when minimized", async () => {
            mockWidgetState.isMinimized = true;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const widget = wrapper.find(".radio-widget");
            expect(widget.classes()).toContain("is-minimized");
        });

        it("should hide widget body when minimized", async () => {
            mockWidgetState.isMinimized = true;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".widget-body").exists()).toBe(false);
        });
    });

    describe("Keyboard Shortcuts", () => {
        it("should increase volume on ArrowUp key", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            mockPlayer.volume.value = 50;

            const event = new KeyboardEvent("keydown", { key: "ArrowUp" });
            document.dispatchEvent(event);

            expect(mockPlayer.setVolume).toHaveBeenCalledWith(55);
        });

        it("should decrease volume on ArrowDown key", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            mockPlayer.volume.value = 50;

            const event = new KeyboardEvent("keydown", { key: "ArrowDown" });
            document.dispatchEvent(event);

            expect(mockPlayer.setVolume).toHaveBeenCalledWith(45);
        });

        it("should toggle mute on M key", async () => {
            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const event = new KeyboardEvent("keydown", { key: "m" });
            document.dispatchEvent(event);

            expect(mockPlayer.toggleMute).toHaveBeenCalled();
        });

        it("should not handle keyboard shortcuts in input fields", async () => {
            await router.push("/");
            mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            // Create an input element
            const input = document.createElement("input");
            document.body.appendChild(input);
            input.focus();

            const event = new KeyboardEvent("keydown", {
                key: "ArrowUp",
                target: input,
            });
            Object.defineProperty(event, "target", {
                writable: false,
                value: input,
            });

            document.dispatchEvent(event);

            // setVolume should not have been called
            expect(mockPlayer.setVolume).not.toHaveBeenCalled();

            document.body.removeChild(input);
        });
    });

    describe("Progress Bar", () => {
        it("should display progress bar when track has duration", async () => {
            mockPlayer.duration.value = 180;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            expect(wrapper.find(".progress-bar").exists()).toBe(true);
        });

        it("should update progress bar width based on progress", async () => {
            mockPlayer.duration.value = 100;
            mockPlayer.currentTime.value = 50;
            mockPlayer.progress.value = 50;

            await router.push("/");
            const wrapper = mount(RadioWidget, {
                global: {
                    plugins: [router],
                    stubs: {
                        Teleport: true,
                    },
                },
            });

            const progressFill = wrapper.find(".progress-fill");
            expect(progressFill.attributes("style")).toContain("width: 50%");
        });
    });
});
