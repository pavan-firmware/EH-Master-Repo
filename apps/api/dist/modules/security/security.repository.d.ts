import { Principal, UserRole, HomeRole, PrincipalStatus, ResourceContext } from '@eh-home/contracts';
import { FastifyInstance } from 'fastify';
export interface ISecurityRepository {
    getPrincipal(id: string): Promise<Principal | null>;
    getPrincipalByEmail(email: string): Promise<Principal | null>;
    savePrincipal(principal: Principal): Promise<Principal>;
    updateUserRole(userId: string, role: UserRole): Promise<Principal>;
    updateUserStatus(userId: string, status: PrincipalStatus): Promise<Principal>;
    getDeviceOwnership(deviceId: string): Promise<ResourceContext | null>;
    getHomeMembership(userId: string, homeId: string): Promise<{
        homeId: string;
        userId: string;
        role: HomeRole;
    } | null>;
    claimDevice(deviceId: string, userId: string, homeId: string, customName?: string): Promise<any>;
    unclaimDevice(deviceId: string, userId: string): Promise<any>;
    transferDeviceOwnership(deviceId: string, fromUserId: string, toUserId: string, targetHomeId: string): Promise<any>;
    revokeDevice(deviceId: string, reason: string): Promise<any>;
}
export declare class SecurityRepository implements ISecurityRepository {
    protected _db: any;
    private static memoryPrincipals;
    private static memoryDevices;
    private static memoryHomeMemberships;
    constructor(app?: FastifyInstance);
    seedPrincipal(principal: Principal): void;
    seedDevice(deviceId: string, resource: ResourceContext): void;
    seedHomeMembership(homeId: string, userId: string, role: HomeRole): void;
    getPrincipal(id: string): Promise<Principal | null>;
    getPrincipalByEmail(email: string): Promise<Principal | null>;
    savePrincipal(principal: Principal): Promise<Principal>;
    updateUserRole(userId: string, role: UserRole): Promise<Principal>;
    updateUserStatus(userId: string, status: PrincipalStatus): Promise<Principal>;
    getDeviceOwnership(deviceId: string): Promise<ResourceContext | null>;
    getHomeMembership(userId: string, homeId: string): Promise<{
        homeId: string;
        userId: string;
        role: HomeRole;
    } | null>;
    claimDevice(deviceId: string, userId: string, homeId: string, customName?: string): Promise<any>;
    unclaimDevice(deviceId: string, userId: string): Promise<any>;
    transferDeviceOwnership(deviceId: string, fromUserId: string, toUserId: string, targetHomeId: string): Promise<any>;
    revokeDevice(deviceId: string, reason: string): Promise<any>;
}
//# sourceMappingURL=security.repository.d.ts.map