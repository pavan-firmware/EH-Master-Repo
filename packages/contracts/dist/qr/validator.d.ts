import { PrintJobRequest, PrinterErrorCode } from './label';
import { CANONICAL_APPROVED_VARIANTS, CANONICAL_HARDWARE_REVISIONS, isCanonicalProductHardwareSupported } from '../product';
export { CANONICAL_APPROVED_VARIANTS, CANONICAL_HARDWARE_REVISIONS, isCanonicalProductHardwareSupported };
export declare const SUPPORTED_TEMPLATES: Set<string>;
export declare const SUPPORTED_PROTOCOLS: Set<string>;
export interface PrintValidationGateResult {
    valid: boolean;
    errorCode?: PrinterErrorCode;
    message: string;
    gateDetails: Array<{
        gate: string;
        passed: boolean;
        detail?: string;
    }>;
}
/**
 * Evaluates the 8 Mandatory Print Safety Gates before allowing label command generation or submission:
 *
 * Gate 1: DEVICE_RECORD_EXISTS (Valid deviceId UUID)
 * Gate 2: SERIAL_NUMBER_VALID (Matches SerialNumberSchema)
 * Gate 3: PRODUCT_VARIANT_CANONICAL (In approved product catalog)
 * Gate 4: HARDWARE_REVISION_VALID (Compound check: valid & supported by product variant)
 * Gate 5: QR_PAYLOAD_VALID (Matches canonical eh://p/v1?t= format)
 * Gate 6: TEMPLATE_SUPPORTED (In certified template list)
 * Gate 7: PRINTER_PROTOCOL_SUPPORTED (TSPL or ESCPOS)
 * Gate 8: ZERO_SECRET_CONTENT (Scans all fields for secret material)
 */
export declare function validatePrintJob(job: PrintJobRequest): PrintValidationGateResult;
//# sourceMappingURL=validator.d.ts.map