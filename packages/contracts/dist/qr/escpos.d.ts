import { LabelDataModel } from './label';
/**
 * Generates deterministic ESC/POS printer byte stream / string commands for receipt/slip printers.
 *
 * Scoping:
 * - TSPL is the primary device label protocol for adhesive thermal labels with gap sensing (e.g. TSC TE200).
 * - ESC/POS is the standard line/journal protocol for continuous paper receipt printers (e.g. Epson TM-T88, 58mm/80mm rolls).
 *
 * This generator formats a manufacturing bench traveler / quality slip.
 */
export declare function generateReceiptEscPos(data: LabelDataModel): string;
//# sourceMappingURL=escpos.d.ts.map