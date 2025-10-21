import { defineConfig, loadEnv } from "vite";
import vue from "@vitejs/plugin-vue";
import path from "path";

export default defineConfig(({ mode }) => {
    // Load env file based on `mode` in the current working directory.
    const env = loadEnv(mode, process.cwd(), "");

    const isProduction = mode === "production";
    const isTest = mode === "test";

    console.log(`Building for mode: ${mode}`);
    console.log(`API URL: ${env.VITE_API_URL}`);

    return {
        plugins: [vue()],

        // Set base to /dist/ so assets are referenced correctly when served by Mojolicious
        base: "/dist/",

        build: {
            // Use 'dist' for Docker builds (will be copied to correct location by Dockerfile)
            // In local dev, this outputs to frontend/dist
            outDir: "dist",
            emptyOutDir: true,

            // Source maps only in development/staging
            sourcemap: !isProduction,

            // Production optimizations
            minify: isProduction ? "terser" : "esbuild",

            terserOptions: isProduction
                ? {
                      compress: {
                          drop_console: true,
                          drop_debugger: true,
                      },
                  }
                : {},

            rollupOptions: {
                output: {
                    manualChunks: isProduction
                        ? {
                              vendor: ["vue", "vue-router"],
                              markdown: ["marked", "highlight.js"],
                          }
                        : undefined,
                },
            },

            // Chunk size warnings
            chunkSizeWarningLimit: 1000,
        },

        server: {
            port: 5173,
            proxy: {
                "/api": {
                    target: env.VITE_API_URL || "http://localhost:3000",
                    changeOrigin: true,
                },
                "/swagger": {
                    target: env.VITE_API_URL || "http://localhost:3000",
                    changeOrigin: true,
                },
                "/swagger.json": {
                    target: env.VITE_API_URL || "http://localhost:3000",
                    changeOrigin: true,
                },
            },
        },

        resolve: {
            alias: {
                "@": path.resolve(__dirname, "./src"),
            },
        },

        // Test configuration
        test: {
            globals: true,
            environment: "happy-dom",
            coverage: {
                provider: "v8",
                reporter: ["text", "json", "html"],
            },
        },
    };
});
