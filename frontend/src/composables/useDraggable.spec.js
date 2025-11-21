import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { useDraggable } from "./useDraggable";

describe("useDraggable", () => {
    let mockElement;

    beforeEach(() => {
        // Create a mock element with classList
        mockElement = {
            classList: {
                add: vi.fn(),
                remove: vi.fn(),
            },
            getBoundingClientRect: vi.fn(() => ({
                width: 320,
                height: 200,
                top: 0,
                left: 0,
                right: 320,
                bottom: 200,
            })),
            parentElement: {
                getBoundingClientRect: vi.fn(() => ({
                    width: 1000,
                    height: 800,
                    top: 0,
                    left: 0,
                    right: 1000,
                    bottom: 800,
                })),
            },
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

    describe("Initialization", () => {
        it("should initialize with default position", () => {
            const { position } = useDraggable();

            expect(position.value).toEqual({ x: 0, y: 0 });
        });

        it("should initialize with provided position", () => {
            const { position } = useDraggable({
                initialX: 100,
                initialY: 200,
            });

            expect(position.value).toEqual({ x: 100, y: 200 });
        });

        it("should initialize isDragging as false", () => {
            const { isDragging } = useDraggable();

            expect(isDragging.value).toBe(false);
        });
    });

    describe("startDrag", () => {
        it("should set isDragging to true", () => {
            const { startDrag, isDragging } = useDraggable();
            const event = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(event);

            expect(isDragging.value).toBe(true);
        });

        it("should prevent default behavior", () => {
            const { startDrag } = useDraggable();
            const event = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(event);

            expect(event.preventDefault).toHaveBeenCalled();
        });

        it("should add is-dragging class to element", () => {
            const { startDrag } = useDraggable();
            const event = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(event);

            expect(mockElement.classList.add).toHaveBeenCalledWith(
                "is-dragging",
            );
        });

        it("should not start drag on INPUT elements", () => {
            const { startDrag, isDragging } = useDraggable();
            const event = {
                target: { tagName: "INPUT" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(event);

            expect(isDragging.value).toBe(false);
        });

        it("should not start drag on BUTTON elements", () => {
            const { startDrag, isDragging } = useDraggable();
            const event = {
                target: { tagName: "BUTTON" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(event);

            expect(isDragging.value).toBe(false);
        });

        it("should not start drag on TEXTAREA elements", () => {
            const { startDrag, isDragging } = useDraggable();
            const event = {
                target: { tagName: "TEXTAREA" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(event);

            expect(isDragging.value).toBe(false);
        });

        it("should not start drag on SELECT elements", () => {
            const { startDrag, isDragging } = useDraggable();
            const event = {
                target: { tagName: "SELECT" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(event);

            expect(isDragging.value).toBe(false);
        });

        it("should add mousemove and mouseup event listeners", () => {
            const addEventListenerSpy = vi.spyOn(
                document,
                "addEventListener",
            );
            const { startDrag } = useDraggable();
            const event = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(event);

            expect(addEventListenerSpy).toHaveBeenCalledWith(
                "mousemove",
                expect.any(Function),
            );
            expect(addEventListenerSpy).toHaveBeenCalledWith(
                "mouseup",
                expect.any(Function),
            );

            addEventListenerSpy.mockRestore();
        });
    });

    describe("Dragging", () => {
        it("should update position on mouse move", () => {
            const { startDrag, position } = useDraggable({
                initialX: 100,
                initialY: 100,
            });

            const startEvent = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 150,
                clientY: 150,
                preventDefault: vi.fn(),
            };

            startDrag(startEvent);

            // Simulate mouse move
            const moveEvent = new MouseEvent("mousemove", {
                clientX: 200,
                clientY: 250,
            });
            document.dispatchEvent(moveEvent);

            expect(position.value.x).toBe(150); // 100 + (200 - 150)
            expect(position.value.y).toBe(200); // 100 + (250 - 150)
        });

        it("should respect viewport bounds", () => {
            const { startDrag, position } = useDraggable({
                initialX: 100,
                initialY: 100,
                bounds: "viewport",
            });

            const startEvent = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 150,
                clientY: 150,
                preventDefault: vi.fn(),
            };

            startDrag(startEvent);

            // Try to move beyond viewport (width: 1920, element width: 320)
            const moveEvent = new MouseEvent("mousemove", {
                clientX: 2000,
                clientY: 150,
            });
            document.dispatchEvent(moveEvent);

            // Should be clamped to viewport width - element width
            expect(position.value.x).toBe(1600); // 1920 - 320
        });

        it("should respect parent bounds", () => {
            const { startDrag, position } = useDraggable({
                initialX: 100,
                initialY: 100,
                bounds: "parent",
            });

            const startEvent = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 150,
                clientY: 150,
                preventDefault: vi.fn(),
            };

            startDrag(startEvent);

            // Try to move beyond parent (width: 1000, element width: 320)
            const moveEvent = new MouseEvent("mousemove", {
                clientX: 1200,
                clientY: 150,
            });
            document.dispatchEvent(moveEvent);

            // Should be clamped to parent width - element width
            expect(position.value.x).toBe(680); // 1000 - 320
        });

        it("should not update position when not dragging", () => {
            const { position } = useDraggable({
                initialX: 100,
                initialY: 100,
            });

            // Simulate mouse move without starting drag
            const moveEvent = new MouseEvent("mousemove", {
                clientX: 200,
                clientY: 250,
            });
            document.dispatchEvent(moveEvent);

            // Position should not change
            expect(position.value.x).toBe(100);
            expect(position.value.y).toBe(100);
        });
    });

    describe("Drag End", () => {
        it("should set isDragging to false on mouse up", () => {
            const { startDrag, isDragging } = useDraggable();

            const startEvent = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(startEvent);
            expect(isDragging.value).toBe(true);

            // Simulate mouse up
            const upEvent = new MouseEvent("mouseup");
            document.dispatchEvent(upEvent);

            expect(isDragging.value).toBe(false);
        });

        it("should remove is-dragging class on mouse up", () => {
            const { startDrag } = useDraggable();

            const startEvent = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(startEvent);

            // Simulate mouse up
            const upEvent = new MouseEvent("mouseup");
            document.dispatchEvent(upEvent);

            expect(mockElement.classList.remove).toHaveBeenCalledWith(
                "is-dragging",
            );
        });

        it("should call onDragEnd callback with final position", () => {
            const onDragEnd = vi.fn();
            const { startDrag } = useDraggable({
                initialX: 100,
                initialY: 100,
                onDragEnd,
            });

            const startEvent = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 150,
                clientY: 150,
                preventDefault: vi.fn(),
            };

            startDrag(startEvent);

            // Move
            const moveEvent = new MouseEvent("mousemove", {
                clientX: 200,
                clientY: 250,
            });
            document.dispatchEvent(moveEvent);

            // End drag
            const upEvent = new MouseEvent("mouseup");
            document.dispatchEvent(upEvent);

            expect(onDragEnd).toHaveBeenCalledWith(150, 200);
        });

        it("should remove event listeners on mouse up", () => {
            const removeEventListenerSpy = vi.spyOn(
                document,
                "removeEventListener",
            );
            const { startDrag } = useDraggable();

            const startEvent = {
                target: { tagName: "DIV" },
                currentTarget: mockElement,
                clientX: 100,
                clientY: 100,
                preventDefault: vi.fn(),
            };

            startDrag(startEvent);

            // Simulate mouse up
            const upEvent = new MouseEvent("mouseup");
            document.dispatchEvent(upEvent);

            expect(removeEventListenerSpy).toHaveBeenCalledWith(
                "mousemove",
                expect.any(Function),
            );
            expect(removeEventListenerSpy).toHaveBeenCalledWith(
                "mouseup",
                expect.any(Function),
            );

            removeEventListenerSpy.mockRestore();
        });
    });

    describe("setPosition", () => {
        it("should update position programmatically", () => {
            const { position, setPosition } = useDraggable({
                initialX: 100,
                initialY: 100,
            });

            setPosition(300, 400);

            expect(position.value).toEqual({ x: 300, y: 400 });
        });

        it("should not trigger isDragging", () => {
            const { isDragging, setPosition } = useDraggable();

            setPosition(300, 400);

            expect(isDragging.value).toBe(false);
        });
    });
});
