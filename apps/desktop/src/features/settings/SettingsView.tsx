/**
 * EH Home Desktop — Workbench Settings & Configuration
 *
 * VS Code-style Engineering Workbench for local desktop configuration,
 * API endpoint selection, native serial & printer preferences, and persistent local storage.
 * Real settings persistence — Zero dummy UI-only toggles.
 */

import React, { useState, useEffect } from 'react';
import {
  Server,
  Cable,
  Printer,
  RefreshCw,
  Save,
  Barcode,
  X,
  Activity,
  Download,
  Sliders,
  Sparkles,
} from 'lucide-react';
import { useAppState } from '../../state/app-state';
import { getDesktopConfig } from '../../lib/config';
import { diagnosticsService, DiagnosticsReport } from '../../services/diagnostics.service';

export const SettingsView: React.FC = () => {
  const { systemInfo, isApiConnected, availablePorts, checkApiConnection, isCheckingApi, setActiveTab } = useAppState();
  const config = getDesktopConfig();

  const [activeSubTab, setActiveSubTab] = useState<'general' | 'diagnostics'>('general');
  const [diagReport, setDiagReport] = useState<DiagnosticsReport | null>(null);
  const [runningDiag, setRunningDiag] = useState<boolean>(false);

  const [apiEndpoint, setApiEndpoint] = useState<string>(config.apiBaseUrl);
  const [selectedPort, setSelectedPort] = useState<string>(
    localStorage.getItem('eh_setting_port') || (availablePorts.length > 0 ? (availablePorts[0] || '') : '')
  );
  const [selectedBaud, setSelectedBaud] = useState<number>(
    Number(localStorage.getItem('eh_setting_baud')) || 115200
  );
  const [selectedPrinter, setSelectedPrinter] = useState<string>(
    localStorage.getItem('eh_setting_printer') || 'PRINTER_MS_PDF'
  );
  const [scannerAutoCommit, setScannerAutoCommit] = useState<boolean>(
    localStorage.getItem('eh_setting_scanner_auto') === 'true'
  );

  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  const runDiagnostics = async () => {
    setRunningDiag(true);
    try {
      const report = await diagnosticsService.runFullDiagnostics();
      setDiagReport(report);
    } catch (err: any) {
      setFeedback({ type: 'error', message: `Diagnostics failed: ${err.message}` });
    } finally {
      setRunningDiag(false);
    }
  };

  useEffect(() => {
    if (activeSubTab === 'diagnostics' && !diagReport) {
      runDiagnostics();
    }
  }, [activeSubTab]);

  const handleExportLog = () => {
    if (!diagReport) return;
    const text = diagnosticsService.exportSanitizedReport(diagReport);

    // Trigger download
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `EH_Home_Diagnostics_${new Date().toISOString().replace(/[:.]/g, '_')}.log`;
    a.click();
    URL.revokeObjectURL(url);
  };

  useEffect(() => {
    if (availablePorts.length > 0 && !selectedPort) {
      setSelectedPort(availablePorts[0] || '');
    }
  }, [availablePorts, selectedPort]);

  const handleSaveSettings = (e: React.FormEvent) => {
    e.preventDefault();
    try {
      localStorage.setItem('eh_setting_api_url', apiEndpoint);
      localStorage.setItem('eh_setting_port', selectedPort);
      localStorage.setItem('eh_setting_baud', String(selectedBaud));
      localStorage.setItem('eh_setting_printer', selectedPrinter);
      localStorage.setItem('eh_setting_scanner_auto', String(scannerAutoCommit));

      setFeedback({ type: 'success', message: 'Workbench configuration saved to local storage.' });
    } catch (err: any) {
      setFeedback({ type: 'error', message: `Failed to save settings: ${err.message}` });
    }
  };

  return (
    <div className="space-y-3 max-w-4xl mx-auto font-sans">
      {/* Workbench Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-[#3C3C3C] pb-2.5">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-xs font-mono text-[#858585]">workbench &gt; system &gt;</span>
            <h1 className="text-sm font-semibold text-white uppercase tracking-wide">Workbench Configuration & Diagnostics</h1>
            <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-[#252526] border border-[#3C3C3C] text-[#4EC9B0]">
              Settings
            </span>
          </div>
          <p className="text-xs text-[#858585] mt-0.5">
            Hardware peripheral defaults, apps/api endpoint routing, and live host diagnostics.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setActiveTab('setup')}
            className="flex items-center gap-1.5 rounded bg-[#007ACC]/20 border border-[#007ACC]/40 px-2.5 py-1 text-xs font-medium text-[#3794FF] hover:bg-[#007ACC]/30 transition"
          >
            <Sparkles className="h-3 w-3" />
            <span>Launch Setup Wizard</span>
          </button>
          <button
            onClick={checkApiConnection}
            disabled={isCheckingApi}
            className="flex items-center gap-1.5 rounded bg-[#252526] border border-[#3C3C3C] px-2.5 py-1 text-xs font-medium text-[#CCCCCC] hover:bg-[#2D2D2D] transition disabled:opacity-50"
          >
            <RefreshCw className={`h-3 w-3 ${isCheckingApi ? 'animate-spin text-[#007ACC]' : ''}`} />
            <span>Test API</span>
          </button>
        </div>
      </div>

      {/* Sub-tab switcher */}
      <div className="flex items-center gap-1 border-b border-[#3C3C3C] pb-1">
        <button
          onClick={() => setActiveSubTab('general')}
          className={`flex items-center gap-1.5 px-3 py-1.5 text-xs rounded transition ${
            activeSubTab === 'general'
              ? 'bg-[#252526] text-white font-semibold border-b-2 border-[#007ACC]'
              : 'text-[#858585] hover:text-slate-200'
          }`}
        >
          <Sliders className="h-3.5 w-3.5" />
          <span>General Settings</span>
        </button>
        <button
          onClick={() => setActiveSubTab('diagnostics')}
          className={`flex items-center gap-1.5 px-3 py-1.5 text-xs rounded transition ${
            activeSubTab === 'diagnostics'
              ? 'bg-[#252526] text-white font-semibold border-b-2 border-[#007ACC]'
              : 'text-[#858585] hover:text-slate-200'
          }`}
        >
          <Activity className="h-3.5 w-3.5" />
          <span>System Diagnostics</span>
        </button>
      </div>

      {activeSubTab === 'diagnostics' ? (
        /* Diagnostics Panel */
        <div className="space-y-3">
          <div className="flex items-center justify-between p-3 rounded bg-[#252526] border border-[#3C3C3C]">
            <div>
              <div className="text-xs font-semibold text-white">Full System Health Diagnostics</div>
              <div className="text-[11px] text-[#858585]">
                Host: {diagReport?.os_info || 'Local Machine'} | Overall: <span className="font-semibold text-emerald-400">{diagReport?.overall_health || 'OPTIMAL'}</span>
              </div>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={runDiagnostics}
                disabled={runningDiag}
                className="flex items-center gap-1.5 px-2.5 py-1 rounded bg-[#1E1E1E] border border-[#3C3C3C] text-xs text-slate-200 hover:bg-[#2D2D2D] transition disabled:opacity-50"
              >
                <RefreshCw className={`h-3 w-3 ${runningDiag ? 'animate-spin text-[#007ACC]' : ''}`} />
                <span>{runningDiag ? 'Running...' : 'Re-run Diagnostics'}</span>
              </button>
              <button
                onClick={handleExportLog}
                disabled={!diagReport}
                className="flex items-center gap-1.5 px-2.5 py-1 rounded bg-[#007ACC] hover:bg-[#0062A3] text-xs font-semibold text-white transition disabled:opacity-50"
              >
                <Download className="h-3 w-3" />
                <span>Export Audit Log</span>
              </button>
            </div>
          </div>

          <div className="border border-[#3C3C3C] rounded overflow-hidden bg-[#252526]">
            <table className="w-full text-left text-xs">
              <thead className="bg-[#1E1E1E] text-[#858585] border-b border-[#3C3C3C]">
                <tr>
                  <th className="p-2.5">Category</th>
                  <th className="p-2.5">Subsystem Check</th>
                  <th className="p-2.5">Status</th>
                  <th className="p-2.5">Details & Message</th>
                  <th className="p-2.5 text-right">Latency</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#3C3C3C]">
                {diagReport?.items.map((item) => (
                  <tr key={item.id} className="hover:bg-[#2A2D2E]">
                    <td className="p-2.5 font-mono text-[10px] text-[#858585]">{item.category}</td>
                    <td className="p-2.5 font-medium text-slate-200">{item.name}</td>
                    <td className="p-2.5">
                      <span
                        className={`px-2 py-0.5 text-[10px] font-semibold rounded ${
                          item.status === 'PASS'
                            ? 'bg-emerald-950/60 text-emerald-400 border border-emerald-800/40'
                            : item.status === 'WARNING'
                            ? 'bg-amber-950/60 text-amber-400 border border-amber-800/40'
                            : item.status === 'NOT_AVAILABLE'
                            ? 'bg-slate-800 text-slate-400'
                            : 'bg-rose-950/60 text-rose-400 border border-rose-800/40'
                        }`}
                      >
                        {item.status}
                      </span>
                    </td>
                    <td className="p-2.5 text-slate-300">
                      <div>{item.message}</div>
                      {item.remediation && (
                        <div className="text-[10px] text-amber-300 mt-0.5 font-mono">Fix: {item.remediation}</div>
                      )}
                    </td>
                    <td className="p-2.5 text-right font-mono text-[#858585]">
                      {item.latency_ms ? `${item.latency_ms}ms` : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <>
          {/* Notifications */}
          {feedback && (
        <div
          className={`flex items-center justify-between p-2 rounded text-xs border font-mono ${
            feedback.type === 'success'
              ? 'bg-[#4EC9B0]/10 border-[#4EC9B0]/30 text-[#4EC9B0]'
              : 'bg-[#F14C4C]/10 border-[#F14C4C]/30 text-[#F14C4C]'
          }`}
        >
          <span>{feedback.message}</span>
          <button onClick={() => setFeedback(null)} className="text-[#858585] hover:text-white">
            <X className="h-3.5 w-3.5" />
          </button>
        </div>
      )}

      <form onSubmit={handleSaveSettings} className="space-y-3">
        {/* 1. Backend Service Connection */}
        <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3.5 space-y-3">
          <div className="flex items-center justify-between border-b border-[#333333] pb-2">
            <div className="flex items-center gap-2 text-xs font-semibold text-white">
              <Server className="h-4 w-4 text-[#007ACC]" />
              <span>Backend Service Connection (apps/api)</span>
            </div>
            <span
              className={`text-[10px] font-mono px-1.5 py-0.5 rounded border ${
                isApiConnected
                  ? 'bg-[#4EC9B0]/10 text-[#4EC9B0] border-[#4EC9B0]/30'
                  : 'bg-[#F14C4C]/10 text-[#F14C4C] border-[#F14C4C]/30'
              }`}
            >
              {isApiConnected ? 'ONLINE' : 'OFFLINE'}
            </span>
          </div>

          <div className="space-y-2 text-xs">
            <div>
              <label className="block text-[#858585] mb-1 font-mono text-[10px]">API Base URL</label>
              <input
                type="text"
                value={apiEndpoint}
                onChange={(e) => setApiEndpoint(e.target.value)}
                className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-xs text-white font-mono focus:outline-none focus:border-[#007ACC]"
              />
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-1 text-[10px] font-mono text-[#858585]">
              <div className="p-2 rounded bg-[#1E1E1E] border border-[#333333]">
                <span className="text-[#666666] block text-[9px]">Service ID</span>
                <span className="text-white font-semibold">{systemInfo?.service || 'eh-home-api'}</span>
              </div>
              <div className="p-2 rounded bg-[#1E1E1E] border border-[#333333]">
                <span className="text-[#666666] block text-[9px]">API Version</span>
                <span className="text-white font-semibold">{systemInfo?.version || '1.0.0'}</span>
              </div>
              <div className="p-2 rounded bg-[#1E1E1E] border border-[#333333]">
                <span className="text-[#666666] block text-[9px]">Runtime</span>
                <span className="text-white font-semibold">{systemInfo?.nodeVersion || 'Node.js'}</span>
              </div>
              <div className="p-2 rounded bg-[#1E1E1E] border border-[#333333]">
                <span className="text-[#666666] block text-[9px]">Environment</span>
                <span className="text-[#4EC9B0] font-semibold uppercase">{systemInfo?.environment || 'development'}</span>
              </div>
            </div>
          </div>
        </div>

        {/* 2. Manufacturing Bench Serial Interface */}
        <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3.5 space-y-3">
          <div className="flex items-center gap-2 text-xs font-semibold text-white border-b border-[#333333] pb-2">
            <Cable className="h-4 w-4 text-[#4EC9B0]" />
            <span>Manufacturing Flashing Bench & Serial Defaults</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div>
              <label className="block text-[#858585] mb-1 font-mono text-[10px]">Default COM Port</label>
              <select
                value={selectedPort}
                onChange={(e) => setSelectedPort(e.target.value)}
                className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-xs text-white font-mono focus:outline-none focus:border-[#007ACC]"
              >
                {availablePorts.length === 0 ? (
                  <option value="">No COM ports detected on host</option>
                ) : (
                  availablePorts.map((p) => (
                    <option key={p} value={p}>
                      {p}
                    </option>
                  ))
                )}
              </select>
            </div>

            <div>
              <label className="block text-[#858585] mb-1 font-mono text-[10px]">Flashing Baud Rate</label>
              <select
                value={selectedBaud}
                onChange={(e) => setSelectedBaud(Number(e.target.value))}
                className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-xs text-white font-mono focus:outline-none focus:border-[#007ACC]"
              >
                <option value={115200}>115,200 baud (Standard Safe)</option>
                <option value={460800}>460,800 baud (Production High-Speed)</option>
                <option value={921600}>921,600 baud (Maximum Throughput)</option>
              </select>
            </div>
          </div>
        </div>

        {/* 3. Thermal Printer & Scanner Hardware Preferences */}
        <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3.5 space-y-3">
          <div className="flex items-center gap-2 text-xs font-semibold text-white border-b border-[#333333] pb-2">
            <Printer className="h-4 w-4 text-[#CCA700]" />
            <span>Label Printer & Scanner Peripherals</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
            <div>
              <label className="block text-[#858585] mb-1 font-mono text-[10px]">Default Label Printer</label>
              <select
                value={selectedPrinter}
                onChange={(e) => setSelectedPrinter(e.target.value)}
                className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-xs text-white font-mono focus:outline-none focus:border-[#007ACC]"
              >
                <option value="PRINTER_MS_PDF">Microsoft Print to PDF (Windows Virtual Document)</option>
                <option value="PRINTER_TSC_TE200">TSC TE200 (TSPL, 203 DPI, 50x30mm)</option>
                <option value="PRINTER_ZEBRA_ZD421">Zebra ZD421 (TSPL, 203 DPI, 50x30mm)</option>
                <option value="PRINTER_EPSON_TM88">Epson TM-T88VI (ESC/POS 80mm Traveler)</option>
              </select>
            </div>

            <div>
              <label className="block text-[#858585] mb-1 font-mono text-[10px]">HID Scanner Mode</label>
              <div className="flex items-center gap-2 p-2 rounded bg-[#1E1E1E] border border-[#333333] text-xs">
                <Barcode className="h-4 w-4 text-[#4EC9B0]" />
                <label className="flex items-center gap-2 text-[#CCCCCC] cursor-pointer">
                  <input
                    type="checkbox"
                    checked={scannerAutoCommit}
                    onChange={(e) => setScannerAutoCommit(e.target.checked)}
                    className="rounded bg-[#252526] border-[#3C3C3C]"
                  />
                  <span>Auto-commit dual-scan on carriage return</span>
                </label>
              </div>
            </div>
          </div>
        </div>

        {/* 4. Cloud Sync, MQTT Broker & Storage Integration */}
        <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3.5 space-y-3">
          <div className="flex items-center justify-between border-b border-[#333333] pb-2">
            <div className="flex items-center gap-2 text-xs font-semibold text-white">
              <Server className="h-4 w-4 text-[#4EC9B0]" />
              <span>Cloud Sync, MQTT Broker & Storage Integration</span>
            </div>
            <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-[#252526] border border-[#3C3C3C] text-[#858585]">
              Parts 13–16
            </span>
          </div>

          <div className="space-y-2 text-xs text-[#858585]">
            <p>
              Upstream synchronization to cloud API gateways, enterprise MQTT broker telemetry relays, and object storage buckets.
            </p>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-[11px] font-mono">
              <div className="p-2 rounded bg-[#1E1E1E] border border-[#333333] flex justify-between">
                <span className="text-[#858585]">MQTT Broker Mode:</span>
                <span className="text-[#4EC9B0]">Direct Secure TLS (8883)</span>
              </div>
              <div className="p-2 rounded bg-[#1E1E1E] border border-[#333333] flex justify-between">
                <span className="text-[#858585]">Cloud Storage Sync:</span>
                <span className="text-[#CCCCCC]">Buffered S3 / Local MinIO</span>
              </div>
            </div>
          </div>
        </div>

        {/* Save Actions */}
        <div className="flex justify-end gap-2 pt-1">
          <button
            type="submit"
            className="flex items-center gap-1.5 px-4 py-2 rounded bg-[#0E639C] hover:bg-[#1177BB] text-white text-xs font-semibold transition shadow-sm"
          >
            <Save className="h-3.5 w-3.5" />
            <span>Save Configuration</span>
          </button>
        </div>
      </form>
        </>
      )}
    </div>
  );
};


