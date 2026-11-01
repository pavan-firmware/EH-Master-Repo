/**
 * Barcode / QR Scanner Native Service Abstraction
 */

export interface ScanEvent {
  rawPayload: string;
  scannerType: 'HID_KEYBOARD' | 'SERIAL' | 'CAMERA';
  timestamp: string;
}

export interface IScannerService {
  startListening(onScan: (event: ScanEvent) => void): void;
  stopListening(): void;
  isAvailable(): boolean;
}

export class KeyboardHidScannerService implements IScannerService {
  private listener: ((event: ScanEvent) => void) | null = null;

  public startListening(onScan: (event: ScanEvent) => void): void {
    this.listener = onScan;
  }

  public stopListening(): void {
    this.listener = null;
  }

  public isAvailable(): boolean {
    return true;
  }

  public simulateScan(rawPayload: string): void {
    if (this.listener) {
      this.listener({
        rawPayload,
        scannerType: 'HID_KEYBOARD',
        timestamp: new Date().toISOString(),
      });
    }
  }
}
