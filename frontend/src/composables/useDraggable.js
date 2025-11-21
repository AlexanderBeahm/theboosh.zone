import { ref, onMounted, onUnmounted } from 'vue';

/**
 * Composable for making elements draggable
 *
 * Usage:
 * const { position, isDragging, startDrag } = useDraggable({
 *   initialX: 100,
 *   initialY: 100,
 *   onDragEnd: (x, y) => console.log('Dragged to', x, y)
 * });
 *
 * In template:
 * <div :style="{ left: position.x + 'px', top: position.y + 'px' }"
 *      @mousedown="startDrag">
 *   Drag me
 * </div>
 */
export function useDraggable(options = {}) {
    const {
        initialX = 0,
        initialY = 0,
        onDragEnd = null,
        bounds = 'viewport', // 'viewport' or 'parent' or null for no bounds
    } = options;

    const position = ref({ x: initialX, y: initialY });
    const isDragging = ref(false);

    let dragStartX = 0;
    let dragStartY = 0;
    let elementStartX = 0;
    let elementStartY = 0;
    let dragElement = null;

    /**
     * Start dragging
     */
    function startDrag(event) {
        // Prevent drag on form elements
        if (
            event.target.tagName === 'INPUT' ||
            event.target.tagName === 'BUTTON' ||
            event.target.tagName === 'TEXTAREA' ||
            event.target.tagName === 'SELECT'
        ) {
            return;
        }

        isDragging.value = true;
        dragStartX = event.clientX;
        dragStartY = event.clientY;
        elementStartX = position.value.x;
        elementStartY = position.value.y;

        // Store reference to the dragged element
        dragElement = event.currentTarget;

        // Prevent text selection during drag
        event.preventDefault();

        // Add event listeners
        document.addEventListener('mousemove', onMouseMove);
        document.addEventListener('mouseup', onMouseUp);

        // Add dragging class for styling
        if (dragElement) {
            dragElement.classList.add('is-dragging');
        }
    }

    /**
     * Handle mouse move during drag
     */
    function onMouseMove(event) {
        if (!isDragging.value) return;

        const deltaX = event.clientX - dragStartX;
        const deltaY = event.clientY - dragStartY;

        let newX = elementStartX + deltaX;
        let newY = elementStartY + deltaY;

        // Apply bounds if specified
        if (bounds === 'viewport' && dragElement) {
            const rect = dragElement.getBoundingClientRect();
            const viewportWidth = window.innerWidth;
            const viewportHeight = window.innerHeight;

            // Keep element within viewport bounds
            newX = Math.max(0, Math.min(newX, viewportWidth - rect.width));
            newY = Math.max(0, Math.min(newY, viewportHeight - rect.height));
        } else if (bounds === 'parent' && dragElement && dragElement.parentElement) {
            const rect = dragElement.getBoundingClientRect();
            const parentRect = dragElement.parentElement.getBoundingClientRect();

            // Keep element within parent bounds
            newX = Math.max(0, Math.min(newX, parentRect.width - rect.width));
            newY = Math.max(0, Math.min(newY, parentRect.height - rect.height));
        }

        position.value = { x: newX, y: newY };
    }

    /**
     * Handle mouse up - end drag
     */
    function onMouseUp() {
        if (!isDragging.value) return;

        isDragging.value = false;

        // Remove event listeners
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);

        // Remove dragging class
        if (dragElement) {
            dragElement.classList.remove('is-dragging');
        }

        // Call onDragEnd callback
        if (onDragEnd) {
            onDragEnd(position.value.x, position.value.y);
        }

        dragElement = null;
    }

    /**
     * Programmatically set position
     */
    function setPosition(x, y) {
        position.value = { x, y };
    }

    /**
     * Cleanup event listeners on unmount
     */
    onUnmounted(() => {
        document.removeEventListener('mousemove', onMouseMove);
        document.removeEventListener('mouseup', onMouseUp);
    });

    return {
        position,
        isDragging,
        startDrag,
        setPosition,
    };
}
