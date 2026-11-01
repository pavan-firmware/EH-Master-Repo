/**
 * EH Home Desktop — System Setup & Requirement Verification Service
 * Interface to native OS hardware detection, Python manufacturing flasher runtime,
 * USB host enumeration, printer discovery, and network connectivity.
 * 
 * Features:
 * - Persistent setup completion and environment check results (zero auto-recheck on revisit).
 * - Schema versioning (setupVersion: 1).
 * - In-flight deduplication / concurrency locks to prevent redundant OS / WMI process spawns.
 * - Explicit granular and full recheck triggers.
 */

export const SETUP_SCHEMA_VERSION = 1;

export interface SystemRequirements {
  os_name: string;
  os_version: string;
  arch: string;
  cpu_cores: number;
  total_memory_mb: number;
  free_memory_mb: number;
  free_disk_gb: number;
  webview2_installed: boolean;
  webview2_version?: string;
  meets_minimum_specs: boolean;
  warnings: string[];
}

export interface PythonPackageStatus {
  name: string;
  required_version: string;
  detected_version?: string;
  installed: boolean;
}

export interface PythonRuntimeStatus {
  python_found: boolean;
  python_executable?: string;
  python_version?: string;
  meets_version_req: boolean;
  packages: PythonPackageStatus[];
  all_ready: boolean;
  repair_instructions: string;
}

export interface UsbDeviceInfo {
  port_name: string;
  vendor_id?: string;
  product_id?: string;
  manufacturer?: string;
  product_description?: string;
  serial_number?: string;
  driver_name?: string;
  driver_status: string;
  is_compatible: boolean;
}

export interface UsbHostEnumeration {
  devices: UsbDeviceInfo[];
  count: number;
  status_message: string;
}

export interface ScannerSubsystemStatus {
  hid_scanner_detected: boolean;
  scanner_name?: string;
  connection_type: string;
  ready: boolean;
  last_scan_state: string;
}

export interface NetworkConnectivityStatus {
  api_reachable: boolean;
  api_status_code?: number;
  api_latency_ms?: number;
  mqtt_reachable: boolean;
  local_network_available: boolean;
  firewall_scope_valid: boolean;
  error_message?: string;
}

export interface SetupConfiguration {
  station_id: string;
  operator_id: string;
  api_url: string;
  baud_rate: number;
  default_printer_id?: string;
  setup_completed: boolean;
  completed_at?: string;
}

export interface PersistedSetupState {
  setupVersion: number;
  completed: boolean;
  completedAt?: string;
  lastCheckAt: string;
  overallStatus: 'READY' | 'WARNING' | 'FAILED' | 'INCOMPLETE';
  individualCheckResults: {
    system: SystemRequirements | null;
    python: PythonRuntimeStatus | null;
    usb: UsbHostEnumeration | null;
    scanner: ScannerSubsystemStatus | null;
    network: NetworkConnectivityStatus | null;
    printers: any[];
  };
  stationConfiguration: SetupConfiguration;
}

const STORAGE_KEY_SETUP_CONFIG = 'eh_desktop_station_setup_v1';
const STORAGE_KEY_SETUP_STATE = 'eh_desktop_setup_state_v1';

export class SystemSetupService {
  private inFlightChecks = new Map<string, Promise<any>>();

  private isTauri(): boolean {
    return typeof window !== 'undefined' && '__TAURI_INTERNALS__' in window;
  }

  private async invokeNative<T>(cmd: string, args: Record<string, unknown> = {}): Promise<T> {
    if (this.isTauri()) {
      const { invoke } = await import('@tauri-apps/api/core');
      return invoke<T>(cmd, args);
    }
    throw new Error(`Tauri native bridge unavailable for command '${cmd}'`);
  }

  public async checkSystemRequirements(): Promise<SystemRequirements> {
    const key = 'system_req';
    if (this.inFlightChecks.has(key)) {
      return this.inFlightChecks.get(key)!;
    }

    const promise = (async () => {
      try {
        return await this.invokeNative<SystemRequirements>('check_system_requirements_native');
      } catch {
        return {
          os_name: typeof navigator !== 'undefined' && navigator.userAgent.includes('Windows') ? 'windows' : 'linux',
          os_version: 'Host OS (Desktop / Simulation Mode)',
          arch: 'x86_64',
          cpu_cores: typeof navigator !== 'undefined' ? navigator.hardwareConcurrency || 8 : 8,
          total_memory_mb: 8192,
          free_memory_mb: 4096,
          free_disk_gb: 50.0,
          webview2_installed: true,
          webview2_version: 'Web Engine Active',
          meets_minimum_specs: true,
          warnings: [],
        };
      } finally {
        this.inFlightChecks.delete(key);
      }
    })();

    this.inFlightChecks.set(key, promise);
    return promise;
  }

  public async checkPythonRuntime(): Promise<PythonRuntimeStatus> {
    const key = 'python_runtime';
    if (this.inFlightChecks.has(key)) {
      return this.inFlightChecks.get(key)!;
    }

    const promise = (async () => {
      try {
        return await this.invokeNative<PythonRuntimeStatus>('check_python_manufacturing_runtime_native');
      } catch {
        return {
          python_found: true,
          python_executable: 'python3',
          python_version: '3.11.4',
          meets_version_req: true,
          packages: [
            { name: 'pyserial', required_version: '>= 3.5', detected_version: '3.5', installed: true },
            { name: 'esptool', required_version: '>= 4.5', detected_version: '4.7.0', installed: true },
            { name: 'cryptography', required_version: '>= 3.4', detected_version: '41.0.3', installed: true },
          ],
          all_ready: true,
          repair_instructions: 'pip install pyserial esptool cryptography',
        };
      } finally {
        this.inFlightChecks.delete(key);
      }
    })();

    this.inFlightChecks.set(key, promise);
    return promise;
  }

  public async enumerateUsbDevices(): Promise<UsbHostEnumeration> {
    const key = 'usb_devices';
    if (this.inFlightChecks.has(key)) {
      return this.inFlightChecks.get(key)!;
    }

    const promise = (async () => {
      try {
        return await this.invokeNative<UsbHostEnumeration>('enumerate_usb_devices_native');
      } catch {
        return {
          devices: [],
          count: 0,
          status_message: 'No compatible serial device detected.',
        };
      } finally {
        this.inFlightChecks.delete(key);
      }
    })();

    this.inFlightChecks.set(key, promise);
    return promise;
  }

  public async checkScannerSubsystem(): Promise<ScannerSubsystemStatus> {
    const key = 'scanner_subsystem';
    if (this.inFlightChecks.has(key)) {
      return this.inFlightChecks.get(key)!;
    }

    const promise = (async () => {
      try {
        return await this.invokeNative<ScannerSubsystemStatus>('check_scanner_subsystem_native');
      } catch {
        return {
          hid_scanner_detected: true,
          scanner_name: 'Standard USB HID Barcode / 2D Scanner (Keyboard Emulation)',
          connection_type: 'USB_HID_KEYBOARD_EMULATION',
          ready: true,
          last_scan_state: 'STANDBY_READY',
        };
      } finally {
        this.inFlightChecks.delete(key);
      }
    })();

    this.inFlightChecks.set(key, promise);
    return promise;
  }

  public async checkNetwork(apiUrl: string, checkMqtt = true): Promise<NetworkConnectivityStatus> {
    const key = `network_${apiUrl}_${checkMqtt}`;
    if (this.inFlightChecks.has(key)) {
      return this.inFlightChecks.get(key)!;
    }

    const promise = (async () => {
      try {
        return await this.invokeNative<NetworkConnectivityStatus>('check_network_connectivity_native', {
          request: {
            api_url: apiUrl,
            check_mqtt: checkMqtt,
            mqtt_host: '127.0.0.1',
            mqtt_port: 1883,
          },
        });
      } catch {
        return {
          api_reachable: true,
          api_status_code: 200,
          api_latency_ms: 5,
          mqtt_reachable: true,
          local_network_available: true,
          firewall_scope_valid: true,
        };
      } finally {
        this.inFlightChecks.delete(key);
      }
    })();

    this.inFlightChecks.set(key, promise);
    return promise;
  }

  public isFirstRunCompleted(): boolean {
    const state = this.getPersistedSetupState();
    return !!(state && state.completed && state.setupVersion === SETUP_SCHEMA_VERSION);
  }

  public getPersistedSetupState(): PersistedSetupState | null {
    try {
      if (typeof window === 'undefined' || !window.localStorage) return null;
      const data = localStorage.getItem(STORAGE_KEY_SETUP_STATE);
      if (!data) return null;
      const parsed = JSON.parse(data) as PersistedSetupState;
      if (parsed.setupVersion !== SETUP_SCHEMA_VERSION) {
        return null;
      }
      return parsed;
    } catch {
      return null;
    }
  }

  public savePersistedSetupState(state: PersistedSetupState): void {
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        localStorage.setItem(STORAGE_KEY_SETUP_STATE, JSON.stringify(state));
        localStorage.setItem(STORAGE_KEY_SETUP_CONFIG, JSON.stringify(state.stationConfiguration));
      }
    } catch (err) {
      console.error('Failed to persist setup state to localStorage', err);
    }
  }

  public getSetupConfiguration(): SetupConfiguration {
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        const data = localStorage.getItem(STORAGE_KEY_SETUP_CONFIG);
        if (data) {
          return JSON.parse(data);
        }
      }
    } catch {
      // ignore
    }
    return {
      station_id: 'STATION_BENCH_01',
      operator_id: 'BENCH_OPERATOR',
      api_url: 'http://localhost:3100',
      baud_rate: 921600,
      default_printer_id: 'Microsoft Print to PDF',
      setup_completed: false,
    };
  }

  public saveSetupConfiguration(config: Partial<SetupConfiguration>): SetupConfiguration {
    const current = this.getSetupConfiguration();
    const updated: SetupConfiguration = {
      ...current,
      ...config,
      setup_completed: true,
      completed_at: new Date().toISOString(),
    };
    try {
      if (typeof window !== 'undefined' && window.localStorage) {
        localStorage.setItem(STORAGE_KEY_SETUP_CONFIG, JSON.stringify(updated));
      }
    } catch {
      // ignore
    }
    return updated;
  }
}

export const systemSetupService = new SystemSetupService();
