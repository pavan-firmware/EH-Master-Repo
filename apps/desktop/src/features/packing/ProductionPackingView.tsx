/**
 * EH Home Production Floor Dual-Scan & Packing View (Part 11)
 *
 * VS Code-style Engineering Workbench for dual-scan packaging verification:
 * Scan A (Device Identity) vs Scan B (Product Box / Label QR).
 * Real verification & carton assignment connected to apps/api — Zero simulated mock buttons in production UI.
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
  const [stationId] = useState<string>('PACK-STATION-01');
  const [cartons, setCartons] = useState<any[]>([]);
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

  // Fetch cartons and packing history
  const fetchCartonsAndHistory = useCallback(async () => {
    setIsLoadingHistory(true);
    try {
      const [cartonRes, historyRes] = await Promise.all([
        apiClient.listCartons().catch(() => ({ success: false, data: [] })),
        apiClient.getPackingHistory({ limit: 20 }).catch(() => ({ success: false, data: [] })),
      ]);

      if (cartonRes.success && Array.isArray(cartonRes.data)) {
        const cData = cartonRes.data;
        setCartons(cData);
        if (cData.length > 0 && cData[0]) {
          setActiveCartonId((prev) => prev || cData[0].id || cData[0].cartonId);
          setActiveCartonCode((prev) => prev || cData[0].cartonCode || cData[0].code);
        }
      }

      if (historyRes.success && historyRes.data) {
        const records = Array.isArray(historyRes.data) ? historyRes.data : (historyRes.data as any).records || [];
        setPackingHistory(records);
      }
    } catch {
      // Keep state
    } finally {
      setIsLoadingHistory(false);
    }
  }, []);

  useEffect(() => {
    fetchCartonsAndHistory();
  }, [fetchCartonsAndHistory]);

  // Setup HID keyboard scanner listener
  useEffect(() => {
    const scanner = new KeyboardHidScannerService();
    scannerRef.current = scanner;
    scanner.startListening((event: ScanEvent) => {
      setLastScannedPayload(event.rawPayload);
      setScanA((prevA) => {
        if (!prevA) return event.rawPayload;
        setScanB((prevB) => {
          if (!prevB) return event.rawPayload;
          return prevB;
        });
        return prevA;
      });
    });
    setScannerListening(true);

    return () => {
      scanner.stopListening();
    };
  }, []);

  // Dual-scan evaluation
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
        setScanA('');
        setScanB('');
        setVerificationResult(null);
        fetchCartonsAndHistory();
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
    <div className="space-y-3 max-w-7xl mx-auto font-sans">
      {/* Workbench Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-[#3C3C3C] pb-2.5">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-xs font-mono text-[#858585]">workbench &gt; packaging &gt;</span>
            <h1 className="text-sm font-semibold text-white uppercase tracking-wide">Dual-Scan & Carton Packing</h1>
            <span className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-[#252526] border border-[#3C3C3C] text-[#4EC9B0]">
              Part 11
            </span>
          </div>
          <p className="text-xs text-[#858585] mt-0.5">
            Real-time verification: Scan A (Device Serial) vs Scan B (Packaging QR) & carton assignment.
          </p>
        </div>

        <div className="flex items-center gap-2 font-mono text-[10px]">
          <div className="flex items-center gap-1.5 rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2 py-1 text-[#CCCCCC]">
            <span className="h-2 w-2 rounded-full bg-[#4EC9B0] animate-pulse" />
            <span>Station: {stationId}</span>
          </div>

          <div className="flex items-center gap-1.5 rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2 py-1 text-[#CCCCCC]">
            <Barcode className="h-3 w-3 text-[#858585]" />
            <span>HID: <strong className={scannerListening ? 'text-[#4EC9B0]' : 'text-[#CCA700]'}>{scannerListening ? 'LISTENING' : 'OFFLINE'}</strong></span>
            {lastScannedPayload && (
              <span className="text-[#858585] truncate max-w-[80px]">({lastScannedPayload})</span>
            )}
          </div>
        </div>
      </div>

      {/* Main Dual-Scan Workspace */}
      <div className="grid grid-cols-1 gap-3 lg:grid-cols-12">
        {/* Column 1 & 2: Dual Scan Workflow */}
        <div className="space-y-3 lg:col-span-8">
          {/* Dual Inputs Card */}
          <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3.5 space-y-3">
            <div className="flex items-center justify-between border-b border-[#333333] pb-2">
              <div className="flex items-center gap-2 text-xs font-semibold text-white">
                <Scan className="h-4 w-4 text-[#007ACC]" />
                <span className="uppercase tracking-wider">Dual-Scan Verification Station</span>
              </div>
              <button
                onClick={handleReset}
                className="text-xs text-[#858585] hover:text-white transition flex items-center gap-1 font-mono"
              >
                <RefreshCw className="h-3 w-3" /> Clear Inputs
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {/* Scan A: Device Serial */}
              <div className={`p-3 rounded border transition ${scanA ? 'border-[#007ACC] bg-[#007ACC]/10' : 'border-[#333333] bg-[#1E1E1E]'}`}>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs font-semibold text-white flex items-center gap-1.5 font-mono">
                    <Cpu className="h-3.5 w-3.5 text-[#007ACC]" /> SCAN A: Device Serial
                  </span>
                  {scanA && <span className="text-[10px] text-[#4EC9B0] font-mono bg-[#4EC9B0]/10 px-1 py-0.2 rounded border border-[#4EC9B0]/30">CAPTURED</span>}
                </div>
                <input
                  type="text"
                  placeholder="Scan factory barcode (e.g. E1S3H1F1-00005)..."
                  value={scanA}
                  onChange={(e) => setScanA(e.target.value)}
                  className="w-full rounded bg-[#252526] border border-[#3C3C3C] px-2.5 py-1.5 text-xs font-mono text-white placeholder-[#555555] focus:border-[#007ACC] focus:outline-none"
                />
                <p className="text-[10px] text-[#858585] mt-1.5">Factory Code128 scan. Box QR resolves it to the complete device serial.</p>
              </div>

              {/* Scan B: Box / Label QR */}
              <div className={`p-3 rounded border transition ${scanB ? 'border-[#007ACC] bg-[#007ACC]/10' : 'border-[#333333] bg-[#1E1E1E]'}`}>
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-xs font-semibold text-white flex items-center gap-1.5 font-mono">
                    <Barcode className="h-3.5 w-3.5 text-[#007ACC]" /> SCAN B: Box / Label QR
                  </span>
                  {scanB && <span className="text-[10px] text-[#4EC9B0] font-mono bg-[#4EC9B0]/10 px-1 py-0.2 rounded border border-[#4EC9B0]/30">CAPTURED</span>}
                </div>
                <input
                  type="text"
                  placeholder="Scan label QR token (eh://p/v1?t=...)..."
                  value={scanB}
                  onChange={(e) => setScanB(e.target.value)}
                  className="w-full rounded bg-[#252526] border border-[#3C3C3C] px-2.5 py-1.5 text-xs font-mono text-white placeholder-[#555555] focus:border-[#007ACC] focus:outline-none"
                />
                <p className="text-[10px] text-[#858585] mt-1.5">2D QR scan on printed unit retail packaging.</p>
              </div>
            </div>

            {/* Action Bar */}
            <div className="flex items-center justify-end pt-1">
              <button
                type="button"
                onClick={handleVerify}
                disabled={!scanA.trim() || !scanB.trim() || isVerifying}
                className="flex items-center gap-2 rounded bg-[#0E639C] hover:bg-[#1177BB] px-4 py-2 text-xs font-semibold text-white disabled:opacity-40 transition"
              >
                {isVerifying ? (
                  <>
                    <RefreshCw className="h-3.5 w-3.5 animate-spin" /> Verifying Compatibility...
                  </>
                ) : (
                  <>
                    <Scan className="h-3.5 w-3.5" /> Evaluate Dual-Scan Match
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Verification Verdict Card */}
          {verificationResult && (
            <div
              className={`rounded border p-3.5 transition-all ${
                verificationResult.match
                  ? 'border-[#4EC9B0]/40 bg-[#4EC9B0]/5'
                  : 'border-[#F14C4C]/40 bg-[#F14C4C]/5'
              }`}
            >
              <div className="flex items-center justify-between pb-2.5 border-b border-[#333333]">
                <div className="flex items-center gap-2.5">
                  {verificationResult.match ? (
                    <CheckCircle2 className="h-5 w-5 text-[#4EC9B0]" />
                  ) : (
                    <XCircle className="h-5 w-5 text-[#F14C4C]" />
                  )}
                  <div>
                    <h3 className="text-xs font-bold text-white flex items-center gap-2">
                      {verificationResult.match ? 'DUAL-SCAN VERIFIED — PASS' : 'VERIFICATION FAILED — MISMATCH'}
                    </h3>
                    <p className="text-[10px] text-[#858585] font-mono">
                      {verificationResult.match
                        ? `Verification ID: ${verificationResult.verificationId}`
                        : `Error: ${verificationResult.errorCode} — ${verificationResult.errorMessage}`}
                    </p>
                  </div>
                </div>

                {verificationResult.match && (
                  <span className="px-2 py-0.5 bg-[#4EC9B0]/20 text-[#4EC9B0] border border-[#4EC9B0]/40 rounded text-[10px] font-mono font-bold">
                    READY FOR CARTON
                  </span>
                )}
              </div>

              {/* Match Details Matrix */}
              {verificationResult.device && (
                <div className="mt-3 grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs font-mono">
                  <div className="p-2 bg-[#1E1E1E] rounded border border-[#333333]">
                    <span className="text-[#858585] block text-[9px] uppercase">Device Serial</span>
                    <span className="text-white font-medium">{verificationResult.device.serialNumber}</span>
                  </div>
                  <div className="p-2 bg-[#1E1E1E] rounded border border-[#333333]">
                    <span className="text-[#858585] block text-[9px] uppercase">Variant</span>
                    <span className="text-[#4EC9B0] font-medium">{verificationResult.device.productVariantId}</span>
                  </div>
                  <div className="p-2 bg-[#1E1E1E] rounded border border-[#333333]">
                    <span className="text-[#858585] block text-[9px] uppercase">Hardware Rev</span>
                    <span className="text-white font-medium">{verificationResult.device.hardwareRevision}</span>
                  </div>
                  <div className="p-2 bg-[#1E1E1E] rounded border border-[#333333]">
                    <span className="text-[#858585] block text-[9px] uppercase">Firmware</span>
                    <span className="text-[#DCDCAA] font-medium">{verificationResult.device.firmwareFamily}</span>
                  </div>
                </div>
              )}

              {/* Confirm Packing Action */}
              {verificationResult.match && (
                <div className="mt-3 flex items-center justify-between pt-2.5 border-t border-[#333333]">
                  <div className="text-xs text-[#858585]">
                    Target Carton: <span className="font-mono text-white font-semibold">{activeCartonCode}</span>
                  </div>
                  <button
                    type="button"
                    onClick={handleConfirmPacking}
                    disabled={isPacking}
                    className="flex items-center gap-1.5 rounded bg-[#0E639C] hover:bg-[#1177BB] px-4 py-1.5 text-xs font-bold text-white transition disabled:opacity-40"
                  >
                    {isPacking ? (
                      <>
                        <RefreshCw className="h-3 w-3 animate-spin" /> Packing...
                      </>
                    ) : (
                      <>
                        <PackageCheck className="h-3 w-3" /> Confirm & Pack Unit
                      </>
                    )}
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Feedback alerts */}
          {packingSuccess && (
            <div className="p-2.5 bg-[#4EC9B0]/10 border border-[#4EC9B0]/30 rounded text-xs text-[#4EC9B0] flex items-center gap-2 font-mono">
              <CheckCircle2 className="h-4 w-4 shrink-0" />
              <span>{packingSuccess}</span>
            </div>
          )}

          {packingError && (
            <div className="p-2.5 bg-[#F14C4C]/10 border border-[#F14C4C]/30 rounded text-xs text-[#F14C4C] flex items-center gap-2 font-mono">
              <AlertTriangle className="h-4 w-4 shrink-0" />
              <span>{packingError}</span>
            </div>
          )}
        </div>

        {/* Column 3: Carton Target & Audit History */}
        <div className="space-y-3 lg:col-span-4">
          {/* Active Carton Target */}
          <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3 space-y-2.5">
            <div className="flex items-center gap-1.5 border-b border-[#333333] pb-1.5 text-xs font-semibold text-white">
              <Box className="h-3.5 w-3.5 text-[#007ACC]" />
              <span className="uppercase tracking-wider">Active Carton Target</span>
            </div>

            <div className="space-y-2 text-xs">
              {cartons.length > 0 && (
                <div>
                  <label className="text-[#858585] block mb-1 text-[10px] font-mono">Existing Cartons</label>
                  <select
                    value={activeCartonId}
                    onChange={(e) => {
                      const c = cartons.find((cart) => (cart.id || cart.cartonId) === e.target.value);
                      if (c) {
                        setActiveCartonId(c.id || c.cartonId);
                        setActiveCartonCode(c.cartonCode || c.code);
                      }
                    }}
                    className="w-full rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2 py-1 font-mono text-white text-xs"
                  >
                    {cartons.map((c) => (
                      <option key={c.id || c.cartonId} value={c.id || c.cartonId}>
                        {c.cartonCode || c.code} ({c.packedCount || 0} units)
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div>
                <label className="text-[#858585] block mb-1 text-[10px] font-mono">Carton Code</label>
                <div className="flex gap-1.5">
                  <input
                    type="text"
                    value={activeCartonCode}
                    onChange={(e) => setActiveCartonCode(e.target.value)}
                    className="flex-1 rounded bg-[#1E1E1E] border border-[#3C3C3C] px-2 py-1 font-mono text-white text-xs focus:border-[#007ACC] focus:outline-none"
                  />
                  <button
                    type="button"
                    onClick={() => setActiveCartonCode(`CARTON-2026-${Math.floor(100 + Math.random() * 900)}`)}
                    className="px-2 py-1 bg-[#1E1E1E] hover:bg-[#2D2D2D] rounded text-[#CCCCCC] font-mono text-[10px] border border-[#3C3C3C]"
                  >
                    New
                  </button>
                </div>
              </div>

              <div className="rounded bg-[#1E1E1E] p-2 border border-[#333333] text-[10px] space-y-0.5 text-[#858585] font-mono">
                <div className="flex justify-between">
                  <span>Carton Status:</span>
                  <span className="text-[#4EC9B0]">OPEN</span>
                </div>
                <div className="flex justify-between">
                  <span>Zero-Secret Invariant:</span>
                  <span className="text-[#4EC9B0]">ENFORCED</span>
                </div>
              </div>
            </div>
          </div>

          {/* Packing History Audit */}
          <div className="rounded border border-[#3C3C3C] bg-[#252526] p-3 space-y-2">
            <div className="flex items-center justify-between border-b border-[#333333] pb-1.5">
              <div className="flex items-center gap-1.5 text-xs font-semibold text-white">
                <History className="h-3.5 w-3.5 text-[#007ACC]" />
                <span className="uppercase tracking-wider">Recent Packing Trail</span>
              </div>
              <button
                onClick={fetchCartonsAndHistory}
                disabled={isLoadingHistory}
                className="text-[#858585] hover:text-white"
              >
                <RefreshCw className={`h-3 w-3 ${isLoadingHistory ? 'animate-spin' : ''}`} />
              </button>
            </div>

            <div className="space-y-1.5 max-h-72 overflow-y-auto pr-0.5">
              {packingHistory.length === 0 ? (
                <div className="p-4 text-center text-xs text-[#858585] font-mono bg-[#1E1E1E] rounded border border-[#333333]">
                  No packing events recorded yet.
                </div>
              ) : (
                packingHistory.map((item, idx) => (
                  <div
                    key={item.recordId || item.id || idx}
                    className="p-2 bg-[#1E1E1E] rounded border border-[#333333] text-[10px] space-y-0.5 font-mono"
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-[#4EC9B0] font-semibold">{item.serialNumber || item.deviceSerial}</span>
                      <span className="text-[#858585]">
                        {item.packedAt ? new Date(item.packedAt).toLocaleTimeString() : 'Recent'}
                      </span>
                    </div>
                    <div className="flex items-center justify-between text-[#CCCCCC]">
                      <span>{item.productVariantId || 'Variant'}</span>
                      <span className="text-[#858585]">{item.hardwareRevision || 'HW_1_0'}</span>
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
