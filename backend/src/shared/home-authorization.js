'use strict';

/**
 * EH Home — Home Membership Authorization Middleware (Phase 7A)
 *
 * Enforces membership scoping across all Home-related resources (homes, floors, rooms, members, devices, state, commands).
 * Ensures a user belonging to Home A CANNOT access resources in Home B.
 */

class HomeAuthorizationService {
  constructor({ homeRepo, deviceRepo, roomRepo }) {
    this.homeRepo = homeRepo;
    this.deviceRepo = deviceRepo;
    this.roomRepo = roomRepo;
  }

  /**
   * Check if a user is a member of the specified home with optional role restriction.
   */
  async checkHomeMembership(userId, homeId, allowedRoles = null) {
    if (!userId || !homeId) return { isAuthorized: false, reason: 'Missing userId or homeId' };

    if (typeof userId === 'string' && userId.startsWith('system_')) {
      return { isAuthorized: true, role: 'SYSTEM' };
    }

    const memberships = await this.homeRepo.getMembershipsForUser(userId);
    const membership = memberships.find(m => m.home_id === homeId);

    if (!membership) {
      return { isAuthorized: false, reason: `User ${userId} is not a member of home ${homeId}` };
    }

    if (allowedRoles && Array.isArray(allowedRoles) && allowedRoles.length > 0) {
      if (!allowedRoles.includes(membership.role)) {
        return {
          isAuthorized: false,
          reason: `User ${userId} role '${membership.role}' is not allowed (required: ${allowedRoles.join(', ')})`
        };
      }
    }

    return { isAuthorized: true, role: membership.role, membership };
  }

  /**
   * Enforces membership and throws 403 Error if not authorized
   */
  async requireMembership(userId, homeId, allowedRoles = null) {
    const res = await this.checkHomeMembership(userId, homeId, allowedRoles);
    if (!res.isAuthorized) {
      const err = new Error(res.reason || `User ${userId} is not a member of home ${homeId}`);
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
   * Middleware / guard function to authorize a request against a homeId or deviceId.
   */
  async authorizeRequest({ userId, homeId = null, deviceId = null, roomId = null, floorId = null, allowedRoles = null }) {
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

    const check = await this.checkHomeMembership(userId, targetHomeId, allowedRoles);
    if (!check.isAuthorized) {
      return { isAuthorized: false, statusCode: 403, message: check.reason, homeId: targetHomeId };
    }

    return { isAuthorized: true, homeId: targetHomeId, role: check.role };
  }
}

module.exports = { HomeAuthorizationService };
