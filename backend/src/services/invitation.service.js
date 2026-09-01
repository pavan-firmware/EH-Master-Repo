'use strict';

/**
 * EH Home — Invitation Service (Phase 16)
 *
 * Manages secure invitations to join homes with role-based access.
 * Enforces single-use token consumption, 7-day expiration, duplicate prevention,
 * and comprehensive audit logging.
 */

const crypto = require('crypto');

class InvitationService {
  constructor({ invitationRepo, homeRepo, userRepo, auditRepo, notificationService = null }) {
    this.invitationRepo = invitationRepo;
    this.homeRepo = homeRepo;
    this.userRepo = userRepo;
    this.auditRepo = auditRepo;
    this.notificationService = notificationService;
  }

  generateInviteCode() {
    return 'inv_' + crypto.randomBytes(8).toString('hex');
  }

  async createInvitation({ homeId, inviterUserId, inviteeEmail, role = 'MEMBER', customCode = null }) {
    const validRoles = ['ADMIN', 'MEMBER', 'GUEST', 'VIEWER'];
    const normalizedRole = (role || 'MEMBER').toUpperCase();
    if (!validRoles.includes(normalizedRole)) {
      throw new Error(`Invalid invitation role '${role}'. Allowed: ${validRoles.join(', ')}`);
    }

    if (!inviteeEmail || !inviteeEmail.includes('@')) {
      throw new Error('Valid invitee email is required');
    }

    const home = await this.homeRepo.getHome(homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    // Check if invitee is already a member
    const existingUser = await this.userRepo.findByEmail(inviteeEmail);
    if (existingUser) {
      const memberships = await this.homeRepo.getMembershipsForHome(homeId);
      const isAlreadyMember = memberships.some(m => m.user_id === existingUser.id);
      if (isAlreadyMember) {
        throw new Error(`User with email ${inviteeEmail} is already a member of this home`);
      }
    }

    const inviteId = crypto.randomUUID();
    const inviteCode = customCode || this.generateInviteCode();
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();

    const invitation = await this.invitationRepo.createInvitation({
      id: inviteId,
      homeId,
      inviterUserId,
      inviteeEmail: inviteeEmail.toLowerCase().trim(),
      role: normalizedRole,
      inviteCode,
      expiresAt
    });

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_invite_create_${inviteId}`,
        actorUserId: inviterUserId,
        homeId,
        action: 'HOME_INVITATION_CREATED',
        payload: { inviteeEmail, role: normalizedRole, expiresAt }
      });
    }

    return invitation;
  }

  async listPendingInvitationsForHome(homeId) {
    return this.invitationRepo.findPendingByHome(homeId);
  }

  async listPendingInvitationsForUser(email) {
    if (!email) return [];
    const invites = await this.invitationRepo.findPendingByEmail(email);
    const enriched = [];
    for (const inv of invites) {
      const home = await this.homeRepo.getHome(inv.home_id);
      const inviter = await this.userRepo.findById(inv.inviter_user_id);
      enriched.push({
        ...inv,
        homeName: home ? home.name : 'Unknown Home',
        inviterEmail: inviter ? inviter.email : 'Unknown'
      });
    }
    return enriched;
  }

  async revokeInvitation({ homeId, inviteId, actorUserId }) {
    const inv = await this.invitationRepo.findById(inviteId);
    if (!inv) throw new Error(`Invitation ${inviteId} not found`);
    if (inv.home_id !== homeId) throw new Error(`Invitation does not belong to home ${homeId}`);

    const updated = await this.invitationRepo.updateStatus(inviteId, 'REVOKED');

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_invite_revoke_${inviteId}`,
        actorUserId,
        homeId,
        action: 'HOME_INVITATION_REVOKED',
        payload: { inviteId, inviteeEmail: inv.invitee_email }
      });
    }

    return updated;
  }

  async acceptInvitation({ inviteCode, userId, email }) {
    if (!inviteCode) throw new Error('Invite code is required');
    const inv = await this.invitationRepo.findByCode(inviteCode);
    if (!inv) throw new Error('Invalid invitation code');

    if (inv.status !== 'PENDING') {
      throw new Error(`Invitation is no longer pending (status: ${inv.status})`);
    }

    if (new Date(inv.expires_at) < new Date()) {
      await this.invitationRepo.updateStatus(inv.id, 'EXPIRED');
      throw new Error('Invitation code has expired');
    }

    if (email && inv.invitee_email.toLowerCase() !== email.toLowerCase()) {
      throw new Error(`This invitation was issued to ${inv.invitee_email}, not ${email}`);
    }

    // Add membership
    const membership = await this.homeRepo.addMembership({
      id: crypto.randomUUID(),
      homeId: inv.home_id,
      userId,
      role: inv.role,
      acceptedAt: new Date().toISOString()
    });

    // Mark invitation accepted
    await this.invitationRepo.updateStatus(inv.id, 'ACCEPTED', new Date().toISOString());

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_invite_accept_${inv.id}`,
        actorUserId: userId,
        homeId: inv.home_id,
        action: 'HOME_INVITATION_ACCEPTED',
        payload: { inviteId: inv.id, role: inv.role }
      });
    }

    const home = await this.homeRepo.getHome(inv.home_id);
    return { membership, home };
  }

  async rejectInvitation({ inviteCode, email }) {
    if (!inviteCode) throw new Error('Invite code is required');
    const inv = await this.invitationRepo.findByCode(inviteCode);
    if (!inv) throw new Error('Invalid invitation code');

    if (inv.status !== 'PENDING') {
      throw new Error(`Invitation is not pending (status: ${inv.status})`);
    }

    if (email && inv.invitee_email.toLowerCase() !== email.toLowerCase()) {
      throw new Error(`This invitation was issued to ${inv.invitee_email}, not ${email}`);
    }

    const updated = await this.invitationRepo.updateStatus(inv.id, 'REJECTED');

    if (this.auditRepo) {
      await this.auditRepo.log({
        id: `audit_invite_reject_${inv.id}`,
        actorUserId: inv.inviter_user_id,
        homeId: inv.home_id,
        action: 'HOME_INVITATION_REJECTED',
        payload: { inviteId: inv.id, inviteeEmail: inv.invitee_email }
      });
    }

    return updated;
  }
}

module.exports = { InvitationService };
