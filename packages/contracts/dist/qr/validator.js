"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SUPPORTED_PROTOCOLS = exports.SUPPORTED_TEMPLATES = exports.isCanonicalProductHardwareSupported = exports.CANONICAL_HARDWARE_REVISIONS = exports.CANONICAL_APPROVED_VARIANTS = void 0;
exports.validatePrintJob = validatePrintJob;
const base_1 = require("./base");
const generator_1 = require("./generator");
const common_1 = require("../common");
const product_1 = require("../product");
Object.defineProperty(exports, "CANONICAL_APPROVED_VARIANTS", { enumerable: true, get: function () { return product_1.CANONICAL_APPROVED_VARIANTS; } });
Object.defineProperty(exports, "CANONICAL_HARDWARE_REVISIONS", { enumerable: true, get: function () { return product_1.CANONICAL_HARDWARE_REVISIONS; } });
Object.defineProperty(exports, "isCanonicalProductHardwareSupported", { enumerable: true, get: function () { return product_1.isCanonicalProductHardwareSupported; } });
exports.SUPPORTED_TEMPLATES = new Set([
    'device-primary-50x30-v1',
    'device-compact-40x20-v1',
    'device-silicon-25x10-v1',
    'box-receipt-escpos-v1',
]);
exports.SUPPORTED_PROTOCOLS = new Set(['TSPL', 'ESCPOS']);
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
function validatePrintJob(job) {
    const gates = [];
    const label = job.labelData;
    // Gate 1: Device Record Exists
    const uuidRegex = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
    if (!label.deviceId || !uuidRegex.test(label.deviceId)) {
        gates.push({ gate: 'DEVICE_RECORD_EXISTS', passed: false, detail: 'Invalid or missing deviceId UUID' });
        return {
            valid: false,
            errorCode: 'INVALID_LABEL_DATA',
            message: 'Print Gate 1 Failed: Device record ID must be a valid UUID.',
            gateDetails: gates,
        };
    }
    gates.push({ gate: 'DEVICE_RECORD_EXISTS', passed: true, detail: `DeviceId '${label.deviceId}' valid.` });
    // Gate 2: Serial Number Valid
    const serialRegex = /^EH-[A-Z0-9]+-\d{4}W\d{2}-\d{5}$/;
    if (!label.serialNumber || !serialRegex.test(label.serialNumber)) {
        gates.push({ gate: 'SERIAL_NUMBER_VALID', passed: false, detail: `Malformed serial '${label.serialNumber}'` });
        return {
            valid: false,
            errorCode: 'INVALID_LABEL_DATA',
            message: `Print Gate 2 Failed: Serial number '${label.serialNumber}' is invalid.`,
            gateDetails: gates,
        };
    }
    gates.push({ gate: 'SERIAL_NUMBER_VALID', passed: true, detail: `Serial '${label.serialNumber}' valid.` });
    // Gate 3: Product Variant Canonical
    if (!product_1.CANONICAL_APPROVED_VARIANTS.has(label.productVariantId)) {
        gates.push({ gate: 'PRODUCT_VARIANT_CANONICAL', passed: false, detail: `Unapproved variant '${label.productVariantId}'` });
        return {
            valid: false,
            errorCode: 'INVALID_LABEL_DATA',
            message: `Print Gate 3 Failed: Product variant '${label.productVariantId}' is not canonical.`,
            gateDetails: gates,
        };
    }
    gates.push({ gate: 'PRODUCT_VARIANT_CANONICAL', passed: true, detail: `Variant '${label.productVariantId}' canonical.` });
    // Gate 4: Hardware Revision Valid & Compatible with Product Variant (Compound Check)
    const hwParse = common_1.HardwareRevisionCodeSchema.safeParse(label.hardwareRevision);
    if (!hwParse.success || !(0, product_1.isCanonicalProductHardwareSupported)(label.productVariantId, label.hardwareRevision)) {
        gates.push({
            gate: 'HARDWARE_REVISION_VALID',
            passed: false,
            detail: `Hardware revision '${label.hardwareRevision}' is invalid or incompatible with product variant '${label.productVariantId}'.`,
        });
        return {
            valid: false,
            errorCode: 'INVALID_LABEL_DATA',
            message: `Print Gate 4 Failed: Hardware revision '${label.hardwareRevision}' is not compatible with product variant '${label.productVariantId}'.`,
            gateDetails: gates,
        };
    }
    gates.push({
        gate: 'HARDWARE_REVISION_VALID',
        passed: true,
        detail: `Hardware revision '${label.hardwareRevision}' is valid and compatible with '${label.productVariantId}'.`,
    });
    // Gate 5: QR Payload Valid
    const qrParse = base_1.QrUriSchema.safeParse(label.qrUri);
    if (!qrParse.success) {
        gates.push({ gate: 'QR_PAYLOAD_VALID', passed: false, detail: `Invalid QR URI format: ${qrParse.error.message}` });
        return {
            valid: false,
            errorCode: 'INVALID_QR_PAYLOAD',
            message: 'Print Gate 5 Failed: QR URI does not follow canonical eh://p/v1?t=<token> schema.',
            gateDetails: gates,
        };
    }
    gates.push({ gate: 'QR_PAYLOAD_VALID', passed: true, detail: 'Canonical opaque QR URI verified.' });
    // Gate 6: Label Template Supported
    const template = job.templateId || label.templateId;
    if (!exports.SUPPORTED_TEMPLATES.has(template)) {
        gates.push({ gate: 'TEMPLATE_SUPPORTED', passed: false, detail: `Unsupported template '${template}'` });
        return {
            valid: false,
            errorCode: 'TEMPLATE_NOT_FOUND',
            message: `Print Gate 6 Failed: Label template '${template}' is not supported.`,
            gateDetails: gates,
        };
    }
    gates.push({ gate: 'TEMPLATE_SUPPORTED', passed: true, detail: `Template '${template}' supported.` });
    // Gate 7: Printer Protocol Supported
    if (!exports.SUPPORTED_PROTOCOLS.has(job.protocol)) {
        gates.push({ gate: 'PRINTER_PROTOCOL_SUPPORTED', passed: false, detail: `Unsupported protocol '${job.protocol}'` });
        return {
            valid: false,
            errorCode: 'UNSUPPORTED_PRINTER_PROTOCOL',
            message: `Print Gate 7 Failed: Printer protocol '${job.protocol}' is unsupported.`,
            gateDetails: gates,
        };
    }
    gates.push({ gate: 'PRINTER_PROTOCOL_SUPPORTED', passed: true, detail: `Protocol '${job.protocol}' supported.` });
    // Gate 8: Zero Secret Content
    const fieldsToScan = [
        label.brand,
        label.productDisplayName,
        label.productVariantId,
        label.productFamily,
        label.hardwareRevision,
        label.serialNumber,
        label.deviceId,
        label.qrUri,
        label.qrToken,
        label.firmwareFamily,
        label.firmwareVersion,
        label.traceId || '',
        label.batchId || '',
    ];
    for (const field of fieldsToScan) {
        if ((0, generator_1.containsSecretMaterial)(field)) {
            gates.push({ gate: 'ZERO_SECRET_CONTENT', passed: false, detail: 'Prohibited secret material pattern detected in label field.' });
            return {
                valid: false,
                errorCode: 'SECRET_DATA_DETECTED',
                message: 'Print Gate 8 Failed: Secret data detected in printable fields. Printing strictly prohibited.',
                gateDetails: gates,
            };
        }
    }
    gates.push({ gate: 'ZERO_SECRET_CONTENT', passed: true, detail: 'Zero secret leakage verified.' });
    return {
        valid: true,
        message: 'All 8 Print Safety Gates passed successfully. Safe to print.',
        gateDetails: gates,
    };
}
//# sourceMappingURL=validator.js.map