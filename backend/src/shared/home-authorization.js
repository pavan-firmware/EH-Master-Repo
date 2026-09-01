'use strict';

/**
 * EH Home — Home Membership & Capability-Aware Authorization Service (Phase 16)
 *
 * Enforces membership scoping and fine-grained permissions across all Home resources:
 *   - Homes, Settings, Memberships, Invitations, Ownership
 *   - Floors, Rooms, Devices, State, Commands
 *   - Scenes, Automations, Schedules, Execution
 *   - Notifications, History, Realtime SSE
 */

const ROLE_PERMISSIONS = {
  OWNER: {
    canManageHome: true,
    canDeleteHome: true,
    canManageMembers: true,
    canTransferOwnership: true,
    canManageDevices: true,
    canControlDevices: true,
    canManageAutomations: true,
    canExecuteAutomations: true,
    canViewHome: true
  },
  ADMIN: {
    canManageHome: true,
    canDeleteHome: false,
    canManageMembers: true,
    canTransferOwnership: false,
    canManageDevices: true,
    canControlDevices: true,
    canManageAutomations: true,
    canExecuteAutomations: true,
    canViewHome: true
  },
  MEMBER: {
    canManageHome: false,
    canDeleteHome: false,
    canManageMembers: false,
    canTransferOwnership: false,
    canManageDevices: false,
    canControlDevices: true,
    canManageAutomations: false,
    canExecuteAutomations: true,
    canViewHome: true
  },
  GUEST: {
    canManageHome: false,
    canDeleteHome: false,
    canManageMembers: false,
    canTransferOwnership: false,
    canManageDevices: false,
    canControlDevices: false,
    canManageAutomations: false,
    canExecuteAutomations: false,
    canViewHome: true
  },
  VIEWER: {
    canManageHome: false,
    canDeleteHome: false,
    canManageMembers: false,
    canTransferOwnership: false,
    canManageDevices: false,
    canControlDevices: false,
    canManageAutomations: false,
    canExecuteAutomations: false,
    canViewHome: true
  }
};

class HomeAuthorizationService {
  constructor({ homeRepo, deviceRepo, roomRepo }) {
    this.homeRepo = homeRepo;
    this.deviceRepo = deviceRepo;
    this.roomRepo = roomRepo;
  }

  getPermissionsForRole(role) {
    const normalized = (role || 'VIEWER').toUpperCase();
    return ROLE_PERMISSIONS[normalized] || ROLE_PERMISSIONS.VIEWER;
  }

  canManageHome(role) {
    return Boolean(this.getPermissionsForRole(role).canManageHome);
  }

  canManageDevices(role) {
    return Boolean(this.getPermissionsForRole(role).canManageDevices);
  }

  canControlDevices(role) {
    return Boolean(this.getPermissionsForRole(role).canControlDevices);
  }

  canManageAutomations(role) {
    return Boolean(this.getPermissionsForRole(role).canManageAutomations);
  }

  canManageMembers(role) {
    return Boolean(this.getPermissionsForRole(role).canManageMembers);
  }

  canDeleteHome(role) {
    return Boolean(this.getPermissionsForRole(role).canDeleteHome);
  }

  /**
   * Check if a user is a member of the specified home with optional role or capability restriction.
   */
  async checkHomeMembership(userId, homeId, allowedRoles = null, requiredCapability = null) {
    if (!userId || !homeId) return { isAuthorized: false, reason: 'Missing userId or homeId' };

    if (typeof userId === 'string' && userId.startsWith('system_')) {
      return {
        isAuthorized: true,
        role: 'SYSTEM',
        permissions: this.getPermissionsForRole('OWNER')
      };
    }

    const memberships = await this.homeRepo.getMembershipsForUser(userId);
    const membership = memberships.find(m => m.home_id === homeId);

    if (!membership) {
      return { isAuthorized: false, reason: `User ${userId} is not a member of home ${homeId}` };
    }

    const role = (membership.role || 'MEMBER').toUpperCase();
    const permissions = this.getPermissionsForRole(role);

    if (allowedRoles && Array.isArray(allowedRoles) && allowedRoles.length > 0) {
      const normalizedAllowed = allowedRoles.map(r => r.toUpperCase());
      if (!normalizedAllowed.includes(role)) {
        return {
          isAuthorized: false,
          reason: `User ${userId} role '${role}' is not allowed (required: ${allowedRoles.join(', ')})`,
          role,
          permissions
        };
      }
    }

    if (requiredCapability && !permissions[requiredCapability]) {
      return {
        isAuthorized: false,
        reason: `User ${userId} with role '${role}' lacks required capability '${requiredCapability}'`,
        role,
        permissions
      };
    }

    return { isAuthorized: true, role, membership, permissions };
  }

  /**
   * Enforces membership and throws 403 Error if not authorized
   */
  async requireMembership(userId, homeId, allowedRoles = null, requiredCapability = null) {
    const res = await this.checkHomeMembership(userId, homeId, allowedRoles, requiredCapability);
    if (!res.isAuthorized) {
      const err = new Error(res.reason || `User ${userId} is not authorized for home ${homeId}`);
      err.statusCode = 403;
      throw err;
    }
    return res;
  }

  /**
   * Resolve homeId for a device via device_authorizations or deviceRepo.
   */
  async getHomeIdForDevice(deviceId) {
    if (!deviceId) return null;
    const auth = await this.homeRepo.db.findById('device_authorizations', deviceId);
    if (auth && auth.home_id) return auth.home_id;

    // Fallback: check device repo / authorizations table
    const auths = await this.homeRepo.db.find('device_authorizations', a => a.device_id === deviceId);
    return auths[0] ? auths[0].home_id : null;
  }

  /**
   * Resolve homeId for a room or floor.
   */
  async getHomeIdForRoom(roomId) {
    if (!roomId || !this.roomRepo) return null;
    const room = await this.roomRepo.getRoom(roomId);
    return room ? room.home_id : null;
  }

  async getHomeIdForFloor(floorId) {
    if (!floorId || !this.roomRepo) return null;
    const floor = await this.roomRepo.getFloor(floorId);
    return floor ? floor.home_id : null;
  }

  /**
   * Middleware / guard function to authorize a request against a homeId, deviceId, roomId, or floorId.
   */
  async authorizeRequest({ userId, homeId = null, deviceId = null, roomId = null, floorId = null, allowedRoles = null, requiredCapability = null }) {
    let targetHomeId = homeId;

    if (!targetHomeId && deviceId) {
      targetHomeId = await this.getHomeIdForDevice(deviceId);
      if (!targetHomeId) {
        return { isAuthorized: false, statusCode: 404, message: `Device '${deviceId}' not found or not assigned to a home` };
      }
    }

    if (!targetHomeId && roomId) {
      targetHomeId = await this.getHomeIdForRoom(roomId);
      if (!targetHomeId) {
        return { isAuthorized: false, statusCode: 404, message: `Room '${roomId}' not found` };
      }
    }

    if (!targetHomeId && floorId) {
      targetHomeId = await this.getHomeIdForFloor(floorId);
      if (!targetHomeId) {
        return { isAuthorized: false, statusCode: 404, message: `Floor '${floorId}' not found` };
      }
    }

    if (!targetHomeId) {
      return { isAuthorized: false, statusCode: 400, message: 'Target home context could not be determined' };
    }

    const check = await this.checkHomeMembership(userId, targetHomeId, allowedRoles, requiredCapability);
    if (!check.isAuthorized) {
      return {
        isAuthorized: false,
        statusCode: 403,
        message: check.reason,
        homeId: targetHomeId,
        role: check.role
      };
    }

    return {
      isAuthorized: true,
      homeId: targetHomeId,
      role: check.role,
      permissions: check.permissions
    };
  }
}

module.exports = { HomeAuthorizationService, ROLE_PERMISSIONS };
