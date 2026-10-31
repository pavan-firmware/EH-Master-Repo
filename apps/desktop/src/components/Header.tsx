import React from 'react';
import { Wifi, WifiOff, RefreshCw } from 'lucide-react';
import { useAppState } from '../state/app-state';
import { getDesktopConfig } from '../lib/config';

export const Header: React.FC = () => {
  const { isApiConnected, isCheckingApi, checkApiConnection, activeTab } = useAppState();
  const config = getDesktopConfig();

  const getTabLabel = (tab: string) => {
    switch (tab) {
      case 'dashboard': return 'Workbench Dashboard';
      case 'setup': return 'System Setup & Calibration';
      case 'repositories': return 'Source Control & Repositories';
      case 'products': return 'Product & Variant Catalog';
      case 'hardware': return 'Hardware & Bill of Materials (BOM)';
      case 'firmware': return 'Firmware & Release Management';
      case 'provisioner': return 'Bench Provisioner & Flasher';
      case 'labels': return 'Manufacturing Label & QR Printer';
      case 'devices': return 'Device Fleet Management';
      case 'production': return 'Production & QC Verification';
      case 'packing': return 'Dual-Scan Packaging Station';
      case 'inventory': return 'Finished Goods Inventory';
      case 'settings': return 'Workbench Preferences';
      default: return tab;
    }
  };

  return (
    <header className="flex h-9 w-full items-center justify-between border-b border-[#3C3C3C] bg-[#181818] px-3 select-none text-[12.5px] text-[#CCCCCC]">
      {/* Brand & Active Breadcrumb */}
      <div className="flex items-center gap-2.5">
        <div className="flex items-center gap-2 font-semibold text-[#CCCCCC]">
          <img
            src="/branding/app_logo.png"
            alt="EH Home Logo"
            className="h-4 w-4 object-contain"
            onError={(e) => {
              // Fallback to logo.png if app_logo.png is unavailable
              (e.target as HTMLImageElement).src = '/branding/logo.png';
            }}
          />
          <span className="tracking-wide text-white text-[13px]">EH Home</span>
        </div>
        <span className="text-[#555555]">/</span>
        <span className="text-[#9D9D9D] font-mono text-[11.5px]">{getTabLabel(activeTab)}</span>
      </div>

      {/* Connection & Runtime Status */}
      <div className="flex items-center gap-3">
        {/* Backend API State */}
        <button
          onClick={checkApiConnection}
          disabled={isCheckingApi}
          className={`flex items-center gap-1.5 px-2 py-0.5 rounded text-[11px] font-mono transition border ${
            isApiConnected
              ? 'border-[#2E6B34] bg-[#1E3A21] text-[#4EC9B0] hover:bg-[#254929]'
              : 'border-[#6B2E2E] bg-[#3A1E1E] text-[#F48771] hover:bg-[#492525]'
          }`}
          title="Click to re-check API status"
        >
          {isCheckingApi ? (
            <RefreshCw className="h-2.5 w-2.5 animate-spin" />
          ) : isApiConnected ? (
            <Wifi className="h-2.5 w-2.5 text-[#4EC9B0]" />
          ) : (
            <WifiOff className="h-2.5 w-2.5 text-[#F48771]" />
          )}
          <span>{isApiConnected ? 'API: Connected' : 'API: Offline'}</span>
        </button>

        {/* Environment Indicator */}
        <span className="text-[10px] font-mono uppercase tracking-wider text-[#9D9D9D] px-1.5 py-0.5 rounded bg-[#252526] border border-[#3C3C3C]">
          {config.appEnv}
        </span>
      </div>
    </header>
  );
};

