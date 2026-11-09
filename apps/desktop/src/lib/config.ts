/**
 * Desktop Application Configuration
 * Loads environment settings with safe local fallbacks.
 */

export interface DesktopConfig {
  apiBaseUrl: string;
  appEnv: 'development' | 'staging' | 'production' | 'test';
  enableDebugLogs: boolean;
  version: string;
}

export function getDesktopConfig(): DesktopConfig {
  return {
    apiBaseUrl: (import.meta as any).env?.VITE_API_BASE_URL || 'http://127.0.0.1:3100',
    appEnv: ((import.meta as any).env?.VITE_APP_ENV as any) || 'development',
    enableDebugLogs: (import.meta as any).env?.VITE_ENABLE_DEBUG_LOGS === 'true' || true,
    version: '1.0.0',
  };
}
