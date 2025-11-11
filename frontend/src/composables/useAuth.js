import { ref } from "vue";
import axios from "axios";
import { useRouter } from "vue-router";
import { useCSRF } from "./useCSRF";

// Shared authentication state
const isAuthenticated = ref(false);
const user = ref(null);
const isChecking = ref(false);

// Request caching to prevent duplicate auth checks
const authCache = {
    timestamp: 0,
    ttl: 5000, // 5 second cache
};

export function useAuth() {
    const router = useRouter();
    const { extractTokenFromResponse, clearToken } = useCSRF();

    /**
     * Check current authentication status
     * @returns {Promise<boolean>} Authentication status
     */
    async function checkAuth() {
        // Check if cache is still valid
        const now = Date.now();
        const cacheAge = now - authCache.timestamp;

        if (cacheAge < authCache.ttl && authCache.timestamp > 0) {
            // Return cached authentication state
            return isAuthenticated.value;
        }

        if (isChecking.value) {
            // Prevent multiple simultaneous auth checks
            return isAuthenticated.value;
        }

        isChecking.value = true;

        try {
            const response = await axios.get("/api/auth/status");

            if (response.data.authenticated) {
                isAuthenticated.value = true;
                user.value = response.data.user || null;

                // Extract CSRF token from auth status response
                extractTokenFromResponse(response.data);
            } else {
                isAuthenticated.value = false;
                user.value = null;
            }

            // Update cache timestamp
            authCache.timestamp = Date.now();

            return isAuthenticated.value;
        } catch {
            isAuthenticated.value = false;
            user.value = null;
            // Update cache timestamp even on error to prevent retry storms
            authCache.timestamp = Date.now();
            return false;
        } finally {
            isChecking.value = false;
        }
    }

    /**
     * Login with credentials
     * @param {string} username
     * @param {string} password
     * @returns {Promise<Object>} Login result
     */
    async function login(username, password) {
        try {
            const response = await axios.post("/api/auth/login", {
                username,
                password,
            });

            if (response.data.success) {
                // Update shared state
                isAuthenticated.value = true;
                user.value = response.data.user || { username };

                // Extract CSRF token from login response
                extractTokenFromResponse(response.data);

                // Invalidate cache to force fresh check
                authCache.timestamp = Date.now();

                return { success: true, user: user.value };
            } else {
                throw new Error(response.data.error || "Login failed");
            }
        } catch (err) {
            isAuthenticated.value = false;
            user.value = null;

            // Invalidate cache
            authCache.timestamp = 0;

            throw {
                message:
                    err.response?.data?.error ||
                    err.message ||
                    "Login failed. Please try again.",
            };
        }
    }

    /**
     * Logout current user
     * @param {string} redirectPath - Optional path to redirect after logout
     * @returns {Promise<void>}
     */
    async function logout(redirectPath = "/admin/login") {
        try {
            await axios.post("/api/auth/logout");
        } catch {
            // Continue with logout even if API call fails
        } finally {
            // Clear shared state
            isAuthenticated.value = false;
            user.value = null;

            // Clear CSRF token on logout
            clearToken();

            // Invalidate cache
            authCache.timestamp = 0;

            // Redirect to login page
            if (redirectPath) {
                router.push(redirectPath);
            }
        }
    }

    /**
     * Require authentication - redirect if not authenticated
     * @param {string} redirectPath - Where to redirect if not authenticated
     * @returns {Promise<boolean>} Whether user is authenticated
     */
    async function requireAuth(redirectPath = "/admin/login") {
        const authenticated = await checkAuth();

        if (!authenticated) {
            router.push(redirectPath);
            return false;
        }

        return true;
    }

    return {
        // State
        isAuthenticated,
        user,
        isChecking,

        // Methods
        checkAuth,
        login,
        logout,
        requireAuth,
    };
}
