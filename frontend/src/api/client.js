import axios from "axios";
import { config } from "@/config";

const apiClient = axios.create({
    baseURL: config.apiUrl,
    withCredentials: true,
    headers: {
        "Content-Type": "application/json",
    },
});

// Debug logging disabled - re-enable if needed for development

export default apiClient;
