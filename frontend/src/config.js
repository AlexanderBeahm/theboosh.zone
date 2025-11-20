// Environment configuration
// Note: Using nullish coalescing (??) to allow empty strings for relative URLs
export const config = {
    apiUrl: import.meta.env.VITE_API_URL ?? "http://localhost:3000",
    environment: import.meta.env.VITE_ENVIRONMENT ?? "development",
    isDevelopment: import.meta.env.VITE_ENVIRONMENT === "development",
    isProduction: import.meta.env.VITE_ENVIRONMENT === "production",
    enableDebug: import.meta.env.VITE_ENABLE_DEBUG === "true",
    enableSwagger: import.meta.env.VITE_ENABLE_SWAGGER === "true",
};

// Configuration logging disabled
