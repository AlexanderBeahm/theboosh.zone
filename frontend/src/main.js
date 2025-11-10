import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";
import "./assets/index.css";
import "./assets/styles.css";
import "./assets/syntax-highlighting.css";
import "./assets/fonts/atkinson-hyperlegible.css";

// Configure API client (must be imported before CSRF setup)
import "./api/client.js";

// Set up CSRF protection
import { setupCSRFInterceptor } from "./composables/useCSRF";
setupCSRFInterceptor();

createApp(App).use(router).mount("#app");
