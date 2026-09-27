import { LabelDataModel } from './label';
import { assertNoSecretsInRecord } from './generator';

/**
 * Standard ESC/POS Command Constants
 */
const ESC = '\x1b';
const GS = '\x1d';

/**
 * Generates deterministic ESC/POS printer byte stream / string commands for receipt/slip printers.
 *
 * Scoping:
 * - TSPL is the primary device label protocol for adhesive thermal labels with gap sensing (e.g. TSC TE200).
 * - ESC/POS is the standard line/journal protocol for continuous paper receipt printers (e.g. Epson TM-T88, 58mm/80mm rolls).
 *
 * This generator formats a manufacturing bench traveler / quality slip.
 */
export function generateReceiptEscPos(data: LabelDataModel): string {
  assertNoSecretsInRecord(data);

  const qrUri = data.qrUri;
  const qrLen = qrUri.length + 3; // pL, pH calculation for GS ( k
  const pL = String.fromCharCode(qrLen & 0xff);
  const pH = String.fromCharCode((qrLen >> 8) & 0xff);

  const commands: string[] = [
    `${ESC}@`, // Initialize printer
    `${ESC}a\x01`, // Center alignment
    `${ESC}!\x38`, // Double-height, double-width text
    `EH HOME\n`,
    `${ESC}!\x00`, // Normal text
    `Manufacturing Traveler Slip\n`,
    `--------------------------------\n`,
    `${ESC}a\x00`, // Left alignment
    `Device:   ${data.productDisplayName}\n`,
    `Model:    ${data.productVariantId}\n`,
    `Serial:   ${data.serialNumber}\n`,
    `HW Rev:   ${data.hardwareRevision}\n`,
    `Firmware: ${data.firmwareVersion}\n`,
    `Device ID:${data.deviceId}\n`,
    `Date:     ${data.manufacturedAt || new Date().toISOString()}\n`,
    `--------------------------------\n`,
    `${ESC}a\x01`, // Center alignment
    // ESC/POS QR Code Sequence (Model 2, Error Correction Level M)
    `${GS}(k\x04\x00\x31\x41\x32\x00`, // Select QR model 2
    `${GS}(k\x03\x00\x31\x43\x05`, // Set module size to 5
    `${GS}(k\x03\x00\x31\x45\x31`, // Set error correction level M (15%)
    `${GS}(k${pL}${pH}\x31\x50\x30${qrUri}`, // Store QR data
    `${GS}(k\x03\x00\x31\x51\x30`, // Print QR code
    `\nScan via EH Home App during setup\n\n`,
    `${GS}V\x41\x03` // Cut paper (feed 3 lines and partial cut)
  ];

  return commands.join('');
}
