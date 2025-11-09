import axios from "axios";
import { config } from "@/config";

// Configure the global axios defaults
axios.defaults.baseURL = config.apiUrl;
axios.defaults.withCredentials = true;
axios.defaults.headers.common["Content-Type"] = "application/json";

const apiClient = axios.create({
    baseURL: config.apiUrl,
    withCredentials: true,
    headers: {
        "Content-Type": "application/json",
    },
});

// Debug logging disabled - re-enable if needed for development

export default apiClient;
