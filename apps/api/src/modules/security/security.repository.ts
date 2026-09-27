import {
  Principal,
  PrincipalSchema,
  UserRole,
  HomeRole,
  PrincipalStatus,
  ResourceContext
} from '@eh-home/contracts';
import { FastifyInstance } from 'fastify';

export interface ISecurityRepository {
  getPrincipal(id: string): Promise<Principal | null>;
  getPrincipalByEmail(email: string): Promise<Principal | null>;
  savePrincipal(principal: Principal): Promise<Principal>;
  updateUserRole(userId: string, role: UserRole): Promise<Principal>;
  updateUserStatus(userId: string, status: PrincipalStatus): Promise<Principal>;
  getDeviceOwnership(deviceId: string): Promise<ResourceContext | null>;
  getHomeMembership(userId: string, homeId: string): Promise<{ homeId: string; userId: string; role: HomeRole } | null>;
  claimDevice(deviceId: string, userId: string, homeId: string, customName?: string): Promise<any>;
  unclaimDevice(deviceId: string, userId: string): Promise<any>;
  transferDeviceOwnership(deviceId: string, fromUserId: string, toUserId: string, targetHomeId: string): Promise<any>;
  revokeDevice(deviceId: string, reason: string): Promise<any>;
}

export class SecurityRepository implements ISecurityRepository {
  protected _db: any = null;
  private static memoryPrincipals: Map<string, Principal> = new Map();
  private static memoryDevices: Map<string, ResourceContext> = new Map();
  private static memoryHomeMemberships: Map<string, { homeId: string; userId: string; role: HomeRole }> = new Map();

  constructor(app?: FastifyInstance) {
    if (app && (app as any).db) {
      this._db = (app as any).db;
    }
  }

  public seedPrincipal(principal: Principal): void {
    const validated = PrincipalSchema.parse(principal);
    SecurityRepository.memoryPrincipals.set(validated.id, validated);
  }

  public seedDevice(deviceId: string, resource: ResourceContext): void {
    SecurityRepository.memoryDevices.set(deviceId, resource);
  }

  public seedHomeMembership(homeId: string, userId: string, role: HomeRole): void {
    SecurityRepository.memoryHomeMemberships.set(`${homeId}:${userId}`, { homeId, userId, role });
  }

  public async getPrincipal(id: string): Promise<Principal | null> {
    if (SecurityRepository.memoryPrincipals.has(id)) {
      return SecurityRepository.memoryPrincipals.get(id)!;
    }
    return null;
  }

  public async getPrincipalByEmail(email: string): Promise<Principal | null> {
    for (const p of SecurityRepository.memoryPrincipals.values()) {
      if (p.email.toLowerCase() === email.toLowerCase()) {
        return p;
      }
    }
    return null;
  }

  public async savePrincipal(principal: Principal): Promise<Principal> {
    const validated = PrincipalSchema.parse(principal);
    SecurityRepository.memoryPrincipals.set(validated.id, validated);
    return validated;
  }

  public async updateUserRole(userId: string, role: UserRole): Promise<Principal> {
    const principal = await this.getPrincipal(userId);
    if (!principal) {
      throw new Error(`Principal with ID '${userId}' not found`);
    }
    principal.role = role;
    SecurityRepository.memoryPrincipals.set(userId, principal);
    return principal;
  }

  public async updateUserStatus(userId: string, status: PrincipalStatus): Promise<Principal> {
    const principal = await this.getPrincipal(userId);
    if (!principal) {
      throw new Error(`Principal with ID '${userId}' not found`);
    }
    principal.status = status;
    SecurityRepository.memoryPrincipals.set(userId, principal);
    return principal;
  }

  public async getDeviceOwnership(deviceId: string): Promise<ResourceContext | null> {
    if (SecurityRepository.memoryDevices.has(deviceId)) {
      return SecurityRepository.memoryDevices.get(deviceId)!;
    }
    return null;
  }

  public async getHomeMembership(userId: string, homeId: string): Promise<{ homeId: string; userId: string; role: HomeRole } | null> {
    const key = `${homeId}:${userId}`;
    if (SecurityRepository.memoryHomeMemberships.has(key)) {
      return SecurityRepository.memoryHomeMemberships.get(key)!;
    }
    return null;
  }

  public async claimDevice(deviceId: string, userId: string, homeId: string, customName?: string): Promise<any> {
    const existing = await this.getDeviceOwnership(deviceId);
    if (existing && existing.claimedByUserId) {
      throw new Error(`Device '${deviceId}' is already claimed by user '${existing.claimedByUserId}'`);
    }

    const updated: ResourceContext = {
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

  public async unclaimDevice(deviceId: string, userId: string): Promise<any> {
    const existing = await this.getDeviceOwnership(deviceId);
    if (!existing || !existing.claimedByUserId) {
      throw new Error(`Device '${deviceId}' is not currently claimed`);
    }
    if (existing.claimedByUserId !== userId) {
      throw new Error(`Security Violation: User '${userId}' is not the owner of device '${deviceId}'`);
    }

    const updated: ResourceContext = {
      deviceId,
      deviceClaimStatus: 'UNCLAIMED',
      claimedByUserId: undefined,
      assignedHomeId: undefined,
      homeId: undefined
    };
    SecurityRepository.memoryDevices.set(deviceId, updated);
    return { deviceId, status: 'UNCLAIMED', unclaimedAt: new Date().toISOString() };
  }

  public async transferDeviceOwnership(
    deviceId: string,
    fromUserId: string,
    toUserId: string,
    targetHomeId: string
  ): Promise<any> {
    const existing = await this.getDeviceOwnership(deviceId);
    if (!existing || !existing.claimedByUserId) {
      throw new Error(`Device '${deviceId}' is not claimed`);
    }
    if (existing.claimedByUserId !== fromUserId) {
      throw new Error(`Security Violation: User '${fromUserId}' is not the owner of device '${deviceId}'`);
    }

    const updated: ResourceContext = {
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

  public async revokeDevice(deviceId: string, reason: string): Promise<any> {
    const updated: ResourceContext = {
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
