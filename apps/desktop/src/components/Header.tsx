/**
 * Desktop Application Header
 * Displays branding, backend connection indicator, and active environment.
 */

import React from 'react';
import { Cpu, Wifi, WifiOff, RefreshCw } from 'lucide-react';
import { useAppState } from '../state/app-state';
import { getDesktopConfig } from '../lib/config';

export const Header: React.FC = () => {
  const { isApiConnected, isCheckingApi, checkApiConnection } = useAppState();
  const config = getDesktopConfig();

  return (
    <header className="flex h-14 w-full items-center justify-between border-b border-surface-border bg-surface-dark px-4 select-none">
      {/* Brand Identity */}
      <div className="flex items-center gap-3">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-gradient-to-tr from-indigo-600 to-indigo-400 shadow-md shadow-indigo-600/20 text-white">
          <Cpu className="h-5 w-5" />
        </div>
        <div>
          <div className="flex items-center gap-2">
            <span className="font-bold text-sm tracking-wide text-slate-100">EH HOME</span>
            <span className="text-xs px-1.5 py-0.5 rounded font-mono font-medium bg-indigo-950/80 text-indigo-300 border border-indigo-800/60">
              ENG-WORKBENCH
            </span>
          </div>
          <span className="text-[11px] text-slate-400 block -mt-0.5">Manufacturing & Lifecycle Platform</span>
        </div>
      </div>

      {/* Connection & Status Indicators */}
      <div className="flex items-center gap-4">
        {/* Backend API Indicator */}
        <div
          onClick={checkApiConnection}
          className={`flex items-center gap-2 px-2.5 py-1 rounded-full text-xs font-medium border cursor-pointer transition ${
            isApiConnected
              ? 'bg-emerald-950/40 text-emerald-400 border-emerald-800/60 hover:bg-emerald-900/40'
              : 'bg-rose-950/40 text-rose-400 border-rose-800/60 hover:bg-rose-900/40'
          }`}
          title="Click to re-verify backend connectivity"
        >
          {isCheckingApi ? (
            <RefreshCw className="h-3 w-3 animate-spin text-slate-400" />
          ) : isApiConnected ? (
            <Wifi className="h-3 w-3 text-emerald-400" />
          ) : (
            <WifiOff className="h-3 w-3 text-rose-400" />
          )}
          <span>{isApiConnected ? 'API Online' : 'API Offline'}</span>
        </div>

        {/* Environment Tag */}
        <span className="text-[11px] uppercase tracking-wider font-mono text-slate-400 px-2 py-0.5 rounded bg-surface-card border border-surface-border">
          {config.appEnv}
        </span>
      </div>
    </header>
  );
};
