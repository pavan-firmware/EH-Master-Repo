"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SecurityRepository = void 0;
const contracts_1 = require("@eh-home/contracts");
class SecurityRepository {
    _db = null;
    static memoryPrincipals = new Map();
    static memoryDevices = new Map();
    static memoryHomeMemberships = new Map();
    constructor(app) {
        if (app && app.db) {
            this._db = app.db;
        }
    }
    seedPrincipal(principal) {
        const validated = contracts_1.PrincipalSchema.parse(principal);
        SecurityRepository.memoryPrincipals.set(validated.id, validated);
    }
    seedDevice(deviceId, resource) {
        SecurityRepository.memoryDevices.set(deviceId, resource);
    }
    seedHomeMembership(homeId, userId, role) {
        SecurityRepository.memoryHomeMemberships.set(`${homeId}:${userId}`, { homeId, userId, role });
    }
    async getPrincipal(id) {
        if (SecurityRepository.memoryPrincipals.has(id)) {
            return SecurityRepository.memoryPrincipals.get(id);
        }
        return null;
    }
    async getPrincipalByEmail(email) {
        for (const p of SecurityRepository.memoryPrincipals.values()) {
            if (p.email.toLowerCase() === email.toLowerCase()) {
                return p;
            }
        }
        return null;
    }
    async savePrincipal(principal) {
        const validated = contracts_1.PrincipalSchema.parse(principal);
        SecurityRepository.memoryPrincipals.set(validated.id, validated);
        return validated;
    }
    async updateUserRole(userId, role) {
        const principal = await this.getPrincipal(userId);
        if (!principal) {
            throw new Error(`Principal with ID '${userId}' not found`);
        }
        principal.role = role;
        SecurityRepository.memoryPrincipals.set(userId, principal);
        return principal;
    }
    async updateUserStatus(userId, status) {
        const principal = await this.getPrincipal(userId);
        if (!principal) {
            throw new Error(`Principal with ID '${userId}' not found`);
        }
        principal.status = status;
        SecurityRepository.memoryPrincipals.set(userId, principal);
        return principal;
    }
    async getDeviceOwnership(deviceId) {
        if (SecurityRepository.memoryDevices.has(deviceId)) {
            return SecurityRepository.memoryDevices.get(deviceId);
        }
        return null;
    }
    async getHomeMembership(userId, homeId) {
        const key = `${homeId}:${userId}`;
        if (SecurityRepository.memoryHomeMemberships.has(key)) {
            return SecurityRepository.memoryHomeMemberships.get(key);
        }
        return null;
    }
    async claimDevice(deviceId, userId, homeId, customName) {
        const existing = await this.getDeviceOwnership(deviceId);
        if (existing && existing.claimedByUserId) {
            throw new Error(`Device '${deviceId}' is already claimed by user '${existing.claimedByUserId}'`);
        }
        const updated = {
            deviceId,
            deviceClaimStatus: 'CLAIMED',
            claimedByUserId: userId,
            assignedHomeId: homeId,
            homeId
        };
        SecurityRepository.memoryDevices.set(deviceId, updated);
        return {
            deviceId,
            claimedByUserId: userId,
            homeId,
            customName: customName || 'Smart Switch',
            claimedAt: new Date().toISOString()
        };
    }
    async unclaimDevice(deviceId, userId) {
        const existing = await this.getDeviceOwnership(deviceId);
        if (!existing || !existing.claimedByUserId) {
            throw new Error(`Device '${deviceId}' is not currently claimed`);
        }
        if (existing.claimedByUserId !== userId) {
            throw new Error(`Security Violation: User '${userId}' is not the owner of device '${deviceId}'`);
        }
        const updated = {
            deviceId,
            deviceClaimStatus: 'UNCLAIMED',
            claimedByUserId: undefined,
            assignedHomeId: undefined,
            homeId: undefined
        };
        SecurityRepository.memoryDevices.set(deviceId, updated);
        return { deviceId, status: 'UNCLAIMED', unclaimedAt: new Date().toISOString() };
    }
    async transferDeviceOwnership(deviceId, fromUserId, toUserId, targetHomeId) {
        const existing = await this.getDeviceOwnership(deviceId);
        if (!existing || !existing.claimedByUserId) {
            throw new Error(`Device '${deviceId}' is not claimed`);
        }
        if (existing.claimedByUserId !== fromUserId) {
            throw new Error(`Security Violation: User '${fromUserId}' is not the owner of device '${deviceId}'`);
        }
        const updated = {
            deviceId,
            deviceClaimStatus: 'CLAIMED',
            claimedByUserId: toUserId,
            assignedHomeId: targetHomeId,
            homeId: targetHomeId
        };
        SecurityRepository.memoryDevices.set(deviceId, updated);
        return {
            deviceId,
            previousOwnerId: fromUserId,
            newOwnerId: toUserId,
            targetHomeId,
            transferredAt: new Date().toISOString()
        };
    }
    async revokeDevice(deviceId, reason) {
        const updated = {
            deviceId,
            deviceClaimStatus: 'REVOKED',
            claimedByUserId: undefined,
            assignedHomeId: undefined,
            homeId: undefined
        };
        SecurityRepository.memoryDevices.set(deviceId, updated);
        return { deviceId, status: 'REVOKED', reason, revokedAt: new Date().toISOString() };
    }
}
exports.SecurityRepository = SecurityRepository;
//# sourceMappingURL=security.repository.js.map