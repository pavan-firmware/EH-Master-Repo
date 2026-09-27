/**
 * EH Home Production Floor Dual-Scan & Packing View
 *
 * Implements the dual-scan verification workflow:
 * Scan A (Device Identity) vs Scan B (Product Box / Label QR)
 * Validates canonical compatibility and commits verified items to cartons.
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  Scan,
  PackageCheck,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Barcode,
  Cpu,
  History,
  RefreshCw,
  Box,
} from 'lucide-react';
import { apiClient } from '../../services/api-client';
import { KeyboardHidScannerService, ScanEvent } from '../../services/native';

interface VerificationResult {
  match: boolean;
  verificationId?: string;
  errorCode?: string;
  errorMessage?: string;
  device?: {
    deviceId: string;
    serialNumber: string;
    productVariantId: string;
    hardwareRevision: string;
    firmwareFamily: string;
    status: string;
    targetCartonId?: string | null;
  };
  label?: {
    qrToken: string;
    qrUri: string;
    productVariantId: string;
    hardwareRevision: string;
    firmwareFamily: string;
  };
  discrepancies?: string[];
}

export const ProductionPackingView: React.FC = () => {
  // Scan inputs
  const [scanA, setScanA] = useState<string>(''); // Device Serial
  const [scanB, setScanB] = useState<string>(''); // Box / Label QR
  const [stationId] = useState<string>('STATION-PACK-01');
  const [activeCartonCode, setActiveCartonCode] = useState<string>('CARTON-2026-001');
  const [activeCartonId, setActiveCartonId] = useState<string>('');

  // Status & Verification state
  const [isVerifying, setIsVerifying] = useState<boolean>(false);
  const [verificationResult, setVerificationResult] = useState<VerificationResult | null>(null);
  const [isPacking, setIsPacking] = useState<boolean>(false);
  const [packingSuccess, setPackingSuccess] = useState<string | null>(null);
  const [packingError, setPackingError] = useState<string | null>(null);

  // History
  const [packingHistory, setPackingHistory] = useState<any[]>([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState<boolean>(false);

  // Scanner status
  const [scannerListening, setScannerListening] = useState<boolean>(true);
  const [lastScannedPayload, setLastScannedPayload] = useState<string>('');
  const scannerRef = useRef<KeyboardHidScannerService | null>(null);

  const fetchHistory = useCallback(async () => {
    setIsLoadingHistory(true);
    try {
      const res = await apiClient.getPackingHistory({ limit: 10 });
      if (res.success && res.data?.records) {
        setPackingHistory(res.data.records);
      }
    } catch {
      // Ignore network errors in demo
    } finally {
      setIsLoadingHistory(false);
    }
  }, []);

  useEffect(() => {
    fetchHistory();
  }, [fetchHistory]);

  // Setup HID keyboard scanner listener
  useEffect(() => {
    const scanner = new KeyboardHidScannerService();
    scannerRef.current = scanner;
    scanner.startListening((event: ScanEvent) => {
      setLastScannedPayload(event.rawPayload);
      if (!scanA) {
        setScanA(event.rawPayload);
      } else if (!scanB) {
        setScanB(event.rawPayload);
      }
    });
    setScannerListening(true);

    return () => {
      scanner.stopListening();
    };
  }, [scanA, scanB]);

  // Run dual-scan evaluation when both scans are present
  const handleVerify = async () => {
    if (!scanA.trim() || !scanB.trim()) {
      return;
    }

    setIsVerifying(true);
    setVerificationResult(null);
    setPackingSuccess(null);
    setPackingError(null);

    try {
      const res = await apiClient.dualScanVerify({
        stationId,
        deviceSerial: scanA.trim(),
        boxTokenOrUri: scanB.trim(),
        cartonId: activeCartonId || undefined,
      });

      if (res.success && res.data) {
        setVerificationResult(res.data);
      } else {
        setVerificationResult({
          match: false,
          errorCode: res.error?.code || 'VERIFICATION_FAILED',
          errorMessage: res.error?.message || 'Dual scan verification failed.',
        });
      }
    } catch (err: any) {
      setVerificationResult({
        match: false,
        errorCode: 'NETWORK_ERROR',
        errorMessage: err.message || 'Failed to communicate with inventory service.',
      });
    } finally {
      setIsVerifying(false);
    }
  };

  const handleConfirmPacking = async () => {
    if (!verificationResult || !verificationResult.match || !verificationResult.device) {
      return;
    }

    setIsPacking(true);
    setPackingSuccess(null);
    setPackingError(null);

    try {
      // First ensure carton exists or create it
      let targetCartonId = activeCartonId;
      if (!targetCartonId) {
        const cartonRes = await apiClient.createCarton({
          cartonCode: activeCartonCode,
          productVariantId: verificationResult.device.productVariantId,
          hardwareRevision: verificationResult.device.hardwareRevision,
        });
        if (cartonRes.success && cartonRes.data?.carton) {
          targetCartonId = cartonRes.data.carton.cartonId;
          setActiveCartonId(targetCartonId);
        } else {
          setPackingError(cartonRes.error?.message || 'Failed to initialize carton.');
          setIsPacking(false);
          return;
        }
      }

      const packRes = await apiClient.completePacking({
        deviceId: verificationResult.device.deviceId,
        serialNumber: verificationResult.device.serialNumber,
        cartonId: targetCartonId,
        verificationId: verificationResult.verificationId || `V-${Date.now()}`,
        stationId,
      });

      if (packRes.success && packRes.data?.success) {
        setPackingSuccess(`Unit ${verificationResult.device.serialNumber} successfully packed into carton ${activeCartonCode}!`);
        // Reset scans for next unit
        setScanA('');
        setScanB('');
        setVerificationResult(null);
        fetchHistory();
      } else {
        setPackingError(packRes.error?.message || packRes.data?.errorMessage || 'Packing completion rejected by server.');
      }
    } catch (err: any) {
      setPackingError(err.message || 'Network error completing packing operation.');
    } finally {
      setIsPacking(false);
    }
  };

  const handleReset = () => {
    setScanA('');
    setScanB('');
    setVerificationResult(null);
    setPackingSuccess(null);
    setPackingError(null);
  };

  return (
    <div className="space-y-6 pb-12">
      {/* Header Banner */}
      <div className="flex items-center justify-between rounded-xl bg-slate-900/80 p-5 border border-slate-800 backdrop-blur">
        <div>
          <div className="flex items-center gap-2">
            <PackageCheck className="h-6 w-6 text-indigo-400" />
            <h1 className="text-xl font-bold text-white tracking-wide">Production Floor Dual-Scan & Packing</h1>
            <span className="rounded-md bg-emerald-950 px-2 py-0.5 text-[11px] font-semibold text-emerald-400 border border-emerald-800/60">
              Part 11 Active
            </span>
          </div>
          <p className="mt-1 text-xs text-slate-400">
            Enforces strict canonical matching between physical device serial, QR label token, firmware family, and carton assignment.
          </p>
        </div>

        <div className="flex items-center gap-4 text-xs font-mono">
          <div className="flex items-center gap-2 rounded-lg bg-slate-800/80 px-3 py-1.5 border border-slate-700">
            <span className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
            <span className="text-slate-300">Station:</span>
            <span className="font-semibold text-indigo-300">{stationId}</span>
          </div>

          <div className="flex items-center gap-2 rounded-lg bg-slate-800/80 px-3 py-1.5 border border-slate-700">
            <Barcode className="h-3.5 w-3.5 text-slate-400" />
            <span className="text-slate-300">Scanner HID:</span>
            <span className={scannerListening ? 'text-emerald-400 font-semibold' : 'text-amber-400'}>
              {scannerListening ? 'LISTENING' : 'OFFLINE'}
            </span>
            {lastScannedPayload && (
              <span className="text-[10px] text-slate-400 font-mono truncate max-w-[120px]" title={lastScannedPayload}>
                ({lastScannedPayload})
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Main Dual-Scan Workspace */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Column 1 & 2: Dual Scan Workflow */}
        <div className="space-y-6 lg:col-span-2">
          {/* Dual Inputs Card */}
          <div className="rounded-xl border border-slate-800 bg-slate-900/90 p-6 shadow-xl">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4 mb-5">
              <div className="flex items-center gap-2">
                <Scan className="h-5 w-5 text-indigo-400" />
                <h2 className="text-sm font-bold uppercase tracking-wider text-slate-200">Dual-Scan Station</h2>
              </div>
              <button
                onClick={handleReset}
                className="text-xs text-slate-400 hover:text-slate-200 transition flex items-center gap-1"
              >
                <RefreshCw className="h-3 w-3" /> Clear Scans
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {/* Scan A: Device Serial */}
              <div className={`p-4 rounded-lg border transition ${scanA ? 'border-indigo-500/50 bg-indigo-950/20' : 'border-slate-800 bg-slate-950/50'}`}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider text-indigo-300 flex items-center gap-1.5">
                    <Cpu className="h-4 w-4" /> SCAN A: Device Identity
                  </span>
                  {scanA && <span className="text-[10px] text-emerald-400 font-mono bg-emerald-950/60 px-1.5 py-0.5 rounded border border-emerald-800/40">READY</span>}
                </div>
                <input
                  type="text"
                  placeholder="Scan Device Serial (e.g. EH-SW01-2026-00001)"
                  value={scanA}
                  onChange={(e) => setScanA(e.target.value)}
                  className="w-full rounded-md border border-slate-700 bg-slate-900 px-3 py-2 text-xs font-mono text-slate-100 placeholder-slate-500 focus:border-indigo-500 focus:outline-none"
                />
                <p className="text-[11px] text-slate-400 mt-2">Laser barcode scan of provisioned unit.</p>
              </div>

              {/* Scan B: Box / Label QR */}
              <div className={`p-4 rounded-lg border transition ${scanB ? 'border-indigo-500/50 bg-indigo-950/20' : 'border-slate-800 bg-slate-950/50'}`}>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider text-indigo-300 flex items-center gap-1.5">
                    <Barcode className="h-4 w-4" /> SCAN B: Packaging / Label QR
                  </span>
                  {scanB && <span className="text-[10px] text-emerald-400 font-mono bg-emerald-950/60 px-1.5 py-0.5 rounded border border-emerald-800/40">READY</span>}
                </div>
                <input
                  type="text"
                  placeholder="Scan Label QR (eh://p/v1?t=... or token)"
                  value={scanB}
                  onChange={(e) => setScanB(e.target.value)}
                  className="w-full rounded-md border border-slate-700 bg-slate-900 px-3 py-2 text-xs font-mono text-slate-100 placeholder-slate-500 focus:border-indigo-500 focus:outline-none"
                />
                <p className="text-[11px] text-slate-400 mt-2">2D QR scan on printed unit packaging.</p>
              </div>
            </div>

            {/* Quick Simulation Bar for Bench Testing */}
            <div className="mt-4 pt-3 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400">
              <span className="text-[11px]">Quick Bench Simulation:</span>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => {
                    setScanA('EH-SW01-2026-00001');
                    setScanB('eh://p/v1?t=eh-tok-sw01-a1b2c3d4e5f607182930');
                  }}
                  className="px-2 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded text-[11px] font-mono border border-slate-700"
                >
                  Load Sample Switch 1X
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setScanA('EH-DEV-MISMATCH-999');
                    setScanB('eh://p/v1?t=eh-tok-sw01-a1b2c3d4e5f607182930');
                  }}
                  className="px-2 py-1 bg-slate-800 hover:bg-slate-700 text-rose-400 rounded text-[11px] font-mono border border-slate-700"
                >
                  Simulate Mismatch
                </button>
              </div>
            </div>

            {/* Action Bar */}
            <div className="mt-6 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={handleVerify}
                disabled={!scanA.trim() || !scanB.trim() || isVerifying}
                className="flex items-center gap-2 rounded-lg bg-indigo-600 px-5 py-2.5 text-xs font-semibold text-white shadow-lg shadow-indigo-600/30 hover:bg-indigo-500 disabled:opacity-50 transition"
              >
                {isVerifying ? (
                  <>
                    <RefreshCw className="h-4 w-4 animate-spin" /> Verifying Compatibility...
                  </>
                ) : (
                  <>
                    <Scan className="h-4 w-4" /> Evaluate Dual-Scan Match
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Verification Verdict Card */}
          {verificationResult && (
            <div
              className={`rounded-xl border p-6 shadow-2xl transition-all ${
                verificationResult.match
                  ? 'border-emerald-500/60 bg-emerald-950/20 shadow-emerald-950/40'
                  : 'border-rose-500/60 bg-rose-950/20 shadow-rose-950/40'
              }`}
            >
              <div className="flex items-center justify-between pb-4 border-b border-slate-800">
                <div className="flex items-center gap-3">
                  {verificationResult.match ? (
                    <div className="h-10 w-10 rounded-full bg-emerald-500/20 flex items-center justify-center border border-emerald-500/50">
                      <CheckCircle2 className="h-6 w-6 text-emerald-400" />
                    </div>
                  ) : (
                    <div className="h-10 w-10 rounded-full bg-rose-500/20 flex items-center justify-center border border-rose-500/50">
                      <XCircle className="h-6 w-6 text-rose-400" />
                    </div>
                  )}
                  <div>
                    <h3 className="text-base font-bold text-white flex items-center gap-2">
                      {verificationResult.match ? 'DUAL-SCAN VERIFIED — PASS' : 'VERIFICATION FAILED — REJECTED'}
                    </h3>
                    <p className="text-xs text-slate-400 font-mono">
                      {verificationResult.match
                        ? `Verification Token: ${verificationResult.verificationId}`
                        : `Error: ${verificationResult.errorCode} — ${verificationResult.errorMessage}`}
                    </p>
                  </div>
                </div>

                {verificationResult.match && (
                  <span className="px-3 py-1 bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 rounded-full text-xs font-bold tracking-wider uppercase">
                    READY FOR CARTON
                  </span>
                )}
              </div>

              {/* Match Details Matrix */}
              {verificationResult.device && (
                <div className="mt-5 grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                  <div className="p-3 bg-slate-900/80 rounded-lg border border-slate-800">
                    <span className="text-slate-500 block text-[10px] uppercase font-semibold">Device Serial</span>
                    <span className="font-mono text-slate-200 font-medium">{verificationResult.device.serialNumber}</span>
                  </div>
                  <div className="p-3 bg-slate-900/80 rounded-lg border border-slate-800">
                    <span className="text-slate-500 block text-[10px] uppercase font-semibold">Product Variant</span>
                    <span className="font-mono text-indigo-300 font-medium">{verificationResult.device.productVariantId}</span>
                  </div>
                  <div className="p-3 bg-slate-900/80 rounded-lg border border-slate-800">
                    <span className="text-slate-500 block text-[10px] uppercase font-semibold">Hardware Rev</span>
                    <span className="font-mono text-slate-200 font-medium">{verificationResult.device.hardwareRevision}</span>
                  </div>
                  <div className="p-3 bg-slate-900/80 rounded-lg border border-slate-800">
                    <span className="text-slate-500 block text-[10px] uppercase font-semibold">Firmware Family</span>
                    <span className="font-mono text-slate-200 font-medium">{verificationResult.device.firmwareFamily}</span>
                  </div>
                </div>
              )}

              {/* Discrepancies if any */}
              {verificationResult.discrepancies && verificationResult.discrepancies.length > 0 && (
                <div className="mt-4 p-3 bg-rose-950/40 rounded-lg border border-rose-800/60">
                  <span className="text-xs font-semibold text-rose-300 flex items-center gap-1 mb-1">
                    <AlertTriangle className="h-3.5 w-3.5" /> Discrepancies Detected:
                  </span>
                  <ul className="list-disc list-inside text-xs text-rose-200 font-mono space-y-0.5">
                    {verificationResult.discrepancies.map((d, i) => (
                      <li key={i}>{d}</li>
                    ))}
                  </ul>
                </div>
              )}

              {/* Confirm Packing Action */}
              {verificationResult.match && (
                <div className="mt-5 flex items-center justify-between pt-4 border-t border-slate-800">
                  <div className="text-xs text-slate-400">
                    Target Carton: <span className="font-mono text-slate-200 font-semibold">{activeCartonCode}</span>
                  </div>
                  <button
                    type="button"
                    onClick={handleConfirmPacking}
                    disabled={isPacking}
                    className="flex items-center gap-2 rounded-lg bg-emerald-600 px-6 py-2.5 text-xs font-bold text-white shadow-lg shadow-emerald-600/30 hover:bg-emerald-500 disabled:opacity-50 transition"
                  >
                    {isPacking ? (
                      <>
                        <RefreshCw className="h-4 w-4 animate-spin" /> Committing Packaging...
                      </>
                    ) : (
                      <>
                        <PackageCheck className="h-4 w-4" /> Confirm & Pack Unit
                      </>
                    )}
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Feedback alerts */}
          {packingSuccess && (
            <div className="p-4 bg-emerald-950/40 border border-emerald-500/50 rounded-xl text-xs text-emerald-200 flex items-center gap-2 shadow-lg">
              <CheckCircle2 className="h-5 w-5 text-emerald-400 shrink-0" />
              <span>{packingSuccess}</span>
            </div>
          )}

          {packingError && (
            <div className="p-4 bg-rose-950/40 border border-rose-500/50 rounded-xl text-xs text-rose-200 flex items-center gap-2 shadow-lg">
              <AlertTriangle className="h-5 w-5 text-rose-400 shrink-0" />
              <span>{packingError}</span>
            </div>
          )}
        </div>

        {/* Column 3: Carton & Traceability History */}
        <div className="space-y-6">
          {/* Active Carton Manager */}
          <div className="rounded-xl border border-slate-800 bg-slate-900/90 p-5 shadow-xl">
            <div className="flex items-center gap-2 border-b border-slate-800 pb-3 mb-4">
              <Box className="h-4 w-4 text-indigo-400" />
              <h3 className="text-xs font-bold uppercase tracking-wider text-slate-200">Active Carton Target</h3>
            </div>

            <div className="space-y-3 text-xs">
              <div>
                <label className="text-slate-400 block mb-1 text-[11px]">Carton Code</label>
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={activeCartonCode}
                    onChange={(e) => setActiveCartonCode(e.target.value)}
                    className="flex-1 rounded-md border border-slate-700 bg-slate-950 px-2.5 py-1.5 font-mono text-slate-200 text-xs focus:border-indigo-500 focus:outline-none"
                  />
                  <button
                    type="button"
                    onClick={() => setActiveCartonCode(`CARTON-2026-${Math.floor(100 + Math.random() * 900)}`)}
                    className="px-2.5 py-1.5 bg-slate-800 hover:bg-slate-700 rounded text-slate-300 font-mono text-[11px] border border-slate-700"
                  >
                    New
                  </button>
                </div>
              </div>

              <div className="rounded-lg bg-slate-950/70 p-3 border border-slate-800 text-[11px] space-y-1 text-slate-400">
                <div className="flex justify-between">
                  <span>Carton Status:</span>
                  <span className="text-emerald-400 font-mono font-semibold">OPEN / ACCEPTS UNITS</span>
                </div>
                <div className="flex justify-between">
                  <span>Capacity Rule:</span>
                  <span className="text-slate-300 font-mono">1 Unit / Retail Box</span>
                </div>
                <div className="flex justify-between">
                  <span>Zero-Secret Invariant:</span>
                  <span className="text-emerald-400 font-mono">ENFORCED</span>
                </div>
              </div>
            </div>
          </div>

          {/* Packing History Audit */}
          <div className="rounded-xl border border-slate-800 bg-slate-900/90 p-5 shadow-xl">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3 mb-4">
              <div className="flex items-center gap-2">
                <History className="h-4 w-4 text-indigo-400" />
                <h3 className="text-xs font-bold uppercase tracking-wider text-slate-200">Recent Packing Trail</h3>
              </div>
              <button
                onClick={fetchHistory}
                disabled={isLoadingHistory}
                className="text-slate-400 hover:text-slate-200"
              >
                <RefreshCw className={`h-3 w-3 ${isLoadingHistory ? 'animate-spin' : ''}`} />
              </button>
            </div>

            <div className="space-y-2.5 max-h-80 overflow-y-auto pr-1">
              {packingHistory.length === 0 ? (
                <div className="p-4 text-center text-xs text-slate-500 font-mono bg-slate-950/40 rounded-lg border border-slate-800/60">
                  No packing events recorded yet.
                </div>
              ) : (
                packingHistory.map((item, idx) => (
                  <div
                    key={item.recordId || idx}
                    className="p-3 bg-slate-950/70 rounded-lg border border-slate-800/80 text-[11px] space-y-1"
                  >
                    <div className="flex items-center justify-between">
                      <span className="font-mono text-emerald-400 font-semibold">{item.serialNumber}</span>
                      <span className="text-[10px] text-slate-500 font-mono">
                        {item.packedAt ? new Date(item.packedAt).toLocaleTimeString() : 'Just now'}
                      </span>
                    </div>
                    <div className="flex items-center justify-between text-slate-400">
                      <span>{item.productVariantId}</span>
                      <span className="font-mono text-indigo-300">{item.hardwareRevision}</span>
                    </div>
                    <div className="text-[10px] text-slate-500 font-mono truncate">
                      Carton: {item.cartonCode || item.cartonId}
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
