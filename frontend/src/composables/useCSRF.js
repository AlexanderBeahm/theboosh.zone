import { ref, watch } from "vue";
import axios from "axios";

// Shared CSRF state
const csrfToken = ref(null);
const tokenExpiry = ref(null);
const isRefreshing = ref(false);

/**
 * CSRF Token Management Composable
 * Handles automatic CSRF token fetching, caching, and refresh
 */
export function useCSRF() {
    /**
     * Get current CSRF token (from cache or fetch new)
     * @returns {Promise<string|null>} CSRF token or null if failed
     */
    async function getToken() {
        // Check if we have a valid cached token
        if (
            csrfToken.value &&
            tokenExpiry.value &&
            Date.now() < tokenExpiry.value
        ) {
            return csrfToken.value;
        }

        // Refresh token if needed
        await refreshToken();
        return csrfToken.value;
    }

    /**
     * Fetch a fresh CSRF token from the server
     * @returns {Promise<boolean>} Success status
     */
    async function refreshToken() {
        if (isRefreshing.value) {
            // Wait for existing refresh to complete
            return new Promise((resolve) => {
                const unwatch = watch(isRefreshing, (newVal) => {
                    if (!newVal) {
                        unwatch();
                        resolve(csrfToken.value !== null);
                    }
                });
            });
        }

        isRefreshing.value = true;

        try {
            const response = await axios.get("/api/csrf-token");

            if (response.data.success && response.data.data) {
                const { csrf_token, expires_in } = response.data.data;

                csrfToken.value = csrf_token;
                // Set expiry to 90% of server expiry to refresh before it expires
                tokenExpiry.value = Date.now() + expires_in * 1000 * 0.9;

                return true;
            } else {
                clearToken();
                return false;
            }
        } catch {
            clearToken();
            return false;
        } finally {
            isRefreshing.value = false;
        }
    }

    /**
     * Extract CSRF token from authentication responses
     * @param {Object} responseData - API response data
     */
    function extractTokenFromResponse(responseData) {
        if (
            responseData &&
            responseData.csrf_token &&
            responseData.expires_in
        ) {
            csrfToken.value = responseData.csrf_token;
            tokenExpiry.value =
                Date.now() + responseData.expires_in * 1000 * 0.9;
        }
    }

    /**
     * Clear cached token (e.g., on logout)
     */
    function clearToken() {
        csrfToken.value = null;
        tokenExpiry.value = null;
    }

    /**
     * Check if token needs refresh (within 5 minutes of expiry)
     * @returns {boolean} Whether token needs refresh
     */
    function needsRefresh() {
        if (!csrfToken.value || !tokenExpiry.value) {
            return true;
        }

        // Refresh if token expires within 5 minutes
        const fiveMinutes = 5 * 60 * 1000;
        return Date.now() + fiveMinutes >= tokenExpiry.value;
    }

    /**
     * Get token info for debugging
     * @returns {Object} Token info
     */
    function getTokenInfo() {
        return {
            hasToken: !!csrfToken.value,
            expiry: tokenExpiry.value
                ? new Date(tokenExpiry.value).toISOString()
                : null,
            needsRefresh: needsRefresh(),
            isRefreshing: isRefreshing.value,
        };
    }

    return {
        // State
        csrfToken,
        tokenExpiry,
        isRefreshing,

        // Methods
        getToken,
        refreshToken,
        extractTokenFromResponse,
        clearToken,
        needsRefresh,
        getTokenInfo,
    };
}

/**
 * Axios request interceptor to add CSRF tokens automatically
 */
export function setupCSRFInterceptor() {
    const { getToken } = useCSRF();

    // Request interceptor - add CSRF token to requests
    axios.interceptors.request.use(
        async (config) => {
            // Only add CSRF token to non-GET requests
            if (config.method && config.method.toLowerCase() !== "get") {
                try {
                    const token = await getToken();
                    if (token) {
                        config.headers["X-CSRF-Token"] = token;
                    }
                } catch {
                    // Failed to get CSRF token
                }
            }
            return config;
        },
        (error) => {
            return Promise.reject(error);
        },
    );

    // Response interceptor - handle CSRF token refresh on 403 errors
    axios.interceptors.response.use(
        (response) => {
            return response;
        },
        async (error) => {
            const { refreshToken, getToken } = useCSRF();

            // Handle CSRF validation failures
            if (
                error.response?.status === 403 &&
                error.response?.data?.error === "CSRF validation failed"
            ) {
                // Try to refresh token and retry the request
                const refreshSuccess = await refreshToken();
                if (refreshSuccess && error.config && !error.config._retry) {
                    error.config._retry = true;

                    // Add fresh token to the retry request
                    const newToken = await getToken();
                    if (newToken) {
                        error.config.headers["X-CSRF-Token"] = newToken;
                        return axios.request(error.config);
                    }
                }
            }

            return Promise.reject(error);
        },
    );
}
