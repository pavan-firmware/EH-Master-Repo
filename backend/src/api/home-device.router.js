'use strict';

/**
 * EH Home — Phase 16 Home & Device Domain API Router
 *
 * Full lifecycle for Homes, Members, Invitations, Ownership, Floors, Rooms, and Devices.
 */

class HomeDeviceApiRouter {
  constructor({ homeService, floorService, roomService, deviceService, invitationService = null, homeAuthService = null }) {
    this.homeService = homeService;
    this.floorService = floorService;
    this.roomService = roomService;
    this.deviceService = deviceService;
    this.invitationService = invitationService;
    this.homeAuthService = homeAuthService;
  }

  async handle(method, path, body = {}, params = {}) {
    const actorUserId = params.userId || (params.actorContext ? params.actorContext.userId : null);

    try {
      // 1. Homes Collection
      if (method === 'GET' && path === '/api/v1/homes') {
        const userId = actorUserId || 'usr_owner_1';
        const homes = await this.homeService.listHomesForUser(userId);
        const enriched = homes.map(h => ({
          ...h,
          permissions: this.homeAuthService ? this.homeAuthService.getPermissionsForRole(h.role) : null
        }));
        return { status: 200, body: { success: true, data: enriched, total: enriched.length } };
      }

      if (method === 'POST' && path === '/api/v1/homes') {
        const ownerId = body.ownerId || actorUserId;
        const home = await this.homeService.createHome({ ...body, ownerId, actorUserId });
        return { status: 201, body: { success: true, data: home } };
      }

      // 2. Specific Home Operations (/api/v1/homes/:homeId)
      const singleHomeMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)$/);
      if (singleHomeMatch) {
        const homeId = singleHomeMatch[1];
        if (method === 'GET') {
          const home = await this.homeService.getHome(homeId);
          if (!home) return { status: 404, body: { success: false, error: `Home ${homeId} not found` } };
          const members = await this.homeService.getHomeMembers(homeId);
          const rooms = await this.roomService.listRooms(homeId);
          const devices = await this.deviceService.getDevicesSummaryForHome(homeId);
          const userMembership = members.find(m => m.userId === actorUserId);
          const role = userMembership ? userMembership.role : (home.owner_id === actorUserId ? 'OWNER' : 'VIEWER');
          const permissions = this.homeAuthService ? this.homeAuthService.getPermissionsForRole(role) : null;

          return {
            status: 200,
            body: {
              success: true,
              data: {
                ...home,
                role,
                permissions,
                memberCount: members.length,
                roomCount: rooms.length,
                deviceCount: devices.length
              }
            }
          };
        }

        if (method === 'PATCH') {
          const updated = await this.homeService.updateHome({
            homeId,
            name: body.name,
            timezone: body.timezone,
            address: body.address,
            actorUserId
          });
          return { status: 200, body: { success: true, data: updated } };
        }

        if (method === 'DELETE') {
          await this.homeService.deleteHome({ homeId, actorUserId });
          return { status: 200, body: { success: true, data: { deletedHomeId: homeId } } };
        }
      }

      // 3. Home Ownership & Leaving
      const transferMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)\/transfer-ownership$/);
      if (method === 'POST' && transferMatch) {
        const homeId = transferMatch[1];
        const newOwnerId = body.newOwnerId;
        if (!newOwnerId) throw new Error('newOwnerId is required');
        const updated = await this.homeService.transferOwnership({ homeId, newOwnerId, actorUserId });
        return { status: 200, body: { success: true, data: updated } };
      }

      const leaveMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)\/leave$/);
      if (method === 'POST' && leaveMatch) {
        const homeId = leaveMatch[1];
        await this.homeService.leaveHome({ homeId, userId: actorUserId });
        return { status: 200, body: { success: true, data: { message: `Left home ${homeId} successfully` } } };
      }

      // 4. Home Members
      const membersMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)\/members$/);
      if (membersMatch) {
        const homeId = membersMatch[1];
        if (method === 'GET') {
          const members = await this.homeService.getHomeMembers(homeId);
          return { status: 200, body: { success: true, data: members, total: members.length } };
        }
        if (method === 'POST') {
          const member = await this.homeService.addHomeMember({ ...body, homeId, actorUserId });
          return { status: 201, body: { success: true, data: member } };
        }
      }

      const memberRoleMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)\/members\/([^\/]+)\/role$/);
      if (method === 'PATCH' && memberRoleMatch) {
        const homeId = memberRoleMatch[1];
        const targetUserId = memberRoleMatch[2];
        const { role } = body;
        if (!role) throw new Error('Role is required');
        const updated = await this.homeService.updateHomeMemberRole({
          homeId,
          userId: targetUserId,
          newRole: role,
          actorUserId
        });
        return { status: 200, body: { success: true, data: updated } };
      }

      const memberRemoveMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)\/members\/([^\/]+)$/);
      if (method === 'DELETE' && memberRemoveMatch) {
        const homeId = memberRemoveMatch[1];
        const targetUserId = memberRemoveMatch[2];
        await this.homeService.removeHomeMember({ homeId, userId: targetUserId, actorUserId });
        return { status: 200, body: { success: true, data: { removedUserId: targetUserId } } };
      }

      // 5. Home Invitations
      const homeInvitesMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)\/invitations$/);
      if (homeInvitesMatch && this.invitationService) {
        const homeId = homeInvitesMatch[1];
        if (method === 'GET') {
          const invites = await this.invitationService.listPendingInvitationsForHome(homeId);
          return { status: 200, body: { success: true, data: invites, total: invites.length } };
        }
        if (method === 'POST') {
          const { email, role, customCode } = body;
          const invite = await this.invitationService.createInvitation({
            homeId,
            inviterUserId: actorUserId,
            inviteeEmail: email,
            role: role || 'MEMBER',
            customCode
          });
          return { status: 201, body: { success: true, data: invite } };
        }
      }

      const revokeInviteMatch = path.match(/^\/api\/v1\/homes\/([^\/]+)\/invitations\/([^\/]+)$/);
      if (method === 'DELETE' && revokeInviteMatch && this.invitationService) {
        const homeId = revokeInviteMatch[1];
        const inviteId = revokeInviteMatch[2];
        const revoked = await this.invitationService.revokeInvitation({ homeId, inviteId, actorUserId });
        return { status: 200, body: { success: true, data: revoked } };
      }

      // 6. Floors & Rooms
      if (method === 'GET' && path.startsWith('/api/v1/homes/') && path.endsWith('/floors')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/floors', '');
        const floors = await this.floorService.listFloors(homeId);
        return { status: 200, body: { success: true, data: floors, total: floors.length } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/homes/') && path.endsWith('/floors')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/floors', '');
        const floor = await this.floorService.createFloor({ ...body, homeId });
        return { status: 201, body: { success: true, data: floor } };
      }

      if (method === 'GET' && path.startsWith('/api/v1/homes/') && path.endsWith('/rooms')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/rooms', '');
        const rooms = await this.roomService.listRooms(homeId);
        return { status: 200, body: { success: true, data: rooms, total: rooms.length } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/homes/') && path.endsWith('/rooms')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/rooms', '');
        const room = await this.roomService.createRoom({ ...body, homeId });
        return { status: 201, body: { success: true, data: room } };
      }

      // 7. Devices
      if (method === 'GET' && path.startsWith('/api/v1/homes/') && path.endsWith('/devices')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/devices', '');
        const devices = await this.deviceService.getDevicesSummaryForHome(homeId);
        return { status: 200, body: { success: true, data: devices, total: devices.length } };
      }

      if (method === 'POST' && path === '/api/v1/devices/register') {
        const dev = await this.deviceService.registerDevice(body);
        return { status: 201, body: { success: true, data: dev } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/devices/') && path.endsWith('/assign')) {
        const deviceId = path.replace('/api/v1/devices/', '').replace('/assign', '');
        const auth = await this.deviceService.assignDeviceToHome({ ...body, deviceId });
        return { status: 200, body: { success: true, data: auth } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/devices/') && path.endsWith('/move')) {
        const deviceId = path.replace('/api/v1/devices/', '').replace('/move', '');
        let updated;
        if (body.newHomeId) {
          updated = await this.deviceService.moveDeviceToHome({ deviceId, newHomeId: body.newHomeId, newRoomId: body.newRoomId });
        } else {
          updated = await this.deviceService.moveDeviceToRoom({ deviceId, newRoomId: body.newRoomId });
        }
        return { status: 200, body: { success: true, data: updated } };
      }

      if (method === 'GET' && path.startsWith('/api/v1/devices/') && !path.includes('/', 17)) {
        const deviceId = path.replace('/api/v1/devices/', '');
        const summary = await this.deviceService.getResolvedDeviceSummary(deviceId);
        if (!summary) return { status: 404, body: { success: false, error: `Device ${deviceId} not found` } };
        return { status: 200, body: { success: true, data: summary } };
      }

      return { status: 404, body: { success: false, error: 'Not Found', path } };
    } catch (err) {
      return { status: 400, body: { success: false, error: err.message } };
    }
  }
}

module.exports = { HomeDeviceApiRouter };
