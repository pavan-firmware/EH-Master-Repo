import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { apiClient, SystemInfo } from '../services/api-client';
import { getSerialService } from '../services/native';

export type NavigationTab =
  | 'dashboard'
  | 'setup'
  | 'repositories'
  | 'products'
  | 'hardware'
  | 'firmware'
  | 'provisioner'
  | 'labels'
  | 'devices'
  | 'production'
  | 'packing'
  | 'inventory'
  | 'settings';

export interface AppStateContextValue {
  // UI State
  activeTab: NavigationTab;
  setActiveTab: (tab: NavigationTab) => void;

  // Server / API State
  isApiConnected: boolean;
  apiStatusMessage: string;
  systemInfo: SystemInfo | null;
  isCheckingApi: boolean;
  checkApiConnection: () => Promise<void>;

  // Native Capabilities State
  availablePorts: string[];
  isScannerActive: boolean;
  refreshNativeDevices: () => Promise<void>;
}

const AppStateContext = createContext<AppStateContextValue | undefined>(undefined);

export const AppStateProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [activeTab, setActiveTabState] = useState<NavigationTab>(() => {
    if (typeof window !== 'undefined' && window.localStorage) {
      const saved = window.localStorage.getItem('eh_active_tab') as NavigationTab;
      // Setup is an explicit diagnostics screen, never an application startup
      // gate. Older builds could persist `setup` and reopen it forever.
      if (saved && saved !== 'setup') return saved;
    }
    return 'dashboard';
  });
  const [isApiConnected, setIsApiConnected] = useState<boolean>(false);
  const [apiStatusMessage, setApiStatusMessage] = useState<string>('Checking backend...');
  const [systemInfo, setSystemInfo] = useState<SystemInfo | null>(null);
  const [isCheckingApi, setIsCheckingApi] = useState<boolean>(false);
  const [availablePorts, setAvailablePorts] = useState<string[]>([]);
  const [isScannerActive] = useState<boolean>(true);

  const setActiveTab = (tab: NavigationTab) => {
    setActiveTabState(tab);
    if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.setItem('eh_active_tab', tab);
    }
  };

  const checkApiConnection = useCallback(async () => {
    setIsCheckingApi(true);
    try {
      const health = await apiClient.checkHealth();
      if (health.success && health.data?.status === 'UP') {
        setIsApiConnected(true);
        setApiStatusMessage('Connected to apps/api');

        // Fetch system info
        const sys = await apiClient.getSystemInfo();
        if (sys.success && sys.data) {
          setSystemInfo(sys.data);
        }
      } else {
        setIsApiConnected(false);
        setApiStatusMessage(health.error?.message || 'API is not responding');
      }
    } catch (err: any) {
      setIsApiConnected(false);
      setApiStatusMessage(err.message || 'Connection failed');
    } finally {
      setIsCheckingApi(false);
    }
  }, []);

  const refreshNativeDevices = useCallback(async () => {
    try {
      const serial = getSerialService();
      const ports = await serial.listAvailablePorts();
      setAvailablePorts(ports.map((p) => p.portName));
    } catch {
      setAvailablePorts([]);
    }
  }, []);

  useEffect(() => {
    checkApiConnection();
    refreshNativeDevices();
  }, [checkApiConnection, refreshNativeDevices]);

  return (
    <AppStateContext.Provider
      value={{
        activeTab,
        setActiveTab,
        isApiConnected,
        apiStatusMessage,
        systemInfo,
        isCheckingApi,
        checkApiConnection,
        availablePorts,
        isScannerActive,
        refreshNativeDevices,
      }}
    >
      {children}
    </AppStateContext.Provider>
  );
};

export function useAppState(): AppStateContextValue {
  const ctx = useContext(AppStateContext);
  if (!ctx) {
    throw new Error('useAppState must be used within an AppStateProvider');
  }
  return ctx;
}
