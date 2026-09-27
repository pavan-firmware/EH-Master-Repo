/**
 * Serial Port Native Service Abstraction
 * 
 * Provides typed enumeration of serial ports, candidate classification,
 * and deterministic mock behavior for testing and headless execution.
 */

import { SerialPortStatus } from '@eh-home/contracts';

export interface SerialPortInfo {
  portName: string;
  vendorId?: string;
  productId?: string;
  description?: string;
  status: SerialPortStatus;
  isEspCandidate: boolean;
  manufacturer?: string;
}

export interface ISerialService {
  listAvailablePorts(): Promise<SerialPortInfo[]>;
  getPortStatus(portName: string): Promise<SerialPortStatus>;
  openPort(portName: string, baudRate: number): Promise<boolean>;
  closePort(): Promise<void>;
  sendData(data: Uint8Array): Promise<number>;
}

/**
 * Deterministic Mock Serial Service
 * Used for headless testing, CI pipelines, and browser preview.
 */
export class MockSerialService implements ISerialService {
  private mockPorts: SerialPortInfo[] = [
    {
      portName: 'COM3',
      description: 'Silicon Labs CP210x USB to UART Bridge',
      vendorId: '10C4',
      productId: 'EA60',
      status: 'AVAILABLE',
      isEspCandidate: true,
      manufacturer: 'Silicon Labs',
    },
    {
      portName: 'COM4',
      description: 'USB-Enhanced-SERIAL CH340',
      vendorId: '1A86',
      productId: '7523',
      status: 'AVAILABLE',
      isEspCandidate: true,
      manufacturer: 'WCH',
    },
    {
      portName: 'COM9',
      description: 'Standard Serial Port (In Use)',
      status: 'BUSY',
      isEspCandidate: false,
    },
  ];

  public async listAvailablePorts(): Promise<SerialPortInfo[]> {
    return [...this.mockPorts];
  }

  public async getPortStatus(portName: string): Promise<SerialPortStatus> {
    const port = this.mockPorts.find((p) => p.portName === portName);
    return port ? port.status : 'DISCONNECTED';
  }

  public async openPort(_portName: string, _baudRate: number): Promise<boolean> {
    return true;
  }

  public async closePort(): Promise<void> {}

  public async sendData(data: Uint8Array): Promise<number> {
    return data.length;
  }
}

/**
 * Tauri Native Serial Service
 * Invokes allowlisted Tauri native command `list_serial_ports`.
 */
export class TauriSerialService implements ISerialService {
  private fallbackMock = new MockSerialService();

  public async listAvailablePorts(): Promise<SerialPortInfo[]> {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const entries = await invoke<any[]>('list_serial_ports');
        return entries.map((e) => ({
          portName: e.port_name || e.portName,
          description: e.description,
          vendorId: e.vendor_id || e.vendorId,
          productId: e.product_id || e.productId,
          status: (e.status as SerialPortStatus) || 'AVAILABLE',
          isEspCandidate: e.is_esp_candidate ?? e.isEspCandidate ?? true,
          manufacturer: e.manufacturer,
        }));
      }
    } catch (err) {
      console.warn('[SerialService] Tauri native invoke failed, using mock service', err);
    }
    return this.fallbackMock.listAvailablePorts();
  }

  public async getPortStatus(portName: string): Promise<SerialPortStatus> {
    const ports = await this.listAvailablePorts();
    const match = ports.find((p) => p.portName === portName);
    return match ? match.status : 'DISCONNECTED';
  }

  public async openPort(portName: string, baudRate: number): Promise<boolean> {
    return this.fallbackMock.openPort(portName, baudRate);
  }

  public async closePort(): Promise<void> {
    return this.fallbackMock.closePort();
  }

  public async sendData(data: Uint8Array): Promise<number> {
    return this.fallbackMock.sendData(data);
  }
}

export function getSerialService(): ISerialService {
  if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
    return new TauriSerialService();
  }
  return new MockSerialService();
}
