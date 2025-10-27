import { createApp } from "vue";
import App from "./App.vue";
import router from "./router";
import "./assets/index.css";
import "./assets/styles.css";
import "./assets/syntax-highlighting.css";
import "./assets/fonts/atkinson-hyperlegible.css";

createApp(App).use(router).mount("#app");
