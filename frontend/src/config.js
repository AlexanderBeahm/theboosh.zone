// Environment configuration
export const config = {
  apiUrl: import.meta.env.VITE_API_URL || 'http://localhost:3000',
  environment: import.meta.env.VITE_ENVIRONMENT || 'development',
  isDevelopment: import.meta.env.VITE_ENVIRONMENT === 'development',
  isProduction: import.meta.env.VITE_ENVIRONMENT === 'production',
  enableDebug: import.meta.env.VITE_ENABLE_DEBUG === 'true',
}

// Log configuration in non-production
if (!config.isProduction) {
  console.log('App Configuration:', config)
}
