import { z } from 'zod';
export declare const ProductionBatchStatusSchema: z.ZodEnum<["PLANNED", "IN_PRODUCTION", "QC_IN_PROGRESS", "COMPLETED", "CANCELLED"]>;
export type ProductionBatchStatus = z.infer<typeof ProductionBatchStatusSchema>;
export declare const ProductionBatchSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    batchId: z.ZodString;
    batchCode: z.ZodString;
    productVariantId: z.ZodString;
    hardwareRevisionCode: z.ZodString;
    firmwareReleaseId: z.ZodString;
    targetQuantity: z.ZodNumber;
    manufacturedCount: z.ZodDefault<z.ZodNumber>;
    passedQcCount: z.ZodDefault<z.ZodNumber>;
    failedQcCount: z.ZodDefault<z.ZodNumber>;
    status: z.ZodDefault<z.ZodEnum<["PLANNED", "IN_PRODUCTION", "QC_IN_PROGRESS", "COMPLETED", "CANCELLED"]>>;
    operatorUserId: z.ZodOptional<z.ZodString>;
    notes: z.ZodOptional<z.ZodString>;
    scheduledStartDate: z.ZodOptional<z.ZodString>;
    completedAt: z.ZodOptional<z.ZodString>;
    createdAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    status: "PLANNED" | "IN_PRODUCTION" | "QC_IN_PROGRESS" | "COMPLETED" | "CANCELLED";
    schemaVersion: number;
    hardwareRevisionCode: string;
    createdAt: string;
    productVariantId: string;
    firmwareReleaseId: string;
    batchId: string;
    batchCode: string;
    targetQuantity: number;
    manufacturedCount: number;
    passedQcCount: number;
    failedQcCount: number;
    notes?: string | undefined;
    operatorUserId?: string | undefined;
    scheduledStartDate?: string | undefined;
    completedAt?: string | undefined;
}, {
    hardwareRevisionCode: string;
    createdAt: string;
    productVariantId: string;
    firmwareReleaseId: string;
    batchId: string;
    batchCode: string;
    targetQuantity: number;
    status?: "PLANNED" | "IN_PRODUCTION" | "QC_IN_PROGRESS" | "COMPLETED" | "CANCELLED" | undefined;
    schemaVersion?: number | undefined;
    notes?: string | undefined;
    manufacturedCount?: number | undefined;
    passedQcCount?: number | undefined;
    failedQcCount?: number | undefined;
    operatorUserId?: string | undefined;
    scheduledStartDate?: string | undefined;
    completedAt?: string | undefined;
}>;
export type ProductionBatch = z.infer<typeof ProductionBatchSchema>;
export declare const BatchDeviceAssociationSchema: z.ZodObject<{
    batchId: z.ZodString;
    deviceId: z.ZodString;
    serialNumber: z.ZodString;
    assignedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    deviceId: string;
    serialNumber: string;
    batchId: string;
    assignedAt: string;
}, {
    deviceId: string;
    serialNumber: string;
    batchId: string;
    assignedAt: string;
}>;
export type BatchDeviceAssociation = z.infer<typeof BatchDeviceAssociationSchema>;
export declare const QcMeasurementSchema: z.ZodObject<{
    parameter: z.ZodString;
    measuredValue: z.ZodNumber;
    unit: z.ZodString;
    lowerLimit: z.ZodOptional<z.ZodNumber>;
    upperLimit: z.ZodOptional<z.ZodNumber>;
    passed: z.ZodBoolean;
}, "strip", z.ZodTypeAny, {
    passed: boolean;
    parameter: string;
    measuredValue: number;
    unit: string;
    lowerLimit?: number | undefined;
    upperLimit?: number | undefined;
}, {
    passed: boolean;
    parameter: string;
    measuredValue: number;
    unit: string;
    lowerLimit?: number | undefined;
    upperLimit?: number | undefined;
}>;
export type QcMeasurement = z.infer<typeof QcMeasurementSchema>;
export declare const QcTestLogSchema: z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    testLogId: z.ZodString;
    deviceId: z.ZodString;
    serialNumber: z.ZodString;
    batchId: z.ZodString;
    testStationId: z.ZodString;
    operatorUserId: z.ZodOptional<z.ZodString>;
    overallResult: z.ZodEnum<["PASS", "FAIL"]>;
    measurements: z.ZodDefault<z.ZodArray<z.ZodObject<{
        parameter: z.ZodString;
        measuredValue: z.ZodNumber;
        unit: z.ZodString;
        lowerLimit: z.ZodOptional<z.ZodNumber>;
        upperLimit: z.ZodOptional<z.ZodNumber>;
        passed: z.ZodBoolean;
    }, "strip", z.ZodTypeAny, {
        passed: boolean;
        parameter: string;
        measuredValue: number;
        unit: string;
        lowerLimit?: number | undefined;
        upperLimit?: number | undefined;
    }, {
        passed: boolean;
        parameter: string;
        measuredValue: number;
        unit: string;
        lowerLimit?: number | undefined;
        upperLimit?: number | undefined;
    }>, "many">>;
    failureReason: z.ZodOptional<z.ZodString>;
    testedAt: z.ZodString;
}, "strip", z.ZodTypeAny, {
    schemaVersion: number;
    deviceId: string;
    serialNumber: string;
    batchId: string;
    testLogId: string;
    testStationId: string;
    overallResult: "PASS" | "FAIL";
    measurements: {
        passed: boolean;
        parameter: string;
        measuredValue: number;
        unit: string;
        lowerLimit?: number | undefined;
        upperLimit?: number | undefined;
    }[];
    testedAt: string;
    operatorUserId?: string | undefined;
    failureReason?: string | undefined;
}, {
    deviceId: string;
    serialNumber: string;
    batchId: string;
    testLogId: string;
    testStationId: string;
    overallResult: "PASS" | "FAIL";
    testedAt: string;
    schemaVersion?: number | undefined;
    operatorUserId?: string | undefined;
    measurements?: {
        passed: boolean;
        parameter: string;
        measuredValue: number;
        unit: string;
        lowerLimit?: number | undefined;
        upperLimit?: number | undefined;
    }[] | undefined;
    failureReason?: string | undefined;
}>;
export type QcTestLog = z.infer<typeof QcTestLogSchema>;
//# sourceMappingURL=index.d.ts.map