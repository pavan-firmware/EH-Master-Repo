import { LabelDataModel } from './label';
export interface TsplTemplateOptions {
    widthMm?: number;
    heightMm?: number;
    gapMm?: number;
    direction?: 0 | 1;
    density?: number;
    speed?: number;
    referenceX?: number;
    referenceY?: number;
}
/**
 * Sanitizes input strings for safe inclusion in TSPL commands.
 * Eliminates command injection vectors (newlines, control characters, unescaped quotes).
 */
export declare function sanitizeTsplString(input: string, maxLen?: number): string;
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
export declare function generateDeviceLabelTspl(data: LabelDataModel, opts?: TsplTemplateOptions): string;
/**
 * Generates deterministic TSPL for a compact 40mm x 20mm device label.
 */
export declare function generateCompactLabelTspl(data: LabelDataModel, opts?: TsplTemplateOptions): string;
/** Small factory sticker for a populated PCB: model + Code128 serial only. */
export declare function generateSiliconLabelTspl(data: LabelDataModel, opts?: TsplTemplateOptions): string;
//# sourceMappingURL=tspl.d.ts.map