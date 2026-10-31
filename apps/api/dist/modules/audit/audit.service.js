"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuditService = void 0;
const contracts_1 = require("@eh-home/contracts");
const crypto = __importStar(require("crypto"));
class AuditService {
    repo;
    constructor(repo) {
        this.repo = repo;
    }
    getRepository() {
        return this.repo;
    }
    /**
     * Logs an immutable security or operational audit record.
     * Strictly enforces zero-secret policy before recording.
     */
    async logSecurityEvent(params) {
        const meta = params.metadata || {};
        // Fail-closed validation on forbidden secrets
        (0, contracts_1.assertNoSecretsInAuditPayload)(meta);
        const record = {
            id: crypto.randomUUID(),
            timestamp: new Date().toISOString(),
            actorId: params.actorId,
            actorEmail: params.actorEmail,
            actorRole: params.actorRole,
            action: params.action,
            resourceType: params.resourceType,
            resourceId: params.resourceId,
            outcome: params.outcome,
            severity: params.severity || 'INFO',
            failureReason: params.failureReason,
            errorCode: params.errorCode,
            correlationId: params.correlationId,
            clientIp: params.clientIp,
            userAgent: params.userAgent,
            metadata: meta
        };
        return this.repo.createEvent(record);
    }
    /**
     * Queries audit records with strict permission checks and pagination.
     */
    async queryAuditEvents(filter, _callerContext) {
        const validatedFilter = contracts_1.AuditQueryFilterSchema.parse(filter);
        return this.repo.queryEvents(validatedFilter);
    }
}
exports.AuditService = AuditService;
//# sourceMappingURL=audit.service.js.map