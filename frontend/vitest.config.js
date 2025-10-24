import { defineConfig } from "vitest/config";
import vue from "@vitejs/plugin-vue";
import path from "path";
import crypto from "crypto";

// Polyfill crypto.hash for Node 18 compatibility
if (!crypto.hash) {
    crypto.hash = function (algorithm, data) {
        return crypto.createHash(algorithm).update(data).digest("hex");
    };
}

export default defineConfig({
    plugins: [vue()],
    test: {
        globals: true,
        environment: "happy-dom",
        setupFiles: ["./src/setup.js"],
        coverage: {
            provider: "v8",
            reporter: ["text", "json", "html"],
            exclude: ["node_modules/", "dist/", "**/*.spec.js", "**/*.test.js"],
        },
    },
    resolve: {
        alias: {
            "@": path.resolve(__dirname, "./src"),
        },
    },
});
