/**
 * Desktop Application Status Footer
 * Bottom telemetry bar showing API latency, ports count, and scanner status.
 */

import React from 'react';
import { Cable, Barcode, ShieldCheck } from 'lucide-react';
import { useAppState } from '../state/app-state';

export const StatusFooter: React.FC = () => {
  const { isApiConnected, apiStatusMessage, availablePorts, isScannerActive } = useAppState();

  return (
    <footer className="flex h-8 w-full items-center justify-between border-t border-surface-border bg-surface-darker px-4 text-[11px] text-slate-400 select-none">
      {/* Left: Backend API Status */}
      <div className="flex items-center gap-2">
        <span
          className={`h-2 w-2 rounded-full ${
            isApiConnected ? 'bg-emerald-400 shadow-sm shadow-emerald-400/50' : 'bg-rose-500'
          }`}
        />
        <span className="font-mono">{apiStatusMessage}</span>
      </div>

      {/* Right: Native Hardware Peripherals */}
      <div className="flex items-center gap-4">
        {/* Serial Ports */}
        <div className="flex items-center gap-1.5" title="Detected Serial Interfaces">
          <Cable className="h-3 w-3 text-slate-400" />
          <span>{availablePorts.length} COM Ports</span>
        </div>

        {/* Scanner */}
        <div className="flex items-center gap-1.5" title="Dual-Scan Verification Status">
          <Barcode className="h-3 w-3 text-slate-400" />
          <span>{isScannerActive ? 'Scanner Ready' : 'Scanner Inactive'}</span>
        </div>

        {/* Integrity */}
        <div className="flex items-center gap-1 text-slate-400">
          <ShieldCheck className="h-3 w-3 text-indigo-400" />
          <span>Tauri v2 Native Sandbox</span>
        </div>
      </div>
    </footer>
  );
};
