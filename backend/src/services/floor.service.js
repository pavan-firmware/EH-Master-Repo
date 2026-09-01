/**
 * EH Home — Floor Domain Service (Phase 4)
 *
 * Responsibilities:
 *  - Manage Floor creation, listing, renaming, ordering, and deletion
 *  - Enforce Home ownership validation
 *  - Log audit events
 */

class FloorService {
  constructor({ roomRepo, homeRepo, auditRepo }) {
    this.roomRepo = roomRepo;
    this.homeRepo = homeRepo;
    this.auditRepo = auditRepo;
  }

  async createFloor({ id, homeId, name, level = 0, actorUserId = null }) {
    if (!name || name.trim() === '') {
      throw new Error('Floor name is required');
    }

    const home = await this.homeRepo.getHome(homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    const floor = await this.roomRepo.createFloor({ id, homeId, name, level });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_floor_create_${floor.id}_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
        actorUserId,
        homeId,
        action: 'FLOOR_CREATED',
        payload: { floorId: floor.id, name, level }
      });
    }

    return floor;
  }

  async getFloor(floorId) {
    return this.roomRepo.getFloor(floorId);
  }

  async listFloors(homeId) {
    return this.roomRepo.getFloorsByHome(homeId);
  }

  async renameFloor({ floorId, name, actorUserId = null }) {
    if (!name || name.trim() === '') {
      throw new Error('Floor name is required');
    }
    const floor = await this.roomRepo.getFloor(floorId);
    if (!floor) throw new Error(`Floor ${floorId} does not exist`);

    const updated = await this.roomRepo.renameFloor(floorId, name);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_floor_rename_${floorId}`,
        actorUserId,
        homeId: floor.home_id,
        action: 'FLOOR_RENAMED',
        payload: { floorId, oldName: floor.name, newName: name }
      });
    }

    return updated;
  }

  async deleteFloor({ floorId, actorUserId = null }) {
    const floor = await this.roomRepo.getFloor(floorId);
    if (!floor) throw new Error(`Floor ${floorId} does not exist`);

    // Verify no rooms belong to this floor before deletion
    const rooms = await this.roomRepo.getRoomsByHome(floor.home_id);
    const roomsOnFloor = rooms.filter(r => r.floor_id === floorId);
    if (roomsOnFloor.length > 0) {
      throw new Error(`Cannot delete floor ${floorId}: ${roomsOnFloor.length} rooms are attached`);
    }

    const res = await this.roomRepo.deleteFloor(floorId);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_floor_delete_${floorId}`,
        actorUserId,
        homeId: floor.home_id,
        action: 'FLOOR_DELETED',
        payload: { floorId, name: floor.name }
      });
    }

    return res;
  }
}

module.exports = { FloorService };
