/**
 * EH Home — Room Domain Service (Phase 4)
 *
 * Responsibilities:
 *  - Manage Room creation, listing, renaming, moving, and deletion
 *  - Validate cross-home relationships (reject room with Home A pointing to Floor of Home B)
 *  - Log audit events
 */

class RoomService {
  constructor({ roomRepo, homeRepo, deviceRepo, auditRepo }) {
    this.roomRepo = roomRepo;
    this.homeRepo = homeRepo;
    this.deviceRepo = deviceRepo;
    this.auditRepo = auditRepo;
  }

  async createRoom({ id, homeId, floorId = null, name, iconKey = 'default', sortOrder = 0, actorUserId = null }) {
    if (!name || name.trim() === '') {
      throw new Error('Room name is required');
    }

    const home = await this.homeRepo.getHome(homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    if (floorId) {
      const floor = await this.roomRepo.getFloor(floorId);
      if (!floor) throw new Error(`Floor ${floorId} does not exist`);
      if (floor.home_id !== homeId) {
        throw new Error(`Floor ${floorId} belongs to home ${floor.home_id}, not target home ${homeId}`);
      }
    }

    const room = await this.roomRepo.createRoom({ id, homeId, floorId, name, iconKey, sortOrder });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_room_create_${room.id}_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        actorUserId,
        homeId,
        action: 'ROOM_CREATED',
        payload: { roomId: room.id, floorId, name, iconKey }
      });
    }

    return room;
  }

  async getRoom(roomId) {
    return this.roomRepo.getRoom(roomId);
  }

  async listRooms(homeId) {
    return this.roomRepo.getRoomsByHome(homeId);
  }

  async renameRoom({ roomId, name, actorUserId = null }) {
    if (!name || name.trim() === '') {
      throw new Error('Room name is required');
    }
    const room = await this.roomRepo.getRoom(roomId);
    if (!room) throw new Error(`Room ${roomId} does not exist`);

    const updated = await this.roomRepo.renameRoom(roomId, name);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_room_rename_${roomId}`,
        actorUserId,
        homeId: room.home_id,
        action: 'ROOM_RENAMED',
        payload: { roomId, oldName: room.name, newName: name }
      });
    }

    return updated;
  }

  async moveRoomWithinHome({ roomId, newFloorId, actorUserId = null }) {
    const room = await this.roomRepo.getRoom(roomId);
    if (!room) throw new Error(`Room ${roomId} does not exist`);

    if (newFloorId) {
      const floor = await this.roomRepo.getFloor(newFloorId);
      if (!floor) throw new Error(`Floor ${newFloorId} does not exist`);
      if (floor.home_id !== room.home_id) {
        throw new Error(`Cannot move room ${roomId}: target floor ${newFloorId} belongs to home ${floor.home_id}, but room belongs to home ${room.home_id}`);
      }
    }

    const updated = await this.roomRepo.moveRoom(roomId, newFloorId);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_room_move_${roomId}`,
        actorUserId,
        homeId: room.home_id,
        action: 'ROOM_MOVED_FLOOR',
        payload: { roomId, oldFloorId: room.floor_id, newFloorId }
      });
    }

    return updated;
  }

  async deleteRoom({ roomId, actorUserId = null }) {
    const room = await this.roomRepo.getRoom(roomId);
    if (!room) throw new Error(`Room ${roomId} does not exist`);

    // Verify devices assigned to room or unassign them safely
    if (this.deviceRepo) {
      const authorizations = await this.deviceRepo.getAuthorizationsByHome(room.home_id);
      const devicesInRoom = authorizations.filter(a => a.room_id === roomId);
      for (const devAuth of devicesInRoom) {
        await this.deviceRepo.updateDeviceAuthorization(devAuth.device_id, { roomId: null });
      }
    }

    const res = await this.roomRepo.deleteRoom(roomId);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_room_delete_${roomId}`,
        actorUserId,
        homeId: room.home_id,
        action: 'ROOM_DELETED',
        payload: { roomId, name: room.name }
      });
    }

    return res;
  }
}

module.exports = { RoomService };
