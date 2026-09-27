/**
 * Manufacturing QR Code & Thermal Label Printer View (Part 10)
 *
 * Provides operators with:
 * - Provisioned device record selection (from Part 09 bench provisioning)
 * - Live visual label preview (TSPL 50x30mm / 40x20mm / ESC/POS traveler)
 * - 8-Gate Print Safety Validation execution
 * - Allowlisted thermal printer selection (TSC TE200 / Zebra ZD421)
 * - Non-sensitive label inspection & zero-secret assurance
 * - One-click deterministic label printing via typed native command
 */

import React, { useState, useEffect } from 'react';
import {
  Printer,
  QrCode,
  CheckCircle2,
  XCircle,
  Layers,
  Cpu,
  ShieldCheck,
  FileText,
} from 'lucide-react';
import {
  LabelDataModel,
  LabelTemplateId,
  PrinterProtocol,
  PrintJobResult,
  PrintValidationGateResult,
  validatePrintJob,
  buildDeviceLabelData,
  generateDeviceLabelTspl,
  generateCompactLabelTspl,
  generateReceiptEscPos,
} from '@eh-home/contracts';
import { printerService, PrinterDevice } from '../../services/native';
import { logger } from '../../lib/logger';

// Pre-loaded verified Part 09 provisioned device records for bench operators
const SAMPLE_PROVISIONED_RECORDS = [
  {
    schemaVersion: 1,
    traceId: '0194fe23-7a1b-7890-a123-456789abcd99',
    deviceId: '0194fe23-7a1b-7890-a123-456789abcdef',
    serialNumber: 'EH-SW3X-2026W39-00001',
    productVariantId: 'eh-smart-switch-3x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-switch-platform',
    firmwareReleaseId: 'rel-1-0-0',
    firmwareVersion: '1.0.0',
    targetMcu: 'esp32-c6' as const,
    idfTarget: 'esp32c6' as const,
    artifactSha256: 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
    tlsCertFingerprint: 'f0e1d2c3b4a5968778695a4b3c2d1e0ff0e1d2c3b4a5968778695a4b3c2d1e0f',
    port: 'COM3',
    flashStatus: 'PASS' as const,
    verificationStatus: 'PASS' as const,
    provisioningStatus: 'PASS' as const,
    provisionedAt: '2026-03-01T15:30:00Z',
    durationMs: 4200,
  },
  {
    schemaVersion: 1,
    traceId: '0194fe23-7a1b-7890-a123-456789abcd98',
    deviceId: '0194fe23-7a1b-7890-a123-456789abcde0',
    serialNumber: 'EH-SK2X-2026W39-00002',
    productVariantId: 'eh-smart-socket-2x',
    hardwareRevision: 'HW_1_0',
    firmwareFamily: 'esp32c6-socket-platform',
    firmwareReleaseId: 'rel-1-0-0',
    firmwareVersion: '1.0.0',
    targetMcu: 'esp32-c6' as const,
    idfTarget: 'esp32c6' as const,
    artifactSha256: 'b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90a1',
    tlsCertFingerprint: 'e1d2c3b4a5968778695a4b3c2d1e0ff0e1d2c3b4a5968778695a4b3c2d1e0ff0',
    port: 'COM4',
    flashStatus: 'PASS' as const,
    verificationStatus: 'PASS' as const,
    provisioningStatus: 'PASS' as const,
    provisionedAt: '2026-03-01T15:45:00Z',
    durationMs: 3950,
  },
];

export const LabelPrinterView: React.FC = () => {
  const [selectedRecordIdx, setSelectedRecordIdx] = useState<number>(0);
  const [templateId, setTemplateId] = useState<LabelTemplateId>('device-primary-50x30-v1');
  const [copies, setCopies] = useState<number>(1);
  const [availablePrinters, setAvailablePrinters] = useState<PrinterDevice[]>([]);
  const [selectedPrinterId, setSelectedPrinterId] = useState<string>('PRINTER_TSC_TE200');
  const [labelData, setLabelData] = useState<LabelDataModel | null>(null);
  const [validationResult, setValidationResult] = useState<PrintValidationGateResult | null>(null);
  const [isPrinting, setIsPrinting] = useState<boolean>(false);
  const [printResult, setPrintResult] = useState<PrintJobResult | null>(null);
  const [activeTab, setActiveTab] = useState<'preview' | 'commands' | 'gates'>('preview');

  // Load available printers
  useEffect(() => {
    printerService.listAvailablePrinters().then((printers) => {
      setAvailablePrinters(printers);
      if (printers.length > 0 && printers[0]) {
        setSelectedPrinterId(printers[0].id);
      }
    });
  }, []);

  // Update label model when selection or template changes
  useEffect(() => {
    try {
      const source = SAMPLE_PROVISIONED_RECORDS[selectedRecordIdx] || SAMPLE_PROVISIONED_RECORDS[0]!;
      const model = buildDeviceLabelData(source, {
        templateId,
      });
      setLabelData(model);
      setPrintResult(null);

      // Pre-evaluate gates
      const selectedPrinter = availablePrinters.find((p) => p.id === selectedPrinterId);
      const protocol: PrinterProtocol =
        templateId === 'box-receipt-escpos-v1' ? 'ESCPOS' : (selectedPrinter?.protocol || 'TSPL');

      const gates = validatePrintJob({
        printerId: selectedPrinterId,
        protocol,
        templateId,
        labelData: model,
        copies,
      });
      setValidationResult(gates);
    } catch (err: any) {
      logger.error('Failed to construct label data', err);
    }
  }, [selectedRecordIdx, templateId, selectedPrinterId, copies, availablePrinters]);

  const handlePrint = async () => {
    if (!labelData || isPrinting) return;
    setIsPrinting(true);
    setPrintResult(null);

    try {
      const selectedPrinter = availablePrinters.find((p) => p.id === selectedPrinterId);
      const protocol: PrinterProtocol =
        templateId === 'box-receipt-escpos-v1' ? 'ESCPOS' : (selectedPrinter?.protocol || 'TSPL');

      const res = await printerService.printLabel({
        printerId: selectedPrinterId,
        protocol,
        templateId,
        labelData,
        copies,
      });

      setPrintResult(res);
    } catch (err: any) {
      setPrintResult({
        success: false,
        protocol: 'TSPL',
        printerId: selectedPrinterId,
        copiesPrinted: 0,
        errorMessage: err.message,
      });
    } finally {
      setIsPrinting(false);
    }
  };

  const getRenderedCommands = (): string => {
    if (!labelData) return '';
    if (templateId === 'box-receipt-escpos-v1') {
      return generateReceiptEscPos(labelData);
    }
    if (templateId === 'device-compact-40x20-v1') {
      return generateCompactLabelTspl(labelData);
    }
    return generateDeviceLabelTspl(labelData);
  };

  return (
    <div className="space-y-6">
      {/* Title Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-lg font-bold text-slate-100 flex items-center gap-2">
            <Printer className="h-5 w-5 text-indigo-400" />
            <span>Manufacturing QR Code & Thermal Label Printer</span>
          </h1>
          <p className="text-xs text-slate-400">
            TSPL (TSC / Zebra 203 DPI) and ESC/POS deterministic label generation with 8-Gate Print Safety.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <span className="flex items-center gap-1.5 rounded-full bg-emerald-950/80 px-2.5 py-1 text-[11px] font-mono font-medium text-emerald-400 border border-emerald-800/60">
            <ShieldCheck className="h-3.5 w-3.5" />
            ZERO-SECRET CERTIFIED
          </span>
        </div>
      </div>

      {/* Main Grid: Control Config & Label Preview */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Job Configuration */}
        <div className="lg:col-span-5 space-y-4">
          <div className="rounded-xl border border-surface-border bg-surface-dark p-4 shadow-sm space-y-4">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-2">
              <Cpu className="h-4 w-4 text-indigo-400" />
              <span>1. Verified Provisioned Device</span>
            </h2>

            <div className="space-y-1.5">
              <label className="text-[11px] font-medium text-slate-300">Select Part 09 Record</label>
              <select
                value={selectedRecordIdx}
                onChange={(e) => setSelectedRecordIdx(Number(e.target.value))}
                className="w-full rounded-lg bg-surface-card border border-surface-border px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500 font-mono"
              >
                {SAMPLE_PROVISIONED_RECORDS.map((rec, idx) => (
                  <option key={rec.serialNumber} value={idx}>
                    {rec.serialNumber} — {rec.productVariantId} ({rec.hardwareRevision})
                  </option>
                ))}
              </select>
            </div>

            {labelData && (
              <div className="rounded-lg bg-surface-darker/60 border border-surface-border p-3 text-[11px] font-mono space-y-1 text-slate-400">
                <div className="flex justify-between">
                  <span>Device UUID:</span>
                  <span className="text-slate-200 select-all">{labelData.deviceId.slice(0, 18)}...</span>
                </div>
                <div className="flex justify-between">
                  <span>Serial:</span>
                  <span className="text-indigo-400 font-bold select-all">{labelData.serialNumber}</span>
                </div>
                <div className="flex justify-between">
                  <span>Variant:</span>
                  <span className="text-slate-200">{labelData.productVariantId}</span>
                </div>
                <div className="flex justify-between">
                  <span>Firmware:</span>
                  <span className="text-slate-200">{labelData.firmwareFamily} @ v{labelData.firmwareVersion}</span>
                </div>
                <div className="flex justify-between">
                  <span>Opaque Token:</span>
                  <span className="text-emerald-400">{labelData.qrToken.slice(0, 16)}...</span>
                </div>
              </div>
            )}
          </div>

          {/* Template & Printer Selection Card */}
          <div className="rounded-xl border border-surface-border bg-surface-dark p-4 shadow-sm space-y-4">
            <h2 className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center gap-2">
              <Layers className="h-4 w-4 text-indigo-400" />
              <span>2. Label Template & Hardware Printer</span>
            </h2>

            <div className="space-y-1.5">
              <label className="text-[11px] font-medium text-slate-300">Label Format & Dimensions</label>
              <select
                value={templateId}
                onChange={(e) => setTemplateId(e.target.value as LabelTemplateId)}
                className="w-full rounded-lg bg-surface-card border border-surface-border px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
              >
                <option value="device-primary-50x30-v1">Device Primary (50mm x 30mm TSPL @ 203 DPI)</option>
                <option value="device-compact-40x20-v1">Device Compact (40mm x 20mm TSPL @ 203 DPI)</option>
                <option value="box-receipt-escpos-v1">Manufacturing Traveler Slip (ESC/POS Receipt)</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-[11px] font-medium text-slate-300">Target Printer</label>
              <select
                value={selectedPrinterId}
                onChange={(e) => setSelectedPrinterId(e.target.value)}
                className="w-full rounded-lg bg-surface-card border border-surface-border px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
              >
                {availablePrinters.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name} [{p.protocol} - {p.connectionType}]
                  </option>
                ))}
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-[11px] font-medium text-slate-300">Copies</label>
              <input
                type="number"
                min={1}
                max={20}
                value={copies}
                onChange={(e) => setCopies(Math.max(1, parseInt(e.target.value) || 1))}
                className="w-24 rounded-lg bg-surface-card border border-surface-border px-3 py-1.5 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
              />
            </div>

            {/* Print Action Button */}
            <div className="pt-2">
              <button
                onClick={handlePrint}
                disabled={isPrinting || !validationResult?.valid}
                className="w-full flex items-center justify-center gap-2 rounded-lg bg-indigo-600 px-4 py-2.5 text-xs font-semibold text-white shadow-sm shadow-indigo-600/30 hover:bg-indigo-500 transition disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Printer className="h-4 w-4" />
                <span>{isPrinting ? 'Transmitting to Spooler...' : 'Validate & Print Thermal Label'}</span>
              </button>
            </div>

            {/* Print Status Feedback */}
            {printResult && (
              <div
                className={`rounded-lg p-3 text-xs border ${
                  printResult.success
                    ? 'bg-emerald-950/40 border-emerald-800 text-emerald-300'
                    : 'bg-rose-950/40 border-rose-800 text-rose-300'
                }`}
              >
                <div className="flex items-center gap-2 font-bold mb-1">
                  {printResult.success ? (
                    <CheckCircle2 className="h-4 w-4 text-emerald-400" />
                  ) : (
                    <XCircle className="h-4 w-4 text-rose-400" />
                  )}
                  <span>
                    {printResult.success
                      ? `Print Job Dispatched: ${printResult.jobId}`
                      : `Print Failed: ${printResult.errorCode || 'ERROR'}`}
                  </span>
                </div>
                <div className="text-[11px] opacity-90">
                  {printResult.errorMessage ||
                    `Successfully spooled ${printResult.copiesPrinted} label(s) via ${printResult.protocol} to ${printResult.printerId}.`}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Visual Label Preview & Print Gates */}
        <div className="lg:col-span-7 space-y-4">
          {/* View Tabs */}
          <div className="flex items-center gap-2 border-b border-surface-border pb-2">
            <button
              onClick={() => setActiveTab('preview')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition ${
                activeTab === 'preview'
                  ? 'bg-indigo-600 text-white'
                  : 'bg-surface-card text-slate-300 hover:bg-surface-border/50'
              }`}
            >
              <QrCode className="h-3.5 w-3.5" />
              <span>Visual Label Preview</span>
            </button>
            <button
              onClick={() => setActiveTab('gates')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition ${
                activeTab === 'gates'
                  ? 'bg-indigo-600 text-white'
                  : 'bg-surface-card text-slate-300 hover:bg-surface-border/50'
              }`}
            >
              <ShieldCheck className="h-3.5 w-3.5" />
              <span>8 Print Safety Gates</span>
            </button>
            <button
              onClick={() => setActiveTab('commands')}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition ${
                activeTab === 'commands'
                  ? 'bg-indigo-600 text-white'
                  : 'bg-surface-card text-slate-300 hover:bg-surface-border/50'
              }`}
            >
              <FileText className="h-3.5 w-3.5" />
              <span>Rendered TSPL / ESC-POS</span>
            </button>
          </div>

          {/* Tab 1: Visual Label Preview */}
          {activeTab === 'preview' && labelData && (
            <div className="rounded-xl border border-surface-border bg-surface-dark p-6 flex flex-col items-center justify-center min-h-[360px]">
              {/* Simulated 50mm x 30mm Thermal Label (White with crisp black thermal ink) */}
              <div className="w-[420px] h-[250px] bg-white rounded-lg shadow-xl p-4 flex flex-col justify-between text-neutral-900 border-2 border-neutral-300 select-none font-sans">
                {/* Header row: Branding & QR Code */}
                <div className="flex justify-between items-start">
                  <div>
                    <div className="text-sm font-black tracking-tight text-neutral-900">EH HOME</div>
                    <div className="text-xs font-bold text-neutral-800 leading-tight">
                      {labelData.productDisplayName}
                    </div>
                    <div className="text-[10px] text-neutral-600 font-mono mt-0.5">
                      Model: {labelData.productVariantId}
                    </div>
                    <div className="text-[9px] text-neutral-600 font-mono mt-0.5">
                      HW: {labelData.hardwareRevision} | FW: v{labelData.firmwareVersion}
                    </div>
                  </div>

                  {/* Simulated 2D QR Code Badge */}
                  <div className="flex flex-col items-center">
                    <div className="w-20 h-20 bg-neutral-900 rounded p-1 flex items-center justify-center text-white">
                      <QrCode className="w-16 h-16 text-white" />
                    </div>
                    <span className="text-[8px] font-mono text-neutral-500 mt-1">OPAQUE QR</span>
                  </div>
                </div>

                {/* 1D Barcode Simulation & Serial Number */}
                <div className="space-y-1">
                  {/* Simulated Code128 bar pattern */}
                  <div className="h-7 w-full flex items-stretch gap-[2px] overflow-hidden px-1 bg-white">
                    {Array.from({ length: 48 }).map((_, i) => (
                      <div
                        key={i}
                        className={`bg-neutral-900 ${
                          i % 7 === 0 ? 'w-1.5' : i % 3 === 0 ? 'w-1' : 'w-0.5'
                        }`}
                      />
                    ))}
                  </div>
                  <div className="text-center font-mono font-bold text-xs tracking-wider text-neutral-900">
                    SN: {labelData.serialNumber}
                  </div>
                </div>

                {/* Footer: Truncated UUID & Opaque Proof */}
                <div className="flex justify-between items-center text-[9px] font-mono text-neutral-500 border-t border-neutral-200 pt-1">
                  <span>UUID: {labelData.deviceId.slice(0, 16)}...</span>
                  <span className="font-semibold text-emerald-700">EH-PROV/V1 [SAFE]</span>
                </div>
              </div>

              {/* Opaque QR URI Inspection Box */}
              <div className="w-full mt-4 p-3 rounded-lg bg-surface-darker/60 border border-surface-border text-xs space-y-1">
                <div className="text-[11px] font-semibold text-slate-400">Canonical Opaque QR URI:</div>
                <div className="font-mono text-xs text-indigo-400 select-all break-all">{labelData.qrUri}</div>
                <div className="text-[10px] text-slate-500">
                  Zero credentials, keys, or Wi-Fi parameters are encoded. Backend resolves device state securely.
                </div>
              </div>
            </div>
          )}

          {/* Tab 2: 8 Print Safety Gates Checklist */}
          {activeTab === 'gates' && validationResult && (
            <div className="rounded-xl border border-surface-border bg-surface-dark p-5 space-y-3">
              <div className="flex items-center justify-between border-b border-surface-border pb-3">
                <div className="text-xs font-bold text-slate-200">Pre-Print Safety Gate Status</div>
                <span
                  className={`text-[11px] font-mono px-2 py-0.5 rounded font-bold ${
                    validationResult.valid
                      ? 'bg-emerald-950 text-emerald-400 border border-emerald-800'
                      : 'bg-rose-950 text-rose-400 border border-rose-800'
                  }`}
                >
                  {validationResult.valid ? '8/8 GATES PASSED' : 'SAFETY GATE REJECTION'}
                </span>
              </div>

              <div className="space-y-2">
                {validationResult.gateDetails.map((gate, i) => (
                  <div
                    key={gate.gate}
                    className="flex items-center justify-between p-2 rounded-lg bg-surface-card/60 border border-surface-border text-xs"
                  >
                    <div className="flex items-center gap-2">
                      {gate.passed ? (
                        <CheckCircle2 className="h-4 w-4 text-emerald-400 shrink-0" />
                      ) : (
                        <XCircle className="h-4 w-4 text-rose-400 shrink-0" />
                      )}
                      <div>
                        <span className="font-semibold text-slate-200">
                          Gate {i + 1}: {gate.gate}
                        </span>
                        <div className="text-[11px] text-slate-400">{gate.detail}</div>
                      </div>
                    </div>
                    <span
                      className={`text-[10px] font-mono px-1.5 py-0.5 rounded ${
                        gate.passed ? 'text-emerald-400 bg-emerald-950/40' : 'text-rose-400 bg-rose-950/40'
                      }`}
                    >
                      {gate.passed ? 'PASS' : 'FAIL'}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Tab 3: Rendered TSPL / ESC-POS Command Stream */}
          {activeTab === 'commands' && (
            <div className="rounded-xl border border-surface-border bg-surface-dark p-4 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-slate-300">
                  Spooler Payload ({templateId === 'box-receipt-escpos-v1' ? 'ESC/POS' : 'TSPL'})
                </span>
                <span className="text-[10px] text-slate-400 font-mono">
                  {getRenderedCommands().length} Bytes
                </span>
              </div>
              <pre className="rounded-lg bg-surface-darker p-3 text-[11px] font-mono text-emerald-400 overflow-x-auto max-h-[300px] border border-surface-border select-all">
                {getRenderedCommands()}
              </pre>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
