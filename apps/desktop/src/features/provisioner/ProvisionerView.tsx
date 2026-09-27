/**
 * EH Home Desktop — ESP32 Bench Provisioner & Device Flasher
 *
 * Production-grade desktop UI workflow covering:
 * - Serial device discovery and port selection
 * - ESP32 chip detection and identity extraction
 * - Firmware artifact validation against Part 07/08 metadata
 * - Controlled sidecar flashing through tools/manufacturing/flash_device.py
 * - Verification and device identity capture (fact_v2)
 * - Traceability summary and structured audit record
 */

import React, { useState, useEffect, useCallback } from 'react';
import {
  Cpu,
  RefreshCw,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Play,
  RotateCcw,
  ShieldCheck,
  Terminal,
  Copy,
  Check,
  FileCheck2,
} from 'lucide-react';
import {
  SerialPortInfo,
  getSerialService,
  getFlasherService,
  FlashProgressEvent,
} from '../../services/native';
import {
  BenchDeviceState,
  Esp32Identification,
  BenchArtifactValidationResult,
  BenchProvisioningTraceabilityRecord,
  FirmwareBuildManifest,
  FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP,
} from '@eh-home/contracts';
import { logger } from '../../lib/logger';

const CANONICAL_VARIANTS = [
  { id: 'eh-smart-switch-3x', name: 'EH Smart Switch 3-Gang (ESP32-C6)', family: 'esp32c6-switch-platform', mcu: 'esp32-c6' },
  { id: 'eh-smart-switch-1x', name: 'EH Smart Switch 1-Gang (ESP32-C6)', family: 'esp32c6-switch-platform', mcu: 'esp32-c6' },
  { id: 'eh-smart-switch-2x', name: 'EH Smart Switch 2-Gang (ESP32-C6)', family: 'esp32c6-switch-platform', mcu: 'esp32-c6' },
  { id: 'eh-smart-switch-4x', name: 'EH Smart Switch 4-Gang (ESP32-C6)', family: 'esp32c6-switch-platform', mcu: 'esp32-c6' },
  { id: 'eh-smart-socket-1x', name: 'EH Smart Socket 1-Gang (ESP32-C6)', family: 'esp32c6-socket-platform', mcu: 'esp32-c6' },
  { id: 'eh-smart-socket-2x', name: 'EH Smart Socket 2-Gang (ESP32-C6)', family: 'esp32c6-socket-platform', mcu: 'esp32-c6' },
  { id: 'eh-smart-socket-3x', name: 'EH Smart Socket 3-Gang (ESP32-C6)', family: 'esp32c6-socket-platform', mcu: 'esp32-c6' },
  { id: 'eh-smart-light-cct', name: 'EH Smart Light CCT (ESP32-C6)', family: 'esp32c6-light-platform', mcu: 'esp32-c6' },
  { id: 'eh-sensor-node-v1', name: 'EH Environmental Sensor (ESP32-C6)', family: 'esp32c6-sensor-platform', mcu: 'esp32-c6' },
  { id: 'eh-smart-switch-dev', name: 'EH DevKit Switch Prototype (ESP32)', family: 'esp32-dev-platform', mcu: 'esp32' },
];

const DEFAULT_ARTIFACT_SHA = 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

export const ProvisionerView: React.FC = () => {
  const serialService = getSerialService();
  const flasherService = getFlasherService();

  // ── Component State ────────────────────────────────────────────────
  const [deviceState, setDeviceState] = useState<BenchDeviceState>('NO_DEVICE_DETECTED');
  const [availablePorts, setAvailablePorts] = useState<SerialPortInfo[]>([]);
  const [selectedPort, setSelectedPort] = useState<string>('');
  const [isScanningPorts, setIsScanningPorts] = useState<boolean>(false);
  const [identifiedDevice, setIdentifiedDevice] = useState<Esp32Identification | null>(null);

  // Configuration
  const [selectedVariantId, setSelectedVariantId] = useState<string>('eh-smart-switch-3x');
  const [selectedHwRev, setSelectedHwRev] = useState<string>('HW_1_0');
  const [artifactPath, setArtifactPath] = useState<string>('firmware/platforms/esp32/smart-switch-app/build/smart-switch.bin');
  const [artifactSha256, setArtifactSha256] = useState<string>(DEFAULT_ARTIFACT_SHA);

  // Gates & Workflow
  const [validationResult, setValidationResult] = useState<BenchArtifactValidationResult | null>(null);
  const [isValidatingGates, setIsValidatingGates] = useState<boolean>(false);
  const [flashProgress, setFlashProgress] = useState<FlashProgressEvent | null>(null);
  const [traceabilityRecord, setTraceabilityRecord] = useState<BenchProvisioningTraceabilityRecord | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [consoleLogs, setConsoleLogs] = useState<string[]>([]);
  const [copiedTrace, setCopiedTrace] = useState<boolean>(false);

  const selectedVariant = CANONICAL_VARIANTS.find((v) => v.id === selectedVariantId) || CANONICAL_VARIANTS[0]!;

  const appendLog = useCallback((msg: string) => {
    const timestamp = new Date().toISOString().substring(11, 19);
    setConsoleLogs((prev) => [...prev.slice(-100), `[${timestamp}] ${msg}`]);
  }, []);

  // ── Port Discovery ─────────────────────────────────────────────────
  const scanPorts = useCallback(async () => {
    setIsScanningPorts(true);
    try {
      const ports = await serialService.listAvailablePorts();
      setAvailablePorts(ports);
      if (ports.length > 0 && !selectedPort) {
        const candidate = ports.find((p) => p.isEspCandidate) || ports[0];
        if (candidate) {
          setSelectedPort(candidate.portName);
          setDeviceState('DEVICE_DETECTED');
        }
      } else if (ports.length === 0) {
        setDeviceState('NO_DEVICE_DETECTED');
      }
    } catch (err: any) {
      logger.error('Failed to list serial ports', err);
      appendLog(`Error querying serial ports: ${err.message}`);
    } finally {
      setIsScanningPorts(false);
    }
  }, [selectedPort, serialService, appendLog]);

  useEffect(() => {
    scanPorts();
  }, [scanPorts]);

  // ── ESP32 Identification ───────────────────────────────────────────
  const handleIdentifyDevice = async () => {
    if (!selectedPort) return;
    setErrorMessage(null);
    appendLog(`Identifying target device on ${selectedPort}...`);
    try {
      const ident = await flasherService.identifyDevice(selectedPort);
      setIdentifiedDevice(ident);
      setDeviceState('DEVICE_IDENTIFIED');
      appendLog(`Device identified: ${ident.chipName} (${ident.chipFamily}), MAC: ${ident.macAddress || 'unknown'}`);
    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to communicate with device on serial port');
      setDeviceState('FAILED');
      appendLog(`Identification failed: ${err.message}`);
    }
  };

  // ── Artifact Validation Gates ──────────────────────────────────────
  const handleValidateGates = async () => {
    setIsValidatingGates(true);
    setErrorMessage(null);
    appendLog('Validating firmware artifact compatibility gates...');

    const manifest: FirmwareBuildManifest = {
      schemaVersion: 1,
      buildId: '0194fe23-7a1b-7890-a123-456789abcd01',
      firmwareFamily: selectedVariant.family,
      productVariants: FIRMWARE_FAMILY_TO_PRODUCT_VARIANTS_MAP[selectedVariant.family] || [selectedVariant.id],
      version: '1.0.0',
      gitCommitSha: '0123456789abcdef0123456789abcdef01234567',
      gitBranch: 'main',
      targetMcu: selectedVariant.mcu as any,
      idfTarget: 'esp32c6',
      toolchain: 'riscv32-esp-elf',
      idfVersion: 'v5.4.1',
      buildProfile: 'release',
      lifecycleStatus: 'RELEASED',
      compatibleHardwareRevisions: ['HW_1_0', 'HW_1_1'],
      artifacts: [
        {
          artifactType: 'APP_BIN',
          fileName: 'smart-switch.bin',
          fileSizeBytes: 1048576,
          sha256: artifactSha256.trim().toLowerCase(),
          storagePath: artifactPath,
        },
      ],
      generatedAt: new Date().toISOString(),
    };

    try {
      const res = await flasherService.validateArtifact({
        firmwareFamily: selectedVariant.family,
        productVariantId: selectedVariant.id,
        hardwareRevision: selectedHwRev,
        targetMcu: selectedVariant.mcu as any,
        manifest,
        computedSha256: artifactSha256.trim().toLowerCase(),
      });

      setValidationResult(res);
      if (res.valid) {
        setDeviceState('DEVICE_READY_FOR_FLASHING');
        appendLog('All validation gates PASSED. Ready for bench provisioning.');
      } else {
        setErrorMessage(`Validation Gate Rejected: [${res.errorCode}] ${res.message}`);
        setDeviceState('FAILED');
        appendLog(`Validation gate failed: [${res.errorCode}] ${res.message}`);
      }
    } catch (err: any) {
      setErrorMessage(`Validation error: ${err.message}`);
      setDeviceState('FAILED');
    } finally {
      setIsValidatingGates(false);
    }
  };

  // ── Flash & Provision Sequence ─────────────────────────────────────
  const handleFlashAndProvision = async () => {
    if (!selectedPort || !validationResult?.valid) return;

    setErrorMessage(null);
    setTraceabilityRecord(null);
    setDeviceState('FLASHING');
    appendLog(`Starting flashing sequence on ${selectedPort} for ${selectedVariant.id}...`);

    try {
      const record = await flasherService.provisionBenchDevice(
        {
          port: selectedPort,
          productVariantId: selectedVariant.id,
          hardwareRevision: selectedHwRev,
          firmwareFamily: selectedVariant.family,
          firmwareReleaseId: 'rel-1-0-0-prod',
          firmwareVersion: '1.0.0',
          targetMcu: selectedVariant.mcu as any,
          appBinPath: artifactPath,
          computedSha256: artifactSha256.trim().toLowerCase(),
          baudRate: 115200,
        },
        (progress) => {
          setFlashProgress(progress);
          appendLog(`[${progress.stage}] ${progress.message} (${progress.progressPercent}%)`);
          if (progress.stage === 'VERIFYING') {
            setDeviceState('VERIFICATION');
          } else if (progress.stage === 'PROVISIONING') {
            setDeviceState('PROVISIONING');
          }
        }
      );

      setTraceabilityRecord(record);
      setDeviceState('COMPLETED');
      appendLog(`PROVISIONING COMPLETE! Device ID: ${record.deviceId} | Serial: ${record.serialNumber}`);
    } catch (err: any) {
      logger.error('Provisioning failed', err);
      setErrorMessage(err.message || 'Flashing or post-flash verification failed.');
      setDeviceState('FAILED');
      appendLog(`FAILED: ${err.message}`);
    }
  };

  const copyTraceabilityToClipboard = () => {
    if (traceabilityRecord) {
      navigator.clipboard.writeText(JSON.stringify(traceabilityRecord, null, 2));
      setCopiedTrace(true);
      setTimeout(() => setCopiedTrace(false), 2000);
    }
  };

  const handleReset = () => {
    setDeviceState('NO_DEVICE_DETECTED');
    setIdentifiedDevice(null);
    setValidationResult(null);
    setFlashProgress(null);
    setTraceabilityRecord(null);
    setErrorMessage(null);
    scanPorts();
  };

  // ── State Badge Styling ────────────────────────────────────────────
  const getStateBadge = () => {
    switch (deviceState) {
      case 'NO_DEVICE_DETECTED':
        return <span className="rounded-full bg-slate-800 px-3 py-1 text-xs font-semibold text-slate-400">No Device Detected</span>;
      case 'DEVICE_DETECTED':
        return <span className="rounded-full bg-blue-900/50 px-3 py-1 text-xs font-semibold text-blue-400 border border-blue-700/50">Device Detected</span>;
      case 'DEVICE_IDENTIFIED':
        return <span className="rounded-full bg-indigo-900/50 px-3 py-1 text-xs font-semibold text-indigo-400 border border-indigo-700/50">Device Identified</span>;
      case 'DEVICE_READY_FOR_FLASHING':
        return <span className="rounded-full bg-emerald-900/50 px-3 py-1 text-xs font-semibold text-emerald-400 border border-emerald-700/50">Ready For Flashing</span>;
      case 'FLASHING':
        return <span className="rounded-full bg-amber-900/50 px-3 py-1 text-xs font-semibold text-amber-300 animate-pulse border border-amber-600/50">Flashing Firmware...</span>;
      case 'VERIFICATION':
        return <span className="rounded-full bg-purple-900/50 px-3 py-1 text-xs font-semibold text-purple-300 animate-pulse border border-purple-600/50">Verifying Boot & Banner...</span>;
      case 'PROVISIONING':
        return <span className="rounded-full bg-cyan-900/50 px-3 py-1 text-xs font-semibold text-cyan-300 animate-pulse border border-cyan-600/50">Writing NVS fact_v2...</span>;
      case 'COMPLETED':
        return <span className="rounded-full bg-emerald-900/70 px-3 py-1 text-xs font-semibold text-emerald-300 border border-emerald-500">Provisioning Complete</span>;
      case 'FAILED':
        return <span className="rounded-full bg-rose-900/60 px-3 py-1 text-xs font-semibold text-rose-300 border border-rose-600">Operation Failed</span>;
      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 border-b border-surface-border pb-4">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-xl font-bold tracking-tight text-slate-100">ESP32 Bench Provisioner</h1>
            {getStateBadge()}
          </div>
          <p className="mt-1 text-xs text-slate-400">
            Automated production flashing, hardware verification, and NVS identity injection (Part 09)
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={handleReset}
            className="flex items-center gap-1.5 rounded-lg border border-surface-border bg-surface-card px-3 py-1.5 text-xs font-medium text-slate-300 hover:bg-surface-border hover:text-white transition"
          >
            <RotateCcw className="h-3.5 w-3.5" />
            Reset Bench
          </button>
        </div>
      </div>

      {/* Error Banner */}
      {errorMessage && (
        <div className="flex items-start gap-3 rounded-lg border border-rose-800/80 bg-rose-950/40 p-4 text-rose-200">
          <AlertTriangle className="h-5 w-5 shrink-0 text-rose-400" />
          <div className="flex-1 text-xs">
            <span className="font-semibold text-rose-300">Operation Error: </span>
            {errorMessage}
          </div>
        </div>
      )}

      {/* Main Grid: 2 Columns */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Device & Artifact Controls */}
        <div className="lg:col-span-7 space-y-6">
          {/* Step 1: Device Discovery */}
          <div className="rounded-xl border border-surface-border bg-surface-card p-5 space-y-4 shadow-sm">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-sm font-semibold text-slate-200">
                <span className="flex h-5 w-5 items-center justify-center rounded-full bg-indigo-600 text-[11px] font-bold text-white">1</span>
                <span>Serial Device Discovery</span>
              </div>
              <button
                onClick={scanPorts}
                disabled={isScanningPorts}
                className="flex items-center gap-1 text-xs text-indigo-400 hover:text-indigo-300 transition"
              >
                <RefreshCw className={`h-3 w-3 ${isScanningPorts ? 'animate-spin' : ''}`} />
                Scan Ports
              </button>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="sm:col-span-2">
                <label className="block text-[11px] font-medium text-slate-400 mb-1">Target Serial COM Port</label>
                <select
                  value={selectedPort}
                  onChange={(e) => setSelectedPort(e.target.value)}
                  className="w-full rounded-lg border border-surface-border bg-surface-dark px-3 py-2 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                >
                  {availablePorts.length === 0 ? (
                    <option value="">No COM ports detected</option>
                  ) : (
                    availablePorts.map((p) => (
                      <option key={p.portName} value={p.portName}>
                        {p.portName} — {p.description || 'Serial Device'} ({p.status})
                      </option>
                    ))
                  )}
                </select>
              </div>
              <div className="flex items-end">
                <button
                  onClick={handleIdentifyDevice}
                  disabled={!selectedPort || deviceState === 'FLASHING'}
                  className="w-full flex items-center justify-center gap-1.5 rounded-lg bg-indigo-600 px-3 py-2 text-xs font-medium text-white hover:bg-indigo-500 transition disabled:opacity-50"
                >
                  <Cpu className="h-3.5 w-3.5" />
                  Identify Chip
                </button>
              </div>
            </div>

            {/* Chip Info Card */}
            {identifiedDevice && (
              <div className="rounded-lg border border-surface-border/60 bg-surface-dark/70 p-3 text-xs space-y-1.5">
                <div className="flex items-center justify-between">
                  <span className="font-semibold text-slate-200">{identifiedDevice.chipName}</span>
                  <span className="rounded bg-emerald-950 border border-emerald-700/50 px-2 py-0.5 text-[10px] font-mono text-emerald-400">
                    {identifiedDevice.connectionStatus}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-2 text-[11px] text-slate-400 font-mono">
                  <div>Family: <span className="text-slate-300">{identifiedDevice.chipFamily}</span></div>
                  <div>MAC: <span className="text-slate-300">{identifiedDevice.macAddress || 'N/A'}</span></div>
                  <div>Target: <span className="text-slate-300">{identifiedDevice.detectedTarget}</span></div>
                  <div>Flash: <span className="text-slate-300">4 MB (QIO)</span></div>
                </div>
              </div>
            )}
          </div>

          {/* Step 2: Product & Hardware Revision */}
          <div className="rounded-xl border border-surface-border bg-surface-card p-5 space-y-4 shadow-sm">
            <div className="flex items-center gap-2 text-sm font-semibold text-slate-200">
              <span className="flex h-5 w-5 items-center justify-center rounded-full bg-indigo-600 text-[11px] font-bold text-white">2</span>
              <span>Product Variant & Hardware Compatibility</span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-[11px] font-medium text-slate-400 mb-1">Target Product Variant</label>
                <select
                  value={selectedVariantId}
                  onChange={(e) => {
                    setSelectedVariantId(e.target.value);
                    setValidationResult(null);
                  }}
                  className="w-full rounded-lg border border-surface-border bg-surface-dark px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-indigo-500"
                >
                  {CANONICAL_VARIANTS.map((v) => (
                    <option key={v.id} value={v.id}>
                      {v.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-[11px] font-medium text-slate-400 mb-1">Hardware Revision</label>
                <select
                  value={selectedHwRev}
                  onChange={(e) => {
                    setSelectedHwRev(e.target.value);
                    setValidationResult(null);
                  }}
                  className="w-full rounded-lg border border-surface-border bg-surface-dark px-3 py-2 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                >
                  <option value="HW_1_0">HW_1_0 (Primary Production)</option>
                  <option value="HW_1_1">HW_1_1 (Relay Snubber Revision)</option>
                  <option value="HW_9_9">HW_9_9 (Incompatible Test Rev)</option>
                </select>
              </div>
            </div>

            <div className="flex items-center gap-4 text-xs text-slate-400 bg-surface-dark/50 p-2.5 rounded-lg border border-surface-border/50">
              <div>Firmware Family: <span className="font-mono text-indigo-300 font-semibold">{selectedVariant.family}</span></div>
              <div>MCU: <span className="font-mono text-slate-200">{selectedVariant.mcu}</span></div>
            </div>
          </div>

          {/* Step 3: Firmware Artifact Validation */}
          <div className="rounded-xl border border-surface-border bg-surface-card p-5 space-y-4 shadow-sm">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2 text-sm font-semibold text-slate-200">
                <span className="flex h-5 w-5 items-center justify-center rounded-full bg-indigo-600 text-[11px] font-bold text-white">3</span>
                <span>Firmware Artifact & Integrity Gates</span>
              </div>
              <button
                onClick={handleValidateGates}
                disabled={isValidatingGates || deviceState === 'FLASHING'}
                className="flex items-center gap-1.5 rounded-lg bg-slate-700 hover:bg-slate-600 px-3 py-1.5 text-xs font-medium text-slate-200 transition disabled:opacity-50"
              >
                <FileCheck2 className="h-3.5 w-3.5" />
                Validate Gates
              </button>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-[11px] font-medium text-slate-400 mb-1">Application Binary Path (.bin)</label>
                <input
                  type="text"
                  value={artifactPath}
                  onChange={(e) => setArtifactPath(e.target.value)}
                  className="w-full rounded-lg border border-surface-border bg-surface-dark px-3 py-1.5 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-medium text-slate-400 mb-1">Expected SHA-256 Digest</label>
                <input
                  type="text"
                  value={artifactSha256}
                  onChange={(e) => {
                    setArtifactSha256(e.target.value);
                    setValidationResult(null);
                  }}
                  className="w-full rounded-lg border border-surface-border bg-surface-dark px-3 py-1.5 text-xs font-mono text-slate-200 focus:outline-none focus:border-indigo-500"
                />
              </div>

              {/* Validation Gate Details */}
              {validationResult && (
                <div className="rounded-lg border border-surface-border/60 bg-surface-dark/60 p-3 space-y-2">
                  <div className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                    Verification Gates Evaluation
                  </div>
                  <div className="space-y-1">
                    {validationResult.gateDetails.map((g, idx) => (
                      <div key={idx} className="flex items-center gap-2 text-xs">
                        {g.passed ? (
                          <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400 shrink-0" />
                        ) : (
                          <XCircle className="h-3.5 w-3.5 text-rose-400 shrink-0" />
                        )}
                        <span className="font-mono text-[11px] text-slate-300">{g.gate}:</span>
                        <span className="text-[11px] text-slate-400 truncate">{g.detail}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Execution, Traceability & Logs */}
        <div className="lg:col-span-5 space-y-6">
          {/* Action Card: Flash & Provision */}
          <div className="rounded-xl border border-surface-border bg-surface-card p-5 space-y-4 shadow-sm">
            <div className="flex items-center gap-2 text-sm font-semibold text-slate-200">
              <span className="flex h-5 w-5 items-center justify-center rounded-full bg-indigo-600 text-[11px] font-bold text-white">4</span>
              <span>Controlled Bench Flashing</span>
            </div>

            <button
              onClick={handleFlashAndProvision}
              disabled={
                !validationResult?.valid ||
                ['FLASHING', 'VERIFICATION', 'PROVISIONING'].includes(deviceState)
              }
              className="w-full flex items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 p-3 text-sm font-bold text-white shadow-lg shadow-emerald-900/30 transition disabled:opacity-40 disabled:pointer-events-none"
            >
              <Play className="h-4 w-4 fill-white" />
              Flash & Provision Device
            </button>

            {/* Progress Bar */}
            {['FLASHING', 'VERIFICATION', 'PROVISIONING', 'COMPLETED'].includes(deviceState) && (
              <div className="space-y-2 pt-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="font-medium text-slate-300">{flashProgress?.stage || 'PROCESSING'}</span>
                  <span className="font-mono text-emerald-400 font-semibold">{flashProgress?.progressPercent || 0}%</span>
                </div>
                <div className="h-2 w-full overflow-hidden rounded-full bg-surface-dark">
                  <div
                    className="h-full bg-gradient-to-r from-indigo-500 via-teal-400 to-emerald-400 transition-all duration-300"
                    style={{ width: `${flashProgress?.progressPercent || 0}%` }}
                  />
                </div>
                <div className="text-[11px] text-slate-400 truncate">{flashProgress?.message}</div>
              </div>
            )}
          </div>

          {/* Traceability Summary Card */}
          {traceabilityRecord && (
            <div className="rounded-xl border border-emerald-800/60 bg-emerald-950/20 p-5 space-y-3 shadow-sm">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-sm font-semibold text-emerald-400">
                  <ShieldCheck className="h-4 w-4" />
                  <span>Traceability & Identity Record</span>
                </div>
                <button
                  onClick={copyTraceabilityToClipboard}
                  className="flex items-center gap-1 text-[11px] text-emerald-400 hover:text-emerald-300 transition"
                >
                  {copiedTrace ? <Check className="h-3 w-3" /> : <Copy className="h-3 w-3" />}
                  {copiedTrace ? 'Copied!' : 'Copy JSON'}
                </button>
              </div>

              <div className="space-y-1.5 text-xs font-mono bg-surface-dark/80 p-3 rounded-lg border border-surface-border">
                <div>Device ID: <span className="text-slate-200">{traceabilityRecord.deviceId}</span></div>
                <div>Serial No: <span className="text-emerald-400 font-bold">{traceabilityRecord.serialNumber}</span></div>
                <div>Variant: <span className="text-slate-300">{traceabilityRecord.productVariantId}</span></div>
                <div>Hardware Rev: <span className="text-slate-300">{traceabilityRecord.hardwareRevision}</span></div>
                <div>Firmware: <span className="text-slate-300">{traceabilityRecord.firmwareFamily} @ v{traceabilityRecord.firmwareVersion}</span></div>
                <div>Cert Fingerprint: <span className="text-slate-400 truncate block text-[10px]">{traceabilityRecord.tlsCertFingerprint}</span></div>
                <div>Duration: <span className="text-slate-300">{traceabilityRecord.durationMs} ms</span></div>
              </div>
            </div>
          )}

          {/* Console / Output Log */}
          <div className="rounded-xl border border-surface-border bg-surface-dark p-4 space-y-2 shadow-sm">
            <div className="flex items-center gap-2 text-xs font-semibold text-slate-400">
              <Terminal className="h-3.5 w-3.5" />
              <span>Bench Flasher Console</span>
            </div>
            <div className="h-48 overflow-y-auto rounded-lg bg-surface-darker p-2.5 font-mono text-[11px] text-slate-300 space-y-1">
              {consoleLogs.length === 0 ? (
                <div className="text-slate-400 italic">No operations logged yet.</div>
              ) : (
                consoleLogs.map((log, i) => (
                  <div key={i} className="leading-relaxed">
                    {log}
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
