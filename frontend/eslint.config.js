import js from "@eslint/js";
import pluginVue from "eslint-plugin-vue";

export default [
    // Apply recommended rules to all files
    js.configs.recommended,

    // Apply Vue.js recommended rules to Vue files
    ...pluginVue.configs["flat/recommended"],

    // Configure files to lint
    {
        files: ["src/**/*.{js,vue}"],
        languageOptions: {
            ecmaVersion: "latest",
            sourceType: "module",
            globals: {
                // Browser globals
                console: "readonly",
                window: "readonly",
                document: "readonly",
                navigator: "readonly",
                localStorage: "readonly",
                sessionStorage: "readonly",
                fetch: "readonly",
                FileReader: "readonly",
                FormData: "readonly",
                Blob: "readonly",
                setTimeout: "readonly",
                clearTimeout: "readonly",
                setInterval: "readonly",
                clearInterval: "readonly",
                alert: "readonly",
                confirm: "readonly",
                prompt: "readonly",
                URL: "readonly",
                URLSearchParams: "readonly",
                IntersectionObserver: "readonly",
                // Node/Test globals
                process: "readonly",
                global: "readonly",
                __dirname: "readonly",
                __filename: "readonly",
                module: "readonly",
                require: "readonly",
            },
        },
        rules: {
            "vue/multi-word-component-names": "off",
            "vue/no-v-html": "warn",
            "no-console": "warn",
            "no-debugger": "warn",
        },
    },
    // Relax rules for test files
    {
        files: ["**/*.spec.{js,vue}", "**/setup.js", "**/test-utils.js"],
        rules: {
            "no-unused-vars": "warn",
            "no-console": "off",
        },
    },
];
