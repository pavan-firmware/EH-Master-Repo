/**
 * Dashboard & System Health View
 * Implements Step 16: Desktop -> API Client -> apps/api connectivity proof.
 */

import React, { useState } from 'react';
import {
  Server,
  Activity,
  Cpu,
  Layers,
  CheckCircle2,
  XCircle,
  Send,
  RefreshCw,
  Barcode,
  Printer,
  Cable,
} from 'lucide-react';
import { useAppState } from '../../state/app-state';
import { apiClient } from '../../services/api-client';

export const DashboardView: React.FC = () => {
  const { isApiConnected, systemInfo, isCheckingApi, checkApiConnection } = useAppState();
  const [echoMessage, setEchoMessage] = useState('EH Home Desktop Handshake');
  const [echoResult, setEchoResult] = useState<string | null>(null);
  const [isSendingEcho, setIsSendingEcho] = useState(false);

  const handleSendEcho = async () => {
    if (!echoMessage.trim()) return;
    setIsSendingEcho(true);
    setEchoResult(null);
    try {
      const res = await apiClient.echo(echoMessage);
      if (res.success && res.data) {
        setEchoResult(`Echo response: "${res.data.echo}" [Received: ${new Date(res.data.receivedAt).toLocaleTimeString()}]`);
      } else {
        setEchoResult(`Echo failed: ${res.error?.message || 'Unknown error'}`);
      }
    } catch (err: any) {
      setEchoResult(`Echo error: ${err.message}`);
    } finally {
      setIsSendingEcho(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Title & Refresh */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-lg font-bold text-slate-100">Engineering & Manufacturing Workbench</h1>
          <p className="text-xs text-slate-400">
            Internal desktop platform coordinating apps/api backend and native manufacturing tooling.
          </p>
        </div>
        <button
          onClick={checkApiConnection}
          disabled={isCheckingApi}
          className="flex items-center gap-2 rounded-lg bg-surface-card border border-surface-border px-3 py-1.5 text-xs font-medium text-slate-200 hover:bg-surface-border/50 transition disabled:opacity-50"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${isCheckingApi ? 'animate-spin' : ''}`} />
          <span>Refresh Status</span>
        </button>
      </div>

      {/* Connectivity & Service Status Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* Backend API Card */}
        <div className="rounded-xl border border-surface-border bg-surface-dark p-4 shadow-sm">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2 text-xs font-semibold text-slate-300">
              <Server className="h-4 w-4 text-indigo-400" />
              <span>Backend Service (apps/api)</span>
            </div>
            {isApiConnected ? (
              <span className="flex items-center gap-1 text-[11px] font-medium text-emerald-400">
                <CheckCircle2 className="h-3.5 w-3.5" />
                <span>ONLINE</span>
              </span>
            ) : (
              <span className="flex items-center gap-1 text-[11px] font-medium text-rose-400">
                <XCircle className="h-3.5 w-3.5" />
                <span>OFFLINE</span>
              </span>
            )}
          </div>
          <div className="space-y-1.5 font-mono text-[11px] text-slate-400">
            <div className="flex justify-between">
              <span>Service:</span>
              <span className="text-slate-200">{systemInfo?.service || 'eh-home-api'}</span>
            </div>
            <div className="flex justify-between">
              <span>Version:</span>
              <span className="text-slate-200">{systemInfo?.version || '1.0.0'}</span>
            </div>
            <div className="flex justify-between">
              <span>Runtime:</span>
              <span className="text-slate-200">{systemInfo?.nodeVersion || 'Node.js'}</span>
            </div>
          </div>
        </div>

        {/* Database Layer Card */}
        <div className="rounded-xl border border-surface-border bg-surface-dark p-4 shadow-sm">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2 text-xs font-semibold text-slate-300">
              <Layers className="h-4 w-4 text-indigo-400" />
              <span>PostgreSQL & Drizzle</span>
            </div>
            <span className="text-[11px] font-mono text-indigo-400 bg-indigo-950/60 px-1.5 py-0.5 rounded border border-indigo-800/60">
              103 Tables
            </span>
          </div>
          <div className="space-y-1.5 font-mono text-[11px] text-slate-400">
            <div className="flex justify-between">
              <span>Migrations:</span>
              <span className="text-slate-200">001–029 (Frozen)</span>
            </div>
            <div className="flex justify-between">
              <span>Access Mode:</span>
              <span className="text-slate-200">apps/api Mediated</span>
            </div>
            <div className="flex justify-between">
              <span>Direct DB from UI:</span>
              <span className="text-emerald-400">Forbidden [Compliant]</span>
            </div>
          </div>
        </div>

        {/* Desktop Native Sandbox Card */}
        <div className="rounded-xl border border-surface-border bg-surface-dark p-4 shadow-sm">
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2 text-xs font-semibold text-slate-300">
              <Cpu className="h-4 w-4 text-indigo-400" />
              <span>Tauri v2 Native Runtime</span>
            </div>
            <span className="text-[11px] font-mono text-emerald-400 bg-emerald-950/60 px-1.5 py-0.5 rounded border border-emerald-800/60">
              SANDBOXED
            </span>
          </div>
          <div className="space-y-1.5 font-mono text-[11px] text-slate-400">
            <div className="flex justify-between">
              <span>Frontend:</span>
              <span className="text-slate-200">React + TypeScript</span>
            </div>
            <div className="flex justify-between">
              <span>Host OS:</span>
              <span className="text-slate-200">Windows (x64)</span>
            </div>
            <div className="flex justify-between">
              <span>Command Security:</span>
              <span className="text-slate-200">Explicit Whitelist</span>
            </div>
          </div>
        </div>
      </div>

      {/* Native Capability Abstractions */}
      <div className="rounded-xl border border-surface-border bg-surface-dark p-5">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-4 flex items-center gap-2">
          <Activity className="h-4 w-4 text-indigo-400" />
          <span>Manufacturing Hardware Service Abstractions</span>
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3 text-xs">
          <div className="p-3 rounded-lg bg-surface-card border border-surface-border flex items-start gap-3">
            <Cable className="h-5 w-5 text-indigo-400 shrink-0 mt-0.5" />
            <div>
              <div className="font-semibold text-slate-200">IFlasherService</div>
              <div className="text-[11px] text-slate-400">PythonSidecarFlasher</div>
              <div className="text-[10px] text-amber-400 mt-1 font-mono">Controlled Boundary</div>
            </div>
          </div>

          <div className="p-3 rounded-lg bg-surface-card border border-surface-border flex items-start gap-3">
            <Cable className="h-5 w-5 text-indigo-400 shrink-0 mt-0.5" />
            <div>
              <div className="font-semibold text-slate-200">ISerialService</div>
              <div className="text-[11px] text-slate-400">UART & ESP-IDF Logging</div>
              <div className="text-[10px] text-slate-400 mt-1 font-mono">COM Port Bridge</div>
            </div>
          </div>

          <div className="p-3 rounded-lg bg-surface-card border border-surface-border flex items-start gap-3">
            <Barcode className="h-5 w-5 text-indigo-400 shrink-0 mt-0.5" />
            <div>
              <div className="font-semibold text-slate-200">IScannerService</div>
              <div className="text-[11px] text-slate-400">HID / QR Scanner</div>
              <div className="text-[10px] text-emerald-400 mt-1 font-mono">Dual-Scan Enforcer</div>
            </div>
          </div>

          <div className="p-3 rounded-lg bg-surface-card border border-surface-border flex items-start gap-3">
            <Printer className="h-5 w-5 text-indigo-400 shrink-0 mt-0.5" />
            <div>
              <div className="font-semibold text-slate-200">IPrinterService</div>
              <div className="text-[11px] text-slate-400">Zebra / TSC TSPL</div>
              <div className="text-[10px] text-slate-400 mt-1 font-mono">Label & Box Printer</div>
            </div>
          </div>
        </div>
      </div>

      {/* Interactive Desktop-to-API Communication Test */}
      <div className="rounded-xl border border-surface-border bg-surface-dark p-5">
        <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-2 flex items-center gap-2">
          <Send className="h-4 w-4 text-indigo-400" />
          <span>Desktop → apps/api Interactive Probe</span>
        </h2>
        <p className="text-xs text-slate-400 mb-4">
          Tests HTTP client request correlation, Zod request body validation, and error contract handling.
        </p>

        <div className="flex gap-2 max-w-xl mb-3">
          <input
            type="text"
            value={echoMessage}
            onChange={(e) => setEchoMessage(e.target.value)}
            placeholder="Type a message to echo through apps/api..."
            className="flex-1 rounded-lg border border-surface-border bg-surface-card px-3 py-2 text-xs text-slate-200 placeholder-slate-500 focus:border-indigo-500 focus:outline-none"
          />
          <button
            onClick={handleSendEcho}
            disabled={isSendingEcho}
            className="flex items-center gap-1.5 rounded-lg bg-indigo-600 px-4 py-2 text-xs font-semibold text-white shadow-sm shadow-indigo-600/30 hover:bg-indigo-500 transition disabled:opacity-50"
          >
            {isSendingEcho ? <RefreshCw className="h-3.5 w-3.5 animate-spin" /> : <Send className="h-3.5 w-3.5" />}
            <span>Send Probe</span>
          </button>
        </div>

        {echoResult && (
          <div className="p-3 rounded-lg bg-surface-card border border-surface-border font-mono text-xs text-slate-300">
            {echoResult}
          </div>
        )}
      </div>
    </div>
  );
};
