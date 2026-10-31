import { z } from 'zod';
export declare const SchemaVersionSchema: z.ZodDefault<z.ZodNumber>;
export declare const UuidSchema: z.ZodString;
export declare const IsoTimestampSchema: z.ZodString;
export declare const IsoDateTimeSchema: z.ZodString;
export declare const SemanticVersionSchema: z.ZodString;
export declare const HardwareRevisionCodeSchema: z.ZodString;
export declare const MacAddressSchema: z.ZodString;
export declare const SerialNumberSchema: z.ZodString;
export declare const PaginationQuerySchema: z.ZodObject<{
    page: z.ZodDefault<z.ZodNumber>;
    limit: z.ZodDefault<z.ZodNumber>;
    cursor: z.ZodOptional<z.ZodString>;
}, "strip", z.ZodTypeAny, {
    page: number;
    limit: number;
    cursor?: string | undefined;
}, {
    page?: number | undefined;
    limit?: number | undefined;
    cursor?: string | undefined;
}>;
export type PaginationQuery = z.infer<typeof PaginationQuerySchema>;
export declare const ApiEnvelopeSchema: <T extends z.ZodTypeAny>(dataSchema: T) => z.ZodObject<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    success: z.ZodBoolean;
    data: z.ZodOptional<T>;
    error: z.ZodOptional<z.ZodObject<{
        code: z.ZodString;
        message: z.ZodString;
        details: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    }, "strip", z.ZodTypeAny, {
        message: string;
        code: string;
        details?: Record<string, unknown> | undefined;
    }, {
        message: string;
        code: string;
        details?: Record<string, unknown> | undefined;
    }>>;
    meta: z.ZodOptional<z.ZodObject<{
        requestId: z.ZodOptional<z.ZodString>;
        timestamp: z.ZodDefault<z.ZodString>;
        pagination: z.ZodOptional<z.ZodObject<{
            total: z.ZodNumber;
            page: z.ZodNumber;
            limit: z.ZodNumber;
            hasMore: z.ZodBoolean;
        }, "strip", z.ZodTypeAny, {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        }, {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        }>>;
    }, "strip", z.ZodTypeAny, {
        timestamp: string;
        requestId?: string | undefined;
        pagination?: {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        } | undefined;
    }, {
        requestId?: string | undefined;
        timestamp?: string | undefined;
        pagination?: {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        } | undefined;
    }>>;
}, "strip", z.ZodTypeAny, z.objectUtil.addQuestionMarks<z.baseObjectOutputType<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    success: z.ZodBoolean;
    data: z.ZodOptional<T>;
    error: z.ZodOptional<z.ZodObject<{
        code: z.ZodString;
        message: z.ZodString;
        details: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    }, "strip", z.ZodTypeAny, {
        message: string;
        code: string;
        details?: Record<string, unknown> | undefined;
    }, {
        message: string;
        code: string;
        details?: Record<string, unknown> | undefined;
    }>>;
    meta: z.ZodOptional<z.ZodObject<{
        requestId: z.ZodOptional<z.ZodString>;
        timestamp: z.ZodDefault<z.ZodString>;
        pagination: z.ZodOptional<z.ZodObject<{
            total: z.ZodNumber;
            page: z.ZodNumber;
            limit: z.ZodNumber;
            hasMore: z.ZodBoolean;
        }, "strip", z.ZodTypeAny, {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        }, {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        }>>;
    }, "strip", z.ZodTypeAny, {
        timestamp: string;
        requestId?: string | undefined;
        pagination?: {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        } | undefined;
    }, {
        requestId?: string | undefined;
        timestamp?: string | undefined;
        pagination?: {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        } | undefined;
    }>>;
}>, any> extends infer T_1 ? { [k in keyof T_1]: T_1[k]; } : never, z.baseObjectInputType<{
    schemaVersion: z.ZodDefault<z.ZodNumber>;
    success: z.ZodBoolean;
    data: z.ZodOptional<T>;
    error: z.ZodOptional<z.ZodObject<{
        code: z.ZodString;
        message: z.ZodString;
        details: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodUnknown>>;
    }, "strip", z.ZodTypeAny, {
        message: string;
        code: string;
        details?: Record<string, unknown> | undefined;
    }, {
        message: string;
        code: string;
        details?: Record<string, unknown> | undefined;
    }>>;
    meta: z.ZodOptional<z.ZodObject<{
        requestId: z.ZodOptional<z.ZodString>;
        timestamp: z.ZodDefault<z.ZodString>;
        pagination: z.ZodOptional<z.ZodObject<{
            total: z.ZodNumber;
            page: z.ZodNumber;
            limit: z.ZodNumber;
            hasMore: z.ZodBoolean;
        }, "strip", z.ZodTypeAny, {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        }, {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        }>>;
    }, "strip", z.ZodTypeAny, {
        timestamp: string;
        requestId?: string | undefined;
        pagination?: {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        } | undefined;
    }, {
        requestId?: string | undefined;
        timestamp?: string | undefined;
        pagination?: {
            page: number;
            limit: number;
            total: number;
            hasMore: boolean;
        } | undefined;
    }>>;
}> extends infer T_2 ? { [k_1 in keyof T_2]: T_2[k_1]; } : never>;
//# sourceMappingURL=index.d.ts.map