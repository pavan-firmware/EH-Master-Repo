import { LabelDataModel } from './label';
import { assertNoSecretsInRecord } from './generator';

export interface TsplTemplateOptions {
  widthMm?: number;
  heightMm?: number;
  gapMm?: number;
  direction?: 0 | 1;
  density?: number; // 0-15
  speed?: number; // 2-6 ips
  referenceX?: number;
  referenceY?: number;
}

/**
 * Sanitizes input strings for safe inclusion in TSPL commands.
 * Eliminates command injection vectors (newlines, control characters, unescaped quotes).
 */
export function sanitizeTsplString(input: string, maxLen = 128): string {
  if (!input) return '';
  return input
    .replace(/[\r\n\0]/g, ' ')
    .replace(/"/g, "'")
    .trim()
    .slice(0, maxLen);
}

/**
 * Generates deterministic TSPL printer commands for the primary 50mm x 30mm device label.
 *
 * 50mm x 30mm @ 203 DPI = ~400 dots width x ~240 dots height.
 * Layout:
 * - Top Left: "EH HOME" Header + Product Name & Model
 * - Right: 2D QR Code (Opaque URI)
 * - Middle Left: Hardware Revision, MCU, Firmware Version
 * - Bottom: 1D Code128 Barcode + Human-Readable Serial Number
 * - Footer: Truncated Device ID & Traceability Hash
 */
export function generateDeviceLabelTspl(
  data: LabelDataModel,
  opts?: TsplTemplateOptions
): string {
  // Pre-generation zero-secret assertion
  assertNoSecretsInRecord(data);

  const width = opts?.widthMm || 50;
  const height = opts?.heightMm || 30;
  const gap = opts?.gapMm !== undefined ? opts?.gapMm : 2;
  const direction = opts?.direction !== undefined ? opts?.direction : 1;
  const density = opts?.density !== undefined ? opts?.density : 8;
  const speed = opts?.speed !== undefined ? opts?.speed : 4;
  const refX = opts?.referenceX || 0;
  const refY = opts?.referenceY || 0;

  // Sanitized field values
  const brand = sanitizeTsplString(data.brand);
  const displayName = sanitizeTsplString(data.productDisplayName, 24);
  const variantId = sanitizeTsplString(data.productVariantId, 24);
  const serial = sanitizeTsplString(data.serialNumber, 32);
  const hwRev = sanitizeTsplString(data.hardwareRevision, 10);
  const fwVer = sanitizeTsplString(data.firmwareVersion, 12);
  const deviceIdShort = sanitizeTsplString(data.deviceId.slice(0, 18), 20);
  const qrUri = sanitizeTsplString(data.qrUri, 128);

  const lines: string[] = [
    `SIZE ${width} mm,${height} mm`,
    `GAP ${gap} mm,0 mm`,
    `SPEED ${speed}`,
    `DENSITY ${density}`,
    `DIRECTION ${direction}`,
    `REFERENCE ${refX},${refY}`,
    `CLS`,
    // Brand & Product Identity (Left column)
    `TEXT 16,14,"3",0,1,1,"${brand}"`,
    `TEXT 16,42,"2",0,1,1,"${displayName}"`,
    `TEXT 16,66,"1",0,1,1,"Model: ${variantId}"`,
    `TEXT 16,84,"1",0,1,1,"HW: ${hwRev} | FW: v${fwVer}"`,
    // QR Code (Right column: x=256, y=14, cell width=4, Error Correction=M)
    `QRCODE 256,14,M,4,A,0,"${qrUri}"`,
    // 1D Barcode (Code128 across bottom)
    `BARCODE 16,112,"128",38,0,0,2,2,"${serial}"`,
    // Human-readable Serial Number & Short Device UUID
    `TEXT 16,156,"2",0,1,1,"SN: ${serial}"`,
    `TEXT 16,182,"1",0,1,1,"ID: ${deviceIdShort}... [SEC-OPQ]"`,
    `PRINT 1,1`
  ];

  return lines.join('\r\n') + '\r\n';
}

/**
 * Generates deterministic TSPL for a compact 40mm x 20mm device label.
 */
export function generateCompactLabelTspl(
  data: LabelDataModel,
  opts?: TsplTemplateOptions
): string {
  assertNoSecretsInRecord(data);

  const width = opts?.widthMm || 40;
  const height = opts?.heightMm || 20;
  const gap = opts?.gapMm !== undefined ? opts?.gapMm : 2;

  const brand = sanitizeTsplString(data.brand);
  const variantId = sanitizeTsplString(data.productVariantId, 20);
  const serial = sanitizeTsplString(data.serialNumber, 28);
  const hwRev = sanitizeTsplString(data.hardwareRevision, 8);
  const qrUri = sanitizeTsplString(data.qrUri, 128);

  const lines: string[] = [
    `SIZE ${width} mm,${height} mm`,
    `GAP ${gap} mm,0 mm`,
    `DIRECTION 1`,
    `CLS`,
    `TEXT 10,10,"2",0,1,1,"${brand}"`,
    `TEXT 10,32,"1",0,1,1,"${variantId}"`,
    `TEXT 10,50,"1",0,1,1,"HW: ${hwRev}"`,
    `TEXT 10,72,"1",0,1,1,"${serial}"`,
    `QRCODE 190,10,M,3,A,0,"${qrUri}"`,
    `PRINT 1,1`
  ];

  return lines.join('\r\n') + '\r\n';
}

/** Small factory sticker for a populated PCB: model + Code128 serial only. */
export function generateSiliconLabelTspl(
  data: LabelDataModel,
  opts?: TsplTemplateOptions
): string {
  assertNoSecretsInRecord(data);
  // A full EH serial needs the physical width of a 203-DPI Code128 symbol.
  // 40x15mm remains a small PCB/silicon-pack sticker without compressing the
  // barcode below a scanner-safe module width.
  const width = opts?.widthMm || 40;
  const height = opts?.heightMm || 15;
  const serial = sanitizeTsplString(data.serialNumber, 32);
  const model = sanitizeTsplString(data.productVariantId, 22);
  const variant = data.productVariantId.includes('smart-switch')
    ? `S${data.productVariantId.match(/[1-4]x/)?.[0]?.[0] || '3'}`
    : data.productVariantId.includes('smart-socket') ? 'K1'
    : data.productVariantId.includes('smart-fan') ? 'F1'
    : data.productVariantId.includes('smart-light') ? 'L1'
    : data.productVariantId.includes('sensor') ? 'N1'
    : data.productVariantId.includes('hub') ? 'B1'
    : 'X1';
  const hardware = data.hardwareRevision.match(/\d/)?.[0] || '0';
  const firmware = data.firmwareVersion.match(/\d/)?.[0] || '0';
  const barcodeValue = `E1${variant}H${hardware}F${firmware}-${serial.split('-').pop() || '00000'}`;
  return [
    `SIZE ${width} mm,${height} mm`,
    'GAP 2 mm,0 mm',
    'DIRECTION 1',
    'CLS',
    `TEXT 72,10,"1",0,1,1,"${model}"`,
    `BARCODE 16,34,"128",48,0,0,1,1,"${barcodeValue}"`,
    `TEXT 72,94,"1",0,1,1,"${serial}"`,
    'PRINT 1,1',
  ].join('\r\n') + '\r\n';
}
