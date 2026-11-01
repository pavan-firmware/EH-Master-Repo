"use strict";
/**
 * System Module Service
 * Business logic layer for operational diagnostics and system status.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.SystemService = void 0;
class SystemService {
    environment;
    constructor(environment) {
        this.environment = environment;
    }
    getSystemInfo() {
        return {
            service: 'eh-home-api',
            version: '1.0.0',
            nodeVersion: process.version,
            environment: this.environment,
            uptimeSeconds: Math.floor(process.uptime()),
            timestamp: new Date().toISOString(),
        };
    }
    echo(payload) {
        return {
            echo: payload.message,
            metadata: payload.metadata,
            receivedAt: new Date().toISOString(),
        };
    }
}
exports.SystemService = SystemService;
//# sourceMappingURL=system.service.js.map