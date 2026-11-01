/**
 * Desktop Application Status Footer
 * Compact 22px VS Code-style workbench status bar.
 */

import React, { useState, useEffect } from 'react';
import { Cable, Barcode, ShieldCheck, Printer, Clock, Database, Radio } from 'lucide-react';
import { useAppState } from '../state/app-state';

export const StatusFooter: React.FC = () => {
  const { isApiConnected, apiStatusMessage, availablePorts, isScannerActive } = useAppState();
  const [currentTime, setCurrentTime] = useState<string>('');

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setCurrentTime(now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }));
    };
    updateTime();
    const timer = setInterval(updateTime, 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <footer className="flex h-[22px] min-h-[22px] w-full items-center justify-between border-t border-[#3C3C3C] bg-[#007ACC] px-2 text-[11px] text-white select-none font-sans z-50">
      {/* Left: Backend API & Environment Status */}
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-1.5 px-1 hover:bg-white/10 rounded cursor-pointer transition">
          <Database className="h-3 w-3" />
          <span className="font-mono text-[10px]">{isApiConnected ? 'API: Connected' : 'API: Offline'}</span>
        </div>

        <div className="flex items-center gap-1.5 px-1 hover:bg-white/10 rounded cursor-pointer transition">
          <Radio className="h-3 w-3" />
          <span className="text-[10px]">{apiStatusMessage}</span>
        </div>
      </div>

      {/* Right: Native Hardware Peripherals & Time */}
      <div className="flex items-center gap-3 font-mono text-[10px]">
        {/* Serial COM Ports */}
        <div className="flex items-center gap-1 px-1 hover:bg-white/10 rounded cursor-pointer transition" title="Detected Native Serial Interfaces">
          <Cable className="h-3 w-3" />
          <span>{availablePorts.length} COM Port{availablePorts.length === 1 ? '' : 's'}</span>
        </div>

        {/* Scanner HID */}
        <div className="flex items-center gap-1 px-1 hover:bg-white/10 rounded cursor-pointer transition" title="Dual-Scan Verification Status">
          <Barcode className="h-3 w-3" />
          <span>{isScannerActive ? 'Scanner: Ready' : 'Scanner: Standby'}</span>
        </div>

        {/* Windows Virtual / TSPL Printer */}
        <div className="flex items-center gap-1 px-1 hover:bg-white/10 rounded cursor-pointer transition" title="Label / Box Printer Status">
          <Printer className="h-3 w-3" />
          <span>TSPL/PDF Ready</span>
        </div>

        {/* Tauri Sandbox */}
        <div className="flex items-center gap-1 px-1 hover:bg-white/10 rounded cursor-pointer transition" title="Tauri v2 Native Security Boundary">
          <ShieldCheck className="h-3 w-3" />
          <span>Sandbox</span>
        </div>

        {/* Clock */}
        <div className="flex items-center gap-1 pl-1 border-l border-white/20">
          <Clock className="h-3 w-3" />
          <span>{currentTime}</span>
        </div>
      </div>
    </footer>
  );
};
