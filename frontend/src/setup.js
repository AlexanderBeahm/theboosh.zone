import { vi } from "vitest";

// Mock IntersectionObserver (used for infinite scroll)
global.IntersectionObserver = class IntersectionObserver {
    constructor(callback, options) {
        this.callback = callback;
        this.options = options;
    }

    observe(target) {
        // Immediately trigger callback for testing
        this.callback([
            {
                target,
                isIntersecting: true,
                intersectionRatio: 1,
            },
        ]);
    }

    unobserve() {
        // No-op for testing
    }

    disconnect() {
        // No-op for testing
    }
};

// Mock localStorage
const localStorageMock = {
    getItem: vi.fn(() => null),
    setItem: vi.fn(() => null),
    removeItem: vi.fn(() => null),
    clear: vi.fn(() => null),
};

global.localStorage = localStorageMock;

// Mock sessionStorage
const sessionStorageMock = {
    getItem: vi.fn(() => null),
    setItem: vi.fn(() => null),
    removeItem: vi.fn(() => null),
    clear: vi.fn(() => null),
};

global.sessionStorage = sessionStorageMock;

// Mock window.matchMedia (used for responsive design checks)
Object.defineProperty(window, "matchMedia", {
    writable: true,
    value: vi.fn().mockImplementation((query) => ({
        matches: false,
        media: query,
        onchange: null,
        addListener: vi.fn(),
        removeListener: vi.fn(),
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
        dispatchEvent: vi.fn(),
    })),
});

// Mock URL.createObjectURL (used for image previews)
global.URL.createObjectURL = vi.fn(() => `blob:mock-url-${Date.now()}`);
global.URL.revokeObjectURL = vi.fn();

// Mock File and Blob constructors for file upload testing
global.File = class File extends Blob {
    constructor(bits, name, options = {}) {
        super(bits, options);
        this.name = name;
        this.lastModified = options.lastModified || Date.now();
    }
};

// Mock FileReader for image preview testing
global.FileReader = class FileReader {
    constructor() {
        this.result = null;
        this.error = null;
        this.readyState = 0;
        this.onload = null;
        this.onerror = null;
    }

    readAsDataURL() {
        this.readyState = 2;
        this.result =
            "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==";

        if (this.onload) {
            this.onload({ target: this });
        }
    }

    readAsText() {
        this.readyState = 2;
        this.result = "mock file content";

        if (this.onload) {
            this.onload({ target: this });
        }
    }

    abort() {
        this.readyState = 0;
    }
};

// Mock console methods to reduce noise in tests (optional)
// Uncomment if you want to suppress console output during tests
// global.console = {
//   ...console,
//   log: vi.fn(),
//   debug: vi.fn(),
//   info: vi.fn(),
//   warn: vi.fn(),
//   error: vi.fn(),
// }
