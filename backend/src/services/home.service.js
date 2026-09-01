/**
 * EH Home — Home & Membership Domain Service (Phase 4)
 *
 * Responsibilities:
 *  - Manage Home creation and details
 *  - Manage Home Membership (OWNER, ADMIN, MEMBER, GUEST)
 *  - Enforce membership rules (e.g. minimum 1 OWNER)
 *  - Log audit events for membership actions
 */

class HomeService {
  constructor({ homeRepo, userRepo, auditRepo }) {
    this.homeRepo = homeRepo;
    this.userRepo = userRepo;
    this.auditRepo = auditRepo;
  }

  async createHome({ id, name, timezone = 'UTC', address = null, ownerId, actorUserId = null }) {
    if (!name || name.trim() === '') {
      throw new Error('Home name is required');
    }
    const home = await this.homeRepo.createHome({ id, name, timezone, address, ownerId });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_${id}_created_${require('crypto').randomUUID()}`,
        actorUserId: actorUserId || ownerId,
        homeId: id,
        action: 'HOME_CREATED',
        payload: { name, timezone, ownerId }
      });
    }

    return home;
  }

  async getHome(homeId) {
    return this.homeRepo.getHome(homeId);
  }

  async listHomesForUser(userId) {
    const memberships = await this.homeRepo.getMembershipsForUser(userId);
    const homes = [];
    for (const m of memberships) {
      const home = await this.homeRepo.getHome(m.home_id);
      if (home) {
        homes.push({ ...home, role: m.role });
      }
    }
    return homes;
  }

  async getHomeMembers(homeId) {
    const home = await this.homeRepo.getHome(homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    const memberships = await this.homeRepo.getMembershipsForHome(homeId);
    const members = [];
    for (const m of memberships) {
      const user = await this.userRepo.findById(m.user_id);
      members.push({
        membershipId: m.id,
        homeId: m.home_id,
        userId: m.user_id,
        email: user ? user.email : null,
        role: m.role,
        invitedAt: m.invited_at,
        acceptedAt: m.accepted_at
      });
    }
    return members;
  }

  async addHomeMember({ id, homeId, userId, role = 'MEMBER', actorUserId = null }) {
    const validRoles = ['OWNER', 'ADMIN', 'MEMBER', 'GUEST'];
    if (!validRoles.includes(role)) {
      throw new Error(`Invalid role '${role}'. Allowed roles: ${validRoles.join(', ')}`);
    }

    const membership = await this.homeRepo.addMembership({
      id,
      homeId,
      userId,
      role,
      acceptedAt: new Date().toISOString()
    });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_member_add_${id}`,
        actorUserId: actorUserId || userId,
        homeId,
        action: 'HOME_MEMBER_ADDED',
        payload: { addedUserId: userId, role }
      });
    }

    return membership;
  }

  async updateHomeMemberRole({ homeId, userId, newRole, actorUserId = null }) {
    const validRoles = ['OWNER', 'ADMIN', 'MEMBER', 'GUEST'];
    if (!validRoles.includes(newRole)) {
      throw new Error(`Invalid role '${newRole}'`);
    }

    // Demotion check: If demoting from OWNER, ensure at least 1 other OWNER exists
    const currentMemberships = await this.homeRepo.getMembershipsForHome(homeId);
    const targetMembership = currentMemberships.find(m => m.user_id === userId);
    if (!targetMembership) {
      throw new Error(`User ${userId} is not a member of home ${homeId}`);
    }

    if (targetMembership.role === 'OWNER' && newRole !== 'OWNER') {
      const ownerCount = currentMemberships.filter(m => m.role === 'OWNER').length;
      if (ownerCount <= 1) {
        throw new Error('Cannot demote the sole OWNER of a Home');
      }
    }

    const updated = await this.homeRepo.updateMembershipRole(homeId, userId, newRole);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_role_update_${homeId}_${userId}`,
        actorUserId,
        homeId,
        action: 'HOME_MEMBER_ROLE_UPDATED',
        payload: { targetUserId: userId, oldRole: targetMembership.role, newRole }
      });
    }

    return updated;
  }

  async removeHomeMember({ homeId, userId, actorUserId = null }) {
    const currentMemberships = await this.homeRepo.getMembershipsForHome(homeId);
    const targetMembership = currentMemberships.find(m => m.user_id === userId);
    if (!targetMembership) {
      throw new Error(`User ${userId} is not a member of home ${homeId}`);
    }

    if (targetMembership.role === 'OWNER') {
      const ownerCount = currentMemberships.filter(m => m.role === 'OWNER').length;
      if (ownerCount <= 1) {
        throw new Error('Cannot remove the sole OWNER of a Home');
      }
    }

    const res = await this.homeRepo.removeMembership(homeId, userId);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_member_remove_${homeId}_${userId}`,
        actorUserId,
        homeId,
        action: 'HOME_MEMBER_REMOVED',
        payload: { removedUserId: userId }
      });
    }

    return res;
  }

  async updateHome({ homeId, name, timezone, address, actorUserId = null }) {
    const updated = await this.homeRepo.updateHome(homeId, { name, timezone, address });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_home_update_${homeId}_${Date.now()}`,
        actorUserId,
        homeId,
        action: 'HOME_UPDATED',
        payload: { name, timezone, address }
      });
    }

    return updated;
  }

  async deleteHome({ homeId, actorUserId = null }) {
    const home = await this.homeRepo.getHome(homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    const res = await this.homeRepo.deleteHome(homeId);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_home_delete_${homeId}_${Date.now()}`,
        actorUserId,
        homeId,
        action: 'HOME_DELETED',
        payload: { name: home.name }
      });
    }

    return res;
  }

  async transferOwnership({ homeId, newOwnerId, actorUserId = null }) {
    const updated = await this.homeRepo.transferOwnership(homeId, actorUserId, newOwnerId);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_home_transfer_${homeId}_${Date.now()}`,
        actorUserId,
        homeId,
        action: 'HOME_OWNERSHIP_TRANSFERRED',
        payload: { oldOwnerId: actorUserId, newOwnerId }
      });
    }

    return updated;
  }

  async leaveHome({ homeId, userId }) {
    const currentMemberships = await this.homeRepo.getMembershipsForHome(homeId);
    const targetMembership = currentMemberships.find(m => m.user_id === userId);
    if (!targetMembership) {
      throw new Error(`User ${userId} is not a member of home ${homeId}`);
    }

    if (targetMembership.role === 'OWNER') {
      const ownerCount = currentMemberships.filter(m => m.role === 'OWNER').length;
      if (ownerCount <= 1) {
        throw new Error('Sole owner cannot leave home without deleting or transferring ownership first');
      }
    }

    const res = await this.homeRepo.removeMembership(homeId, userId);

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_member_left_${homeId}_${userId}`,
        actorUserId: userId,
        homeId,
        action: 'HOME_MEMBER_LEFT',
        payload: { userId }
      });
    }

    return res;
  }
}

module.exports = { HomeService };
