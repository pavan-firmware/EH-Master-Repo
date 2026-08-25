/**
 * EH Home — Phase 4 API Route Handlers
 * Read-only and domain CRUD endpoints for Homes, Members, Floors, Rooms, and Devices.
 * Does NOT execute real hardware commands or production authentication.
 */

class HomeDeviceApiRouter {
  constructor({ homeService, floorService, roomService, deviceService }) {
    this.homeService = homeService;
    this.floorService = floorService;
    this.roomService = roomService;
    this.deviceService = deviceService;
  }

  async handle(method, path, body = {}, params = {}) {
    try {
      // 1. Homes
      if (method === 'GET' && path === '/api/v1/homes') {
        const userId = params.userId || 'usr_owner_1';
        const homes = await this.homeService.listHomesForUser(userId);
        return { status: 200, body: { data: homes, total: homes.length } };
      }

      if (method === 'POST' && path === '/api/v1/homes') {
        const home = await this.homeService.createHome(body);
        return { status: 201, body: { data: home } };
      }

      if (method === 'GET' && path.startsWith('/api/v1/homes/') && path.endsWith('/members')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/members', '');
        const members = await this.homeService.getHomeMembers(homeId);
        return { status: 200, body: { data: members, total: members.length } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/homes/') && path.endsWith('/members')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/members', '');
        const member = await this.homeService.addHomeMember({ ...body, homeId });
        return { status: 201, body: { data: member } };
      }

      if (method === 'GET' && path.startsWith('/api/v1/homes/') && path.endsWith('/floors')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/floors', '');
        const floors = await this.floorService.listFloors(homeId);
        return { status: 200, body: { data: floors, total: floors.length } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/homes/') && path.endsWith('/floors')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/floors', '');
        const floor = await this.floorService.createFloor({ ...body, homeId });
        return { status: 201, body: { data: floor } };
      }

      if (method === 'GET' && path.startsWith('/api/v1/homes/') && path.endsWith('/rooms')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/rooms', '');
        const rooms = await this.roomService.listRooms(homeId);
        return { status: 200, body: { data: rooms, total: rooms.length } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/homes/') && path.endsWith('/rooms')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/rooms', '');
        const room = await this.roomService.createRoom({ ...body, homeId });
        return { status: 201, body: { data: room } };
      }

      if (method === 'GET' && path.startsWith('/api/v1/homes/') && path.endsWith('/devices')) {
        const homeId = path.replace('/api/v1/homes/', '').replace('/devices', '');
        const devices = await this.deviceService.getDevicesSummaryForHome(homeId);
        return { status: 200, body: { data: devices, total: devices.length } };
      }

      if (method === 'GET' && path.startsWith('/api/v1/homes/') && !path.includes('/', 15)) {
        const homeId = path.replace('/api/v1/homes/', '');
        const home = await this.homeService.getHome(homeId);
        if (!home) return { status: 404, body: { error: `Home ${homeId} not found` } };
        return { status: 200, body: { data: home } };
      }

      // 2. Devices
      if (method === 'POST' && path === '/api/v1/devices/register') {
        const dev = await this.deviceService.registerDevice(body);
        return { status: 201, body: { data: dev } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/devices/') && path.endsWith('/assign')) {
        const deviceId = path.replace('/api/v1/devices/', '').replace('/assign', '');
        const auth = await this.deviceService.assignDeviceToHome({ ...body, deviceId });
        return { status: 200, body: { data: auth } };
      }

      if (method === 'POST' && path.startsWith('/api/v1/devices/') && path.endsWith('/move')) {
        const deviceId = path.replace('/api/v1/devices/', '').replace('/move', '');
        let updated;
        if (body.newHomeId) {
          updated = await this.deviceService.moveDeviceToHome({ deviceId, newHomeId: body.newHomeId, newRoomId: body.newRoomId });
        } else {
          updated = await this.deviceService.moveDeviceToRoom({ deviceId, newRoomId: body.newRoomId });
        }
        return { status: 200, body: { data: updated } };
      }

      if (method === 'GET' && path.startsWith('/api/v1/devices/') && !path.includes('/', 17)) {
        const deviceId = path.replace('/api/v1/devices/', '');
        const summary = await this.deviceService.getResolvedDeviceSummary(deviceId);
        if (!summary) return { status: 404, body: { error: `Device ${deviceId} not found` } };
        return { status: 200, body: { data: summary } };
      }

      return { status: 404, body: { error: 'Not Found', path } };
    } catch (err) {
      return { status: 400, body: { error: err.message } };
    }
  }
}

module.exports = { HomeDeviceApiRouter };
