/**
 * EH Home Desktop — System Setup & First-Run Environment Wizard
 * Comprehensive hardware, runtime, driver, printer, and network verification.
 * Follows VS Code Workbench engineering design system.
 * 
 * Performance & Lifecycle Architecture:
 * - Persistent setup results with ZERO automatic checks on revisit.
 * - Automatic checks execute ONLY on first install or version invalidation.
 * - Explicit [Recheck All] and individual section [Recheck] triggers.
 * - In-flight concurrency guards and unmount lifecycle cleanup.
 */

import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  systemSetupService,
  SystemRequirements,
  PythonRuntimeStatus,
  UsbHostEnumeration,
  ScannerSubsystemStatus,
  NetworkConnectivityStatus,
  SetupConfiguration,
  PersistedSetupState,
  SETUP_SCHEMA_VERSION,
} from '../../services/system-setup.service';
import { printerService, PrinterDevice } from '../../services/native/printer.service';
import { useAppState } from '../../state/app-state';

export const SystemSetupWizardView: React.FC = () => {
  const { setActiveTab } = useAppState();
  const [currentStep, setCurrentStep] = useState<number>(1);
  const [loading, setLoading] = useState<boolean>(true);
  const [rechecking, setRechecking] = useState<boolean>(false);
  const [recheckingSection, setRecheckingSection] = useState<string | null>(null);

  // Verification states
  const [sysReq, setSysReq] = useState<SystemRequirements | null>(null);
  const [pyStatus, setPyStatus] = useState<PythonRuntimeStatus | null>(null);
  const [usbStatus, setUsbStatus] = useState<UsbHostEnumeration | null>(null);
  const [scannerStatus, setScannerStatus] = useState<ScannerSubsystemStatus | null>(null);
  const [netStatus, setNetStatus] = useState<NetworkConnectivityStatus | null>(null);
  const [printers, setPrinters] = useState<PrinterDevice[]>([]);

  // Persistence metadata
  const [isPersistedReady, setIsPersistedReady] = useState<boolean>(false);
  const [lastCheckTime, setLastCheckTime] = useState<string>('');
  const [completedTime, setCompletedTime] = useState<string>('');

  // Form configuration
  const [config, setConfig] = useState<SetupConfiguration>(() => systemSetupService.getSetupConfiguration());
  const [copiedCmd, setCopiedCmd] = useState<boolean>(false);
  const [saveSuccess, setSaveSuccess] = useState<boolean>(false);

  const isMountedRef = useRef<boolean>(true);
  const isInFlightRef = useRef<boolean>(false);

  useEffect(() => {
    isMountedRef.current = true;
    return () => {
      isMountedRef.current = false;
    };
  }, []);

  const saveCurrentState = useCallback(
    (
      currentSys: SystemRequirements | null,
      currentPy: PythonRuntimeStatus | null,
      currentUsb: UsbHostEnumeration | null,
      currentScan: ScannerSubsystemStatus | null,
      currentNet: NetworkConnectivityStatus | null,
      currentPrn: PrinterDevice[],
      currentCfg: SetupConfiguration,
      markCompleted = false
    ) => {
      const now = new Date().toISOString();
      const state: PersistedSetupState = {
        setupVersion: SETUP_SCHEMA_VERSION,
        completed: markCompleted || isPersistedReady,
        completedAt: markCompleted ? now : completedTime || now,
        lastCheckAt: now,
        overallStatus:
          currentSys?.meets_minimum_specs && currentPy?.all_ready && currentNet?.api_reachable
            ? 'READY'
            : 'WARNING',
        individualCheckResults: {
          system: currentSys,
          python: currentPy,
          usb: currentUsb,
          scanner: currentScan,
          network: currentNet,
          printers: currentPrn,
        },
        stationConfiguration: currentCfg,
      };
      systemSetupService.savePersistedSetupState(state);
      if (isMountedRef.current) {
        setLastCheckTime(now);
        if (markCompleted) {
          setCompletedTime(now);
          setIsPersistedReady(true);
        }
      }
    },
    [isPersistedReady, completedTime]
  );

  const runAllChecks = useCallback(
    async (isManualRecheck = false) => {
      if (isInFlightRef.current) return;
      isInFlightRef.current = true;

      if (isManualRecheck) {
        setRechecking(true);
      } else {
        setLoading(true);
      }

      try {
        const [sys, py, usb, scan, net, prn] = await Promise.all([
          systemSetupService.checkSystemRequirements(),
          systemSetupService.checkPythonRuntime(),
          systemSetupService.enumerateUsbDevices(),
          systemSetupService.checkScannerSubsystem(),
          systemSetupService.checkNetwork(config.api_url),
          printerService.listAvailablePrinters(),
        ]);

        if (!isMountedRef.current) return;

        setSysReq(sys);
        setPyStatus(py);
        setUsbStatus(usb);
        setScannerStatus(scan);
        setNetStatus(net);
        setPrinters(prn);

        saveCurrentState(sys, py, usb, scan, net, prn, config, false);
      } catch (err) {
        console.error('Environment check failed', err);
      } finally {
        isInFlightRef.current = false;
        if (isMountedRef.current) {
          setLoading(false);
          setRechecking(false);
        }
      }
    },
    [config, saveCurrentState]
  );

  // Mount logic: Load saved results if available; run checks ONLY on first install or invalid schema
  useEffect(() => {
    const saved = systemSetupService.getPersistedSetupState();
    if (saved && saved.completed && saved.setupVersion === SETUP_SCHEMA_VERSION) {
      // LOAD SAVED RESULTS DIRECTLY — ZERO AUTOMATIC OS/WMI/PROCESS CHECKS
      setSysReq(saved.individualCheckResults.system);
      setPyStatus(saved.individualCheckResults.python);
      setUsbStatus(saved.individualCheckResults.usb);
      setScannerStatus(saved.individualCheckResults.scanner);
      setNetStatus(saved.individualCheckResults.network);
      setPrinters(saved.individualCheckResults.printers || []);
      setConfig(saved.stationConfiguration);
      setIsPersistedReady(true);
      setLastCheckTime(saved.lastCheckAt || '');
      setCompletedTime(saved.completedAt || '');
      setLoading(false);
    } else {
      // First-run experience: No valid completed setup state found
      runAllChecks(false);
    }
  }, []);

  const handleRecheckAll = () => {
    runAllChecks(true);
  };

  const handleRecheckSection = async (section: 'sys' | 'py' | 'usb' | 'scan' | 'net') => {
    if (isInFlightRef.current) return;
    isInFlightRef.current = true;
    setRecheckingSection(section);

    try {
      if (section === 'sys') {
        const sys = await systemSetupService.checkSystemRequirements();
        if (isMountedRef.current) setSysReq(sys);
      } else if (section === 'py') {
        const py = await systemSetupService.checkPythonRuntime();
        if (isMountedRef.current) setPyStatus(py);
      } else if (section === 'usb') {
        const usb = await systemSetupService.enumerateUsbDevices();
        if (isMountedRef.current) setUsbStatus(usb);
      } else if (section === 'scan') {
        const scan = await systemSetupService.checkScannerSubsystem();
        if (isMountedRef.current) setScannerStatus(scan);
      } else if (section === 'net') {
        const net = await systemSetupService.checkNetwork(config.api_url);
        if (isMountedRef.current) setNetStatus(net);
      }
    } catch (err) {
      console.error(`Failed to recheck ${section}`, err);
    } finally {
      isInFlightRef.current = false;
      if (isMountedRef.current) {
        setRecheckingSection(null);
      }
    }
  };

  const handleCopy = (text: string) => {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
      setCopiedCmd(true);
      setTimeout(() => setCopiedCmd(false), 2000);
    }
  };

  const handleSaveAndComplete = () => {
    saveCurrentState(sysReq, pyStatus, usbStatus, scannerStatus, netStatus, printers, config, true);
    setSaveSuccess(true);
    setTimeout(() => {
      setActiveTab('dashboard');
    }, 800);
  };

  const steps = [
    { num: 1, title: 'System Specs' },
    { num: 2, title: 'Python Flasher' },
    { num: 3, title: 'Hardware & USB' },
    { num: 4, title: 'Network & API' },
    { num: 5, title: 'Station Config' },
  ];

  const formatTimestamp = (ts: string) => {
    if (!ts) return 'Never';
    try {
      const d = new Date(ts);
      return `${d.toLocaleDateString()} ${d.toLocaleTimeString()}`;
    } catch {
      return ts;
    }
  };

  return (
    <div className="flex flex-col h-full space-y-4 max-w-5xl mx-auto">
      {/* Header & Title */}
      <div className="flex items-center justify-between border-b border-[#3C3C3C] pb-3">
        <div>
          <div className="flex items-center space-x-2">
            <span className="text-xs font-semibold px-2 py-0.5 bg-[#007ACC]/20 text-[#3794FF] border border-[#007ACC]/40 rounded">
              FIRST-RUN ENVIRONMENT SETUP
            </span>
            <h1 className="text-base font-medium text-white tracking-wide">System Setup & Requirement Diagnostics</h1>
          </div>
          <p className="text-xs text-[#858585] mt-1">
            Real hardware enumeration, manufacturing toolchain validation, printer discovery, and station configuration.
          </p>
        </div>

        <div className="flex items-center space-x-2">
          {isPersistedReady && (
            <div className="text-right mr-2 hidden sm:block">
              <div className="text-[10px] text-emerald-400 font-semibold font-mono">STATUS: READY (PERSISTED)</div>
              <div className="text-[10px] text-[#858585] font-mono">
                Checked: {formatTimestamp(lastCheckTime)}
              </div>
            </div>
          )}
          <button
            onClick={handleRecheckAll}
            disabled={loading || rechecking || !!recheckingSection}
            className="flex items-center space-x-1.5 px-3 py-1.5 bg-[#252526] hover:bg-[#2D2D2D] disabled:opacity-50 text-xs font-medium text-slate-200 border border-[#3C3C3C] rounded transition"
            title="Perform full explicit hardware and toolchain recheck"
          >
            <span className={rechecking ? 'animate-spin' : ''}>↻</span>
            <span>{rechecking ? 'Rechecking All...' : 'Recheck All'}</span>
          </button>
        </div>
      </div>

      {/* Step Stepper Navigation */}
      <div className="grid grid-cols-5 gap-2 bg-[#252526] p-1.5 border border-[#3C3C3C] rounded">
        {steps.map((s) => {
          const isActive = currentStep === s.num;
          const isDone = currentStep > s.num;
          return (
            <button
              key={s.num}
              onClick={() => setCurrentStep(s.num)}
              className={`flex items-center justify-center space-x-2 py-1.5 px-3 rounded text-xs transition ${
                isActive
                  ? 'bg-[#007ACC] text-white font-semibold'
                  : isDone
                  ? 'bg-[#1E1E1E] text-emerald-400 font-medium'
                  : 'text-[#858585] hover:text-slate-300'
              }`}
            >
              <span className="w-4 h-4 rounded-full flex items-center justify-center text-[10px] bg-black/30">
                {isDone ? '✓' : s.num}
              </span>
              <span>{s.title}</span>
            </button>
          );
        })}
      </div>

      {/* Main Content Area */}
      <div className="flex-1 bg-[#252526] border border-[#3C3C3C] rounded p-5 overflow-y-auto">
        {loading ? (
          <div className="flex flex-col items-center justify-center py-16 space-y-3">
            <div className="w-8 h-8 border-2 border-[#007ACC]/30 border-t-[#007ACC] rounded-full animate-spin"></div>
            <div className="text-xs text-[#858585]">Querying host OS subsystems and hardware drivers...</div>
          </div>
        ) : (
          <>
            {/* STEP 1: SYSTEM & OS REQUIREMENTS */}
            {currentStep === 1 && sysReq && (
              <div className="space-y-4">
                <div className="flex items-center justify-between pb-2 border-b border-[#3C3C3C]">
                  <div>
                    <h2 className="text-sm font-semibold text-white">Host Operating System & Core Runtime</h2>
                    <p className="text-xs text-[#858585]">Verifies CPU concurrency, physical memory, storage space, and WebView2 engine.</p>
                  </div>
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => handleRecheckSection('sys')}
                      disabled={!!recheckingSection || rechecking}
                      className="text-xs px-2 py-1 bg-[#1E1E1E] hover:bg-[#2A2D2E] border border-[#3C3C3C] text-slate-300 rounded"
                    >
                      {recheckingSection === 'sys' ? 'Rechecking...' : 'Recheck Specs'}
                    </button>
                    <span
                      className={`px-2 py-0.5 text-xs font-semibold rounded border ${
                        sysReq.meets_minimum_specs
                          ? 'bg-emerald-950/40 text-emerald-400 border-emerald-800'
                          : 'bg-amber-950/40 text-amber-400 border-amber-800'
                      }`}
                    >
                      {sysReq.meets_minimum_specs ? 'REQUIREMENTS SATISFIED' : 'NEEDS ATTENTION'}
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-[#1E1E1E] p-3 border border-[#3C3C3C] rounded space-y-2">
                    <div className="text-xs font-medium text-[#858585]">Operating System</div>
                    <div className="text-sm text-slate-100 font-mono">{sysReq.os_version}</div>
                    <div className="text-xs text-[#858585]">Architecture: <span className="text-slate-300 font-mono">{sysReq.arch}</span></div>
                  </div>

                  <div className="bg-[#1E1E1E] p-3 border border-[#3C3C3C] rounded space-y-2">
                    <div className="text-xs font-medium text-[#858585]">CPU Concurrency</div>
                    <div className="text-sm text-slate-100 font-mono">{sysReq.cpu_cores} Logical Cores</div>
                    <div className="text-xs text-emerald-400">Multi-threaded flashing engine ready</div>
                  </div>

                  <div className="bg-[#1E1E1E] p-3 border border-[#3C3C3C] rounded space-y-2">
                    <div className="text-xs font-medium text-[#858585]">Physical Memory</div>
                    <div className="text-sm text-slate-100 font-mono">{sysReq.total_memory_mb} MB Total ({sysReq.free_memory_mb} MB Free)</div>
                    <div className="text-xs text-[#858585]">Min Req: 2048 MB (4096 MB Recommended)</div>
                  </div>

                  <div className="bg-[#1E1E1E] p-3 border border-[#3C3C3C] rounded space-y-2">
                    <div className="text-xs font-medium text-[#858585]">WebView2 Runtime Engine</div>
                    <div className="text-sm text-slate-100 font-mono">{sysReq.webview2_version || 'Installed'}</div>
                    <div className="text-xs text-emerald-400">Native Evergreen WebView2 Runtime Active</div>
                  </div>
                </div>

                {sysReq.warnings.length > 0 && (
                  <div className="p-3 bg-amber-950/20 border border-amber-800/40 rounded text-xs text-amber-300">
                    {sysReq.warnings.map((w, idx) => (
                      <div key={idx}>⚠️ {w}</div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* STEP 2: PYTHON MANUFACTURING FLASHER RUNTIME */}
            {currentStep === 2 && pyStatus && (
              <div className="space-y-4">
                <div className="flex items-center justify-between pb-2 border-b border-[#3C3C3C]">
                  <div>
                    <h2 className="text-sm font-semibold text-white">Python Manufacturing Flasher Toolchain</h2>
                    <p className="text-xs text-[#858585]">Required for bench flasher sidecar execution, secure partition flashing, and chip identification.</p>
                  </div>
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => handleRecheckSection('py')}
                      disabled={!!recheckingSection || rechecking}
                      className="text-xs px-2 py-1 bg-[#1E1E1E] hover:bg-[#2A2D2E] border border-[#3C3C3C] text-slate-300 rounded"
                    >
                      {recheckingSection === 'py' ? 'Rechecking...' : 'Recheck Python'}
                    </button>
                    <span
                      className={`px-2 py-0.5 text-xs font-semibold rounded border ${
                        pyStatus.all_ready
                          ? 'bg-emerald-950/40 text-emerald-400 border-emerald-800'
                          : 'bg-amber-950/40 text-amber-400 border-amber-800'
                      }`}
                    >
                      {pyStatus.all_ready ? 'TOOLCHAIN READY' : 'DEPENDENCIES MISSING'}
                    </span>
                  </div>
                </div>

                <div className="bg-[#1E1E1E] p-3 border border-[#3C3C3C] rounded flex items-center justify-between">
                  <div>
                    <div className="text-xs text-[#858585]">Python Executable</div>
                    <div className="text-sm font-mono text-slate-100">{pyStatus.python_executable || 'Not Found on PATH'}</div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs text-[#858585]">Detected Version</div>
                    <div className="text-sm font-mono text-slate-100">{pyStatus.python_version || 'None'} (Required: &gt;= 3.8)</div>
                  </div>
                </div>

                <div className="border border-[#3C3C3C] rounded overflow-hidden">
                  <table className="w-full text-left text-xs">
                    <thead className="bg-[#1E1E1E] text-[#858585] border-b border-[#3C3C3C]">
                      <tr>
                        <th className="p-2.5">Package</th>
                        <th className="p-2.5">Required Version</th>
                        <th className="p-2.5">Detected Version</th>
                        <th className="p-2.5 text-right">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-[#3C3C3C]">
                      {pyStatus.packages.map((pkg) => (
                        <tr key={pkg.name} className="hover:bg-[#2A2D2E]">
                          <td className="p-2.5 font-mono text-slate-200">{pkg.name}</td>
                          <td className="p-2.5 text-[#858585]">{pkg.required_version}</td>
                          <td className="p-2.5 font-mono text-slate-300">{pkg.detected_version || 'Not Installed'}</td>
                          <td className="p-2.5 text-right">
                            <span
                              className={`px-2 py-0.5 text-[11px] font-semibold rounded ${
                                pkg.installed ? 'bg-emerald-950/50 text-emerald-400' : 'bg-rose-950/50 text-rose-400'
                              }`}
                            >
                              {pkg.installed ? 'INSTALLED' : 'MISSING'}
                            </span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                {!pyStatus.all_ready && (
                  <div className="p-3 bg-[#1E1E1E] border border-amber-800/40 rounded space-y-2">
                    <div className="text-xs font-semibold text-amber-300">Quick Repair Instruction</div>
                    <div className="flex items-center justify-between bg-black/40 p-2 rounded font-mono text-xs text-slate-200">
                      <span>pip install pyserial esptool cryptography</span>
                      <button
                        onClick={() => handleCopy('pip install pyserial esptool cryptography')}
                        className="px-2 py-1 bg-[#007ACC] hover:bg-[#0062A3] text-white rounded text-[11px]"
                      >
                        {copiedCmd ? 'Copied!' : 'Copy Command'}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* STEP 3: HARDWARE, USB & PRINTERS */}
            {currentStep === 3 && (
              <div className="space-y-4">
                <div className="flex items-center justify-between pb-2 border-b border-[#3C3C3C]">
                  <div>
                    <h2 className="text-sm font-semibold text-white">Hardware Subsystems, USB Serial & Printers</h2>
                    <p className="text-xs text-[#858585]">Real PnP device discovery, USB serial drivers, 2D barcode scanner, and label printers.</p>
                  </div>
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => handleRecheckSection('usb')}
                      disabled={!!recheckingSection || rechecking}
                      className="text-xs px-2 py-1 bg-[#1E1E1E] hover:bg-[#2A2D2E] border border-[#3C3C3C] text-slate-300 rounded"
                    >
                      {recheckingSection === 'usb' ? 'Scanning...' : 'Rescan USB / Ports'}
                    </button>
                  </div>
                </div>

                {/* USB Serial Devices */}
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold text-[#858585]">DISCOVERED USB SERIAL DEVICES</span>
                    <span className="text-xs text-slate-400">{usbStatus?.count || 0} device(s)</span>
                  </div>

                  {usbStatus && usbStatus.devices.length > 0 ? (
                    <div className="border border-[#3C3C3C] rounded overflow-hidden">
                      <table className="w-full text-left text-xs">
                        <thead className="bg-[#1E1E1E] text-[#858585] border-b border-[#3C3C3C]">
                          <tr>
                            <th className="p-2">Port</th>
                            <th className="p-2">VID / PID</th>
                            <th className="p-2">Manufacturer</th>
                            <th className="p-2">Driver Status</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-[#3C3C3C]">
                          {usbStatus.devices.map((d, idx) => (
                            <tr key={idx} className="hover:bg-[#2A2D2E]">
                              <td className="p-2 font-mono text-slate-200">{d.port_name}</td>
                              <td className="p-2 font-mono text-[#858585]">{d.vendor_id || 'N/A'}:{d.product_id || 'N/A'}</td>
                              <td className="p-2 text-slate-300">{d.manufacturer || 'Silicon Labs / Espressif'}</td>
                              <td className="p-2 text-emerald-400">{d.driver_status}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  ) : (
                    <div className="p-4 bg-[#1E1E1E] border border-dashed border-[#3C3C3C] rounded text-center text-xs text-[#858585]">
                      No compatible serial device currently plugged in. (Plug in an ESP32 via USB anytime to flash).
                    </div>
                  )}
                </div>

                {/* Barcode / QR Scanner & Printers */}
                <div className="grid grid-cols-2 gap-4 pt-2">
                  <div className="bg-[#1E1E1E] p-3 border border-[#3C3C3C] rounded space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-semibold text-[#858585]">BARCODE / QR SCANNER</span>
                      <button
                        onClick={() => handleRecheckSection('scan')}
                        disabled={!!recheckingSection || rechecking}
                        className="text-[10px] text-[#3794FF] hover:underline"
                      >
                        {recheckingSection === 'scan' ? 'Testing...' : 'Test'}
                      </button>
                    </div>
                    <div className="text-xs text-slate-200">{scannerStatus?.scanner_name || 'USB HID Keyboard Emulation Mode'}</div>
                    <div className="text-[11px] text-[#858585]">State: <span className="font-mono text-slate-300">{scannerStatus?.last_scan_state || 'STANDBY'}</span></div>
                  </div>

                  <div className="bg-[#1E1E1E] p-3 border border-[#3C3C3C] rounded space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-semibold text-[#858585]">PRINTER SUBSYSTEM</span>
                      <span className="text-xs font-semibold text-emerald-400">{printers.length} DETECTED</span>
                    </div>
                    <div className="text-xs text-slate-200">
                      Virtual PDF: {printers.some((p) => p.isVirtualPdf || p.name.includes('PDF')) ? 'Microsoft Print to PDF' : 'None'}
                    </div>
                    <div className="text-[11px] text-[#858585]">Physical TSPL/ESC-POS: {printers.filter((p) => !p.isVirtualPdf).length} printer(s)</div>
                  </div>
                </div>
              </div>
            )}

            {/* STEP 4: NETWORK & API CONNECTIVITY */}
            {currentStep === 4 && (
              <div className="space-y-4">
                <div className="flex items-center justify-between pb-2 border-b border-[#3C3C3C]">
                  <div>
                    <h2 className="text-sm font-semibold text-white">Network & Backend REST API Connectivity</h2>
                    <p className="text-xs text-[#858585]">Validates API endpoint availability, HTTP latency, and local MQTT broker accessibility.</p>
                  </div>
                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => handleRecheckSection('net')}
                      disabled={!!recheckingSection || rechecking}
                      className="text-xs px-2 py-1 bg-[#1E1E1E] hover:bg-[#2A2D2E] border border-[#3C3C3C] text-slate-300 rounded"
                    >
                      {recheckingSection === 'net' ? 'Pinging...' : 'Ping Network'}
                    </button>
                    <span
                      className={`px-2 py-0.5 text-xs font-semibold rounded border ${
                        netStatus?.api_reachable
                          ? 'bg-emerald-950/40 text-emerald-400 border-emerald-800'
                          : 'bg-amber-950/40 text-amber-400 border-amber-800'
                      }`}
                    >
                      {netStatus?.api_reachable ? 'API REACHABLE' : 'API OFFLINE / UNREACHABLE'}
                    </span>
                  </div>
                </div>

                <div className="bg-[#1E1E1E] p-3 border border-[#3C3C3C] rounded space-y-3">
                  <div className="flex items-center justify-between">
                    <label className="text-xs font-medium text-[#858585]">REST API Base URL</label>
                  </div>
                  <input
                    type="text"
                    value={config.api_url}
                    onChange={(e) => setConfig({ ...config, api_url: e.target.value })}
                    className="w-full bg-[#252526] border border-[#3C3C3C] rounded px-3 py-1.5 text-xs font-mono text-slate-100 focus:outline-none focus:border-[#007ACC]"
                  />
                  <div className="grid grid-cols-3 gap-2 text-xs">
                    <div className="text-[#858585]">API Status: <span className={netStatus?.api_reachable ? 'text-emerald-400 font-semibold' : 'text-rose-400 font-semibold'}>{netStatus?.api_reachable ? 'Online (200 OK)' : 'Unreachable'}</span></div>
                    <div className="text-[#858585]">Latency: <span className="font-mono text-slate-300">{netStatus?.api_latency_ms ? `${netStatus.api_latency_ms} ms` : 'N/A'}</span></div>
                    <div className="text-[#858585]">MQTT Broker: <span className={netStatus?.mqtt_reachable ? 'text-emerald-400 font-semibold' : 'text-amber-400 font-semibold'}>{netStatus?.mqtt_reachable ? 'Port 1883 Open' : 'Offline / Standby'}</span></div>
                  </div>
                </div>

                <div className="p-3 bg-[#1E1E1E] border border-[#3C3C3C] rounded text-xs text-[#858585] space-y-1">
                  <div className="font-semibold text-slate-300">Firewall & Permissions Scope</div>
                  <div>EH Home operates with scoped local network loopback and standard HTTP/TCP client sockets. No unrestricted host firewall elevation is requested.</div>
                </div>
              </div>
            )}

            {/* STEP 5: STATION CONFIGURATION */}
            {currentStep === 5 && (
              <div className="space-y-4">
                <div className="flex items-center justify-between pb-2 border-b border-[#3C3C3C]">
                  <div>
                    <h2 className="text-sm font-semibold text-white">Bench Station Identity & Operational Defaults</h2>
                    <p className="text-xs text-[#858585]">Set default operator identifier, bench station ID, default flasher baud rate, and label printer.</p>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1.5">
                    <label className="text-xs font-medium text-[#858585]">Station ID</label>
                    <input
                      type="text"
                      value={config.station_id}
                      onChange={(e) => setConfig({ ...config, station_id: e.target.value })}
                      className="w-full bg-[#1E1E1E] border border-[#3C3C3C] rounded px-3 py-1.5 text-xs font-mono text-slate-100 focus:outline-none focus:border-[#007ACC]"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-xs font-medium text-[#858585]">Default Operator</label>
                    <input
                      type="text"
                      value={config.operator_id}
                      onChange={(e) => setConfig({ ...config, operator_id: e.target.value })}
                      className="w-full bg-[#1E1E1E] border border-[#3C3C3C] rounded px-3 py-1.5 text-xs font-mono text-slate-100 focus:outline-none focus:border-[#007ACC]"
                    />
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-xs font-medium text-[#858585]">Default Flasher Baud Rate</label>
                    <select
                      value={config.baud_rate}
                      onChange={(e) => setConfig({ ...config, baud_rate: Number(e.target.value) })}
                      className="w-full bg-[#1E1E1E] border border-[#3C3C3C] rounded px-3 py-1.5 text-xs font-mono text-slate-100 focus:outline-none focus:border-[#007ACC]"
                    >
                      <option value="115200">115200 (Standard Reliability)</option>
                      <option value="460800">460800 (Fast)</option>
                      <option value="921600">921600 (High-Throughput Production Default)</option>
                      <option value="1500000">1500000 (Maximum Native USB CDC)</option>
                    </select>
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-xs font-medium text-[#858585]">Default Label & Document Printer</label>
                    <select
                      value={config.default_printer_id || ''}
                      onChange={(e) => setConfig({ ...config, default_printer_id: e.target.value })}
                      className="w-full bg-[#1E1E1E] border border-[#3C3C3C] rounded px-3 py-1.5 text-xs font-mono text-slate-100 focus:outline-none focus:border-[#007ACC]"
                    >
                      <option value="Microsoft Print to PDF">Microsoft Print to PDF (Virtual)</option>
                      {printers.map((p) => (
                        <option key={p.id} value={p.id}>
                          {p.name} {p.isVirtualPdf ? '(Virtual)' : '(Physical)'}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                {saveSuccess && (
                  <div className="p-3 bg-emerald-950/40 border border-emerald-800 rounded text-xs text-emerald-300">
                    ✓ Configuration saved successfully! Launching engineering workbench...
                  </div>
                )}
              </div>
            )}
          </>
        )}
      </div>

      {/* Wizard Footer Navigation */}
      <div className="flex items-center justify-between border-t border-[#3C3C3C] pt-3">
        <button
          onClick={() => setCurrentStep((prev) => Math.max(1, prev - 1))}
          disabled={currentStep === 1}
          className="px-4 py-1.5 bg-[#252526] hover:bg-[#2D2D2D] disabled:opacity-40 text-xs font-medium text-slate-200 border border-[#3C3C3C] rounded transition"
        >
          Previous
        </button>

        <div className="flex items-center space-x-2">
          {currentStep < 5 ? (
            <button
              onClick={() => setCurrentStep((prev) => Math.min(5, prev + 1))}
              className="px-5 py-1.5 bg-[#007ACC] hover:bg-[#0062A3] text-xs font-semibold text-white rounded transition"
            >
              Next Step →
            </button>
          ) : (
            <button
              onClick={handleSaveAndComplete}
              className="px-6 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-xs font-semibold text-white rounded transition shadow"
            >
              Complete Setup & Open Workbench
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
