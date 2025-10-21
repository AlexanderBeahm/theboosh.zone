import axios from 'axios'
import { config } from '@/config'

const apiClient = axios.create({
  baseURL: config.apiUrl,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Add debug logging in development
if (config.enableDebug) {
  apiClient.interceptors.request.use(request => {
    console.log('[API Request]', request.method.toUpperCase(), request.url)
    return request
  })

  apiClient.interceptors.response.use(
    response => {
      console.log('[API Response]', response.status, response.config.url)
      return response
    },
    error => {
      console.error('[API Error]', error.response?.status, error.config?.url)
      return Promise.reject(error)
    }
  )
}

export default apiClient
