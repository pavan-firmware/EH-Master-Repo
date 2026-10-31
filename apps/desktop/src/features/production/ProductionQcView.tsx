/**
 * EH Home Desktop — Production Batches & QC Station Logs (Parts 09 & 11)
 *
 * VS Code-style Engineering Workbench for manufacturing station traceability,
 * automated bench QC verification logs, flash diagnostics, and station pass/fail telemetry.
 * Real CRUD operations connected to apps/api — Zero dummy runtime data.
 */

import React, { useState, useEffect, useCallback } from 'react';
import {
  RefreshCw,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Plus,
  ClipboardCheck,
  X,
} from 'lucide-react';
import { apiClient } from '../../services/api-client';

interface QcStationLog {
  id?: string;
  logId?: string;
  stationId: string;
  stationType: string;
  deviceSerial: string;
  productVariantId?: string;
  status: 'PASS' | 'FAIL' | 'BLOCKED';
  operatorUserId: string;
  durationMs?: number;
  timestamp?: string;
  createdAt?: string;
  notes?: string;
}

export const ProductionQcView: React.FC = () => {
  const [logs, setLogs] = useState<QcStationLog[]>([]);
  const [selectedStation, setSelectedStation] = useState<string>('all');
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  // Modal & Form State
  const [isRecordQcOpen, setIsRecordQcOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [qcForm, setQcForm] = useState({
    stationId: 'BENCH-01',
    stationType: 'FLASHING_BENCH',
    deviceSerial: '',
    productVariantId: 'eh-smart-switch-1x',
    status: 'PASS' as 'PASS' | 'FAIL' | 'BLOCKED',
    operatorUserId: 'BENCH_OPERATOR',
    durationMs: 1200,
    notes: '',
  });

  const fetchQcLogs = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await apiClient.listQcRecords();
      if (res.success && Array.isArray(res.data)) {
        setLogs(res.data);
      } else {
        setLogs([]);
      }
    } catch (err: any) {
      setError(`Failed to query QC records from apps/api: ${err.message}`);
      setLogs([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchQcLogs();
  }, [fetchQcLogs]);

  const handleRecordQc = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!qcForm.deviceSerial.trim()) return;
    setIsSubmitting(true);
    try {
      const res = await apiClient.recordQcOperation({
        stationId: qcForm.stationId,
        stationType: qcForm.stationType,
        deviceSerial: qcForm.deviceSerial.trim(),
        productVariantId: qcForm.productVariantId,
        status: qcForm.status,
        operatorUserId: qcForm.operatorUserId,
        durationMs: Number(qcForm.durationMs),
        notes: qcForm.notes,
      });

      if (res.success) {
        setFeedback({ type: 'success', message: `QC operation recorded for ${qcForm.deviceSerial}.` });
        setIsRecordQcOpen(false);
        setQcForm({
          stationId: 'BENCH-01',
          stationType: 'FLASHING_BENCH',
          deviceSerial: '',
          productVariantId: 'eh-smart-switch-1x',
          status: 'PASS',
          operatorUserId: 'BENCH_OPERATOR',
          durationMs: 1200,
          notes: '',
        });
        await fetchQcLogs();
      } else {
        setFeedback({ type: 'error', message: res.error?.message || 'Failed to record QC operation' });
      }
    } catch (err: any) {
      setFeedback({ type: 'error', message: err.message });
    } finally {
      setIsSubmitting(false);
    }
  };

  const filteredLogs = logs.filter(
    (l) => selectedStation === 'all' || l.stationType === selectedStation
  );

  const passCount = filteredLogs.filter((l) => l.status === 'PASS').length;
  const failCount = filteredLogs.filter((l) => l.status === 'FAIL').length;
  const passRate = filteredLogs.length > 0 ? `${Math.round((passCount / filteredLogs.length) * 100)}%` : 'N/A';

  return (
    <div className="space-y-3 max-w-7xl mx-auto font-sans">
      {/* Workbench Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-[#3C3C3C] pb-2.5">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-xs font-mono text-[#858585]">workbench &gt; quality &gt;</span>
            <h1 className="text-sm font-semibold text-white uppercase tracking-wide">Production Batches & QC Logs</h1>
            <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-[#252526] border border-[#3C3C3C] text-[#4EC9B0]">
              Part 09 & 11
            </span>
          </div>
          <p className="text-xs text-[#858585] mt-0.5">
            Manufacturing station traceability, automated bench QC verification logs, flash diagnostics, and station pass/fail telemetry.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => setIsRecordQcOpen(true)}
            className="flex items-center gap-1.5 rounded bg-[#0E639C] hover:bg-[#1177BB] px-2.5 py-1 text-xs font-medium text-white transition"
          >
            <Plus className="h-3.5 w-3.5" />
            <span>Record QC Test</span>
          </button>
          <button
            onClick={fetchQcLogs}
            disabled={isLoading}
            className="flex items-center gap-1.5 rounded bg-[#252526] border border-[#3C3C3C] px-2.5 py-1 text-xs font-medium text-[#CCCCCC] hover:bg-[#2D2D2D] transition disabled:opacity-50"
            title="Refresh QC Logs"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${isLoading ? 'animate-spin text-[#007ACC]' : ''}`} />
          </button>
        </div>
      </div>

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

      {error && (
        <div className="flex items-center gap-2 rounded bg-[#CCA700]/10 border border-[#CCA700]/30 p-2 text-xs text-[#DCDCAA]">
          <AlertCircle className="h-4 w-4 shrink-0 text-[#CCA700]" />
          <span>{error}</span>
        </div>
      )}

      {/* Metrics Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
        <div className="p-2.5 rounded border border-[#3C3C3C] bg-[#252526]">
          <div className="text-[10px] text-[#858585] uppercase tracking-wider font-semibold mb-0.5">
            Total QC Operations
          </div>
          <div className="text-lg font-bold text-white font-mono">{filteredLogs.length}</div>
        </div>

        <div className="p-2.5 rounded border border-[#3C3C3C] bg-[#252526]">
          <div className="text-[10px] text-[#4EC9B0] uppercase tracking-wider font-semibold mb-0.5 flex items-center gap-1">
            <CheckCircle2 className="h-3 w-3" /> Passed
          </div>
          <div className="text-lg font-bold text-[#4EC9B0] font-mono">{passCount}</div>
        </div>

        <div className="p-2.5 rounded border border-[#3C3C3C] bg-[#252526]">
          <div className="text-[10px] text-[#F14C4C] uppercase tracking-wider font-semibold mb-0.5 flex items-center gap-1">
            <XCircle className="h-3 w-3" /> Failed
          </div>
          <div className="text-lg font-bold text-[#F14C4C] font-mono">{failCount}</div>
        </div>

        <div className="p-2.5 rounded border border-[#3C3C3C] bg-[#252526]">
          <div className="text-[10px] text-[#007ACC] uppercase tracking-wider font-semibold mb-0.5">
            First-Pass Yield (FPY)
          </div>
          <div className="text-lg font-bold text-[#007ACC] font-mono">{passRate}</div>
        </div>
      </div>

      {/* Station Filters */}
      <div className="flex flex-wrap gap-1 bg-[#252526] p-1.5 rounded border border-[#3C3C3C]">
        {[
          { id: 'all', label: 'All Stations' },
          { id: 'FLASHING_BENCH', label: 'Flashing Bench' },
          { id: 'RELAY_CYCLE', label: 'Relay Cycle QC' },
          { id: 'DUAL_SCAN_PACKING', label: 'Dual-Scan Packing' },
          { id: 'HIGH_POT_SAFETY', label: 'Hipot Safety' },
        ].map((s) => (
          <button
            key={s.id}
            onClick={() => setSelectedStation(s.id)}
            className={`px-2 py-0.5 text-xs font-medium rounded transition ${
              selectedStation === s.id
                ? 'bg-[#0E639C] text-white'
                : 'text-[#858585] hover:text-[#CCCCCC] hover:bg-[#333333]'
            }`}
          >
            {s.label}
          </button>
        ))}
      </div>

      {/* QC Logs Table */}
      <div className="rounded border border-[#3C3C3C] bg-[#252526] overflow-hidden">
        <div className="p-2.5 border-b border-[#3C3C3C] flex items-center justify-between bg-[#1E1E1E]">
          <span className="text-xs font-semibold uppercase tracking-wider text-[#858585]">
            Station Verification Audit Trail ({filteredLogs.length})
          </span>
          <span className="text-[10px] font-mono text-[#858585]">Append-Only Log</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-[#1E1E1E] text-[11px] font-semibold text-[#858585] border-b border-[#3C3C3C]">
              <tr>
                <th className="p-2.5 font-mono">Timestamp</th>
                <th className="p-2.5">Station</th>
                <th className="p-2.5 font-mono">Device Serial</th>
                <th className="p-2.5">Variant</th>
                <th className="p-2.5 font-mono">Operator</th>
                <th className="p-2.5 font-mono">Duration</th>
                <th className="p-2.5">Notes</th>
                <th className="p-2.5 text-right font-mono">Result</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#333333]">
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="p-6 text-center text-[#858585] font-mono">
                    Querying QC records from backend...
                  </td>
                </tr>
              ) : filteredLogs.length === 0 ? (
                <tr>
                  <td colSpan={8} className="p-8 text-center text-[#858585] font-mono">
                    <ClipboardCheck className="h-6 w-6 mx-auto mb-2 text-[#555555]" />
                    <p>No QC records logged yet.</p>
                    <button
                      onClick={() => setIsRecordQcOpen(true)}
                      className="mt-3 inline-flex items-center gap-1.5 px-3 py-1 bg-[#0E639C] hover:bg-[#1177BB] text-white rounded text-xs font-sans transition"
                    >
                      <Plus className="h-3 w-3" />
                      <span>Record First QC Test</span>
                    </button>
                  </td>
                </tr>
              ) : (
                filteredLogs.map((l, idx) => (
                  <tr key={l.id || l.logId || idx} className="hover:bg-[#2A2D2E] transition">
                    <td className="p-2.5 font-mono text-[#858585] text-[10px]">
                      {l.createdAt || l.timestamp ? new Date(l.createdAt || l.timestamp!).toLocaleTimeString() : '—'}
                    </td>
                    <td className="p-2.5 font-mono text-[#007ACC] font-medium">{l.stationId}</td>
                    <td className="p-2.5 font-mono text-white font-medium">{l.deviceSerial}</td>
                    <td className="p-2.5 text-[#CCCCCC]">{l.productVariantId || '—'}</td>
                    <td className="p-2.5 font-mono text-[#858585] text-[10px]">{l.operatorUserId}</td>
                    <td className="p-2.5 font-mono text-[#858585] text-[10px]">{l.durationMs ? `${l.durationMs}ms` : '—'}</td>
                    <td className="p-2.5 text-[#858585] text-[10px] max-w-xs truncate">{l.notes || '—'}</td>
                    <td className="p-2.5 text-right">
                      <span
                        className={`text-[10px] font-mono px-1.5 py-0.2 rounded border ${
                          l.status === 'PASS'
                            ? 'bg-[#4EC9B0]/10 text-[#4EC9B0] border-[#4EC9B0]/30'
                            : 'bg-[#F14C4C]/10 text-[#F14C4C] border-[#F14C4C]/30'
                        }`}
                      >
                        {l.status}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL: Record QC Test */}
      {isRecordQcOpen && (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50">
          <div className="rounded border border-[#3C3C3C] bg-[#252526] w-full max-w-md p-4 space-y-4 shadow-xl">
            <div className="flex items-center justify-between border-b border-[#333333] pb-2">
              <h3 className="text-sm font-semibold text-white">Record Station QC Test</h3>
              <button onClick={() => setIsRecordQcOpen(false)} className="text-[#858585] hover:text-white">
                <X className="h-4 w-4" />
              </button>
            </div>

            <form onSubmit={handleRecordQc} className="space-y-3 text-xs">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[#CCCCCC] mb-1 font-mono">Device Serial Number</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. EH-SW-2026-0001"
                    value={qcForm.deviceSerial}
                    onChange={(e) => setQcForm({ ...qcForm, deviceSerial: e.target.value })}
                    className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-white font-mono"
                  />
                </div>
                <div>
                  <label className="block text-[#CCCCCC] mb-1 font-mono">Product Variant</label>
                  <input
                    type="text"
                    required
                    value={qcForm.productVariantId}
                    onChange={(e) => setQcForm({ ...qcForm, productVariantId: e.target.value })}
                    className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-white font-mono"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[#CCCCCC] mb-1">Station ID</label>
                  <input
                    type="text"
                    required
                    value={qcForm.stationId}
                    onChange={(e) => setQcForm({ ...qcForm, stationId: e.target.value })}
                    className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-white font-mono"
                  />
                </div>
                <div>
                  <label className="block text-[#CCCCCC] mb-1">Station Type</label>
                  <select
                    value={qcForm.stationType}
                    onChange={(e) => setQcForm({ ...qcForm, stationType: e.target.value })}
                    className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-white font-mono"
                  >
                    <option value="FLASHING_BENCH">FLASHING_BENCH</option>
                    <option value="RELAY_CYCLE">RELAY_CYCLE</option>
                    <option value="DUAL_SCAN_PACKING">DUAL_SCAN_PACKING</option>
                    <option value="HIGH_POT_SAFETY">HIGH_POT_SAFETY</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[#CCCCCC] mb-1">QC Result</label>
                  <select
                    value={qcForm.status}
                    onChange={(e) => setQcForm({ ...qcForm, status: e.target.value as any })}
                    className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-white font-mono"
                  >
                    <option value="PASS">PASS</option>
                    <option value="FAIL">FAIL</option>
                    <option value="BLOCKED">BLOCKED</option>
                  </select>
                </div>
                <div>
                  <label className="block text-[#CCCCCC] mb-1">Operator ID</label>
                  <input
                    type="text"
                    value={qcForm.operatorUserId}
                    onChange={(e) => setQcForm({ ...qcForm, operatorUserId: e.target.value })}
                    className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-white font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[#CCCCCC] mb-1">QC Inspection Notes</label>
                <textarea
                  rows={2}
                  placeholder="Notes, measurements, or test metrics..."
                  value={qcForm.notes}
                  onChange={(e) => setQcForm({ ...qcForm, notes: e.target.value })}
                  className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2.5 py-1.5 text-white"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2 border-t border-[#333333]">
                <button
                  type="button"
                  onClick={() => setIsRecordQcOpen(false)}
                  className="px-3 py-1.5 rounded bg-[#1E1E1E] border border-[#3C3C3C] text-[#CCCCCC] hover:text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="px-3 py-1.5 rounded bg-[#0E639C] hover:bg-[#1177BB] text-white font-medium"
                >
                  {isSubmitting ? 'Recording...' : 'Save QC Record'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
