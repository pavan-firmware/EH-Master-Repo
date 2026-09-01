'use strict';

/**
 * EH Home — Synchronization & Offline Reconciliation Service (Phase 17)
 */

class SyncService {
  constructor({
    db,
    userRepo,
    homeRepo,
    roomRepo,
    deviceRepo,
    deviceStateRepo,
    sceneRepo,
    automationRepo,
    scheduleRepo,
    notificationRepo,
    syncRepo,
    homeAuthService
  }) {
    this.db = db;
    this.userRepo = userRepo;
    this.homeRepo = homeRepo;
    this.roomRepo = roomRepo;
    this.deviceRepo = deviceRepo;
    this.deviceStateRepo = deviceStateRepo;
    this.sceneRepo = sceneRepo;
    this.automationRepo = automationRepo;
    this.scheduleRepo = scheduleRepo;
    this.notificationRepo = notificationRepo;
    this.syncRepo = syncRepo;
    this.homeAuthService = homeAuthService;
  }

  async getBootstrapBundle(userId, homeId = null, clientDeviceId = 'default_client') {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new Error(`User ${userId} not found`);

    const profile = await this.userRepo.getProfile(userId);
    const memberships = await this.homeRepo.getMembershipsForUser(userId);

    const homes = [];
    const allMembers = [];
    for (const m of memberships) {
      const h = await this.homeRepo.getHome(m.home_id);
      if (h) {
        const perms = this.homeAuthService ? this.homeAuthService.getPermissionsForRole(m.role) : null;
        const count = (await this.homeRepo.getMembershipsForHome(m.home_id)).length;
        homes.push({
          id: h.id,
          name: h.name,
          timezone: h.timezone || 'UTC',
          address: h.address || null,
          role: m.role,
          permissions: perms,
          membersCount: count
        });

        const mems = await this.homeRepo.getMembershipsForHome(m.home_id);
        for (const hm of mems) {
          allMembers.push({
            membershipId: hm.id,
            homeId: hm.home_id,
            userId: hm.user_id,
            email: hm.email || null,
            role: hm.role
          });
        }
      }
    }

    const activeHomeId = homeId || (homes.length > 0 ? homes[0].id : null);

    let rooms = [];
    let devices = [];
    let automations = [];
    let scenes = [];
    let schedules = [];

    if (activeHomeId) {
      // Verify membership
      const userMem = memberships.find(m => m.home_id === activeHomeId);
      if (!userMem) throw new Error(`User ${userId} is not a member of home ${activeHomeId}`);

      // Rooms
      if (this.roomRepo) {
        const rawRooms = await this.roomRepo.getRoomsByHome(activeHomeId);
        rooms = rawRooms.map(r => ({
          id: r.id,
          homeId: r.home_id,
          name: r.name,
          displayOrder: r.sort_order || r.display_order || 0
        }));
      }

      // Devices
      if (this.deviceRepo) {
        const auths = await this.deviceRepo.getAuthorizationsByHome(activeHomeId);
        for (const auth of auths) {
          const d = await this.deviceRepo.getDevice(auth.device_id);
          let state = null;
          if (this.deviceStateRepo) {
            state = await this.deviceStateRepo.getFullState(auth.device_id);
          }
          devices.push({
            id: auth.device_id,
            homeId: activeHomeId,
            roomId: auth.room_id || null,
            customName: auth.custom_name || (d ? d.serial_number : 'Device'),
            productVariantId: d ? d.product_variant_id : null,
            isOnline: state ? state.connectionState === 'ONLINE' : false,
            capabilities: d ? d.capabilities || [] : [],
            channelCount: d ? d.channel_count || 1 : 1,
            healthStatus: state && state.connectionState === 'ONLINE' ? 'ONLINE' : 'OFFLINE',
            lastSeenAt: state ? state.lastSeenAt : null
          });
        }
      }

      // Automations, Scenes, Schedules
      if (this.automationRepo) {
        const rawAuto = await this.automationRepo.findByHomeId(activeHomeId);
        automations = rawAuto.map(a => ({
          id: a.id,
          homeId: a.home_id,
          name: a.name,
          enabled: a.is_enabled !== undefined ? a.is_enabled : a.enabled,
          trigger: a.trigger_config || a.trigger || {},
          actions: a.actions || []
        }));
      }

      if (this.sceneRepo) {
        const rawScenes = await this.sceneRepo.findByHomeId(activeHomeId);
        scenes = rawScenes.map(s => ({
          id: s.id,
          homeId: s.home_id,
          name: s.name,
          actions: s.actions || []
        }));
      }

      if (this.scheduleRepo) {
        const rawSched = await this.scheduleRepo.findByHomeId(activeHomeId);
        schedules = rawSched.map(sc => ({
          id: sc.id,
          homeId: sc.home_id,
          name: sc.name,
          enabled: sc.is_enabled !== undefined ? sc.is_enabled : sc.enabled,
          cronExpression: sc.cron_expression || sc.cronExpression
        }));
      }
    }

    let notificationPreferences = null;
    if (this.notificationRepo) {
      notificationPreferences = await this.notificationRepo.getPreferences(userId);
    }

    // Record checkpoint
    if (this.syncRepo && activeHomeId) {
      await this.syncRepo.recordCheckpoint({
        userId,
        homeId: activeHomeId,
        clientDeviceId,
        lastSyncSeq: Date.now(),
        schemaVersion: 1
      });
    }

    return {
      schemaVersion: 1,
      syncedAt: new Date().toISOString(),
      user: {
        id: user.id,
        email: user.email,
        fullName: profile ? profile.full_name : null,
        phoneNumber: profile ? profile.phone_number : null,
        avatarUrl: profile ? profile.avatar_url : null,
        timezone: profile ? profile.timezone : 'UTC'
      },
      homes,
      members: allMembers,
      rooms,
      devices,
      automations,
      scenes,
      schedules,
      notificationPreferences
    };
  }

  async reconcilePendingChanges(userId, homeId, mutations = []) {
    const memberships = await this.homeRepo.getMembershipsForUser(userId);
    const membership = memberships.find(m => m.home_id === homeId);
    if (!membership) {
      throw new Error(`Authorization failed: User ${userId} is not a member of home ${homeId}`);
    }

    const role = membership.role;
    const results = [];
    let acceptedCount = 0;
    let rejectedCount = 0;
    let conflictCount = 0;

    for (const m of mutations) {
      const mutationId = m.mutationId || `mut_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      const { entityType, entityId, mutationType, payload = {} } = m;

      try {
        let outcome = { mutationId, status: 'ACCEPTED' };

        switch (entityType) {
          case 'home': {
            if (!this.homeAuthService.canManageHome(role)) {
              outcome = { mutationId, status: 'REJECTED', reason: 'Forbidden: Insufficient role to manage home' };
              break;
            }
            if (mutationType === 'update') {
              const updated = await this.homeRepo.updateHome(homeId, payload);
              outcome.authoritativeData = updated;
            }
            break;
          }

          case 'room': {
            if (!this.homeAuthService.canManageHome(role)) {
              outcome = { mutationId, status: 'REJECTED', reason: 'Forbidden: Insufficient role to manage rooms' };
              break;
            }
            if (mutationType === 'create') {
              const roomId = require('crypto').randomUUID();
              const created = await this.roomRepo.createRoom({
                id: roomId,
                homeId,
                name: payload.name || 'New Room',
                displayOrder: payload.displayOrder || 0
              });
              outcome.serverEntityId = roomId;
              outcome.authoritativeData = created;
            } else if (mutationType === 'update' && entityId) {
              const updated = await this.roomRepo.updateRoom(entityId, payload);
              outcome.authoritativeData = updated;
            } else if (mutationType === 'delete' && entityId) {
              await this.roomRepo.deleteRoom(entityId);
            }
            break;
          }

          case 'device': {
            if (!this.homeAuthService.canManageDevices(role)) {
              outcome = { mutationId, status: 'REJECTED', reason: 'Forbidden: Insufficient role to manage devices' };
              break;
            }
            // Check device belongs to this home
            const auth = await this.deviceRepo.getDeviceAuthorization(entityId);
            if (!auth || auth.home_id !== homeId) {
              outcome = { mutationId, status: 'REJECTED', reason: 'Device is no longer claimed in this home' };
              break;
            }

            if (mutationType === 'update') {
              if (payload.customName) {
                await this.deviceRepo.updateDeviceAuthorization(entityId, { custom_name: payload.customName });
              }
              if (payload.roomId !== undefined) {
                // Verify room belongs to home if not null
                if (payload.roomId) {
                  const room = await this.roomRepo.getRoom(payload.roomId);
                  if (!room || room.home_id !== homeId) {
                    outcome = { mutationId, status: 'CONFLICT', reason: 'Target room does not belong to home' };
                    break;
                  }
                }
                await this.deviceRepo.updateDeviceAuthorization(entityId, { room_id: payload.roomId });
              }
              const updatedAuth = await this.deviceRepo.getDeviceAuthorization(entityId);
              outcome.authoritativeData = updatedAuth;
            }
            break;
          }

          case 'profile': {
            if (mutationType === 'update') {
              const updated = await this.userRepo.upsertProfile(userId, {
                full_name: payload.fullName,
                phone_number: payload.phoneNumber,
                timezone: payload.timezone
              });
              outcome.authoritativeData = updated;
            }
            break;
          }

          case 'notification_preference': {
            if (this.notificationRepo && mutationType === 'update') {
              const updated = await this.notificationRepo.updatePreferences(userId, payload);
              outcome.authoritativeData = updated;
            }
            break;
          }

          default:
            outcome = { mutationId, status: 'REJECTED', reason: `Unsupported mutation entity type '${entityType}'` };
        }

        if (outcome.status === 'ACCEPTED') acceptedCount++;
        else if (outcome.status === 'CONFLICT') conflictCount++;
        else rejectedCount++;

        // Audit mutation
        if (this.syncRepo) {
          await this.syncRepo.recordPendingAudit({
            userId,
            homeId,
            clientMutationId: mutationId,
            entityType,
            entityId,
            mutationType,
            payload,
            status: outcome.status,
            rejectionReason: outcome.reason || null
          });
        }

        results.push(outcome);
      } catch (err) {
        rejectedCount++;
        results.push({
          mutationId,
          status: 'REJECTED',
          reason: err.message
        });
      }
    }

    return {
      reconciledAt: new Date().toISOString(),
      totalMutations: mutations.length,
      acceptedCount,
      rejectedCount,
      conflictCount,
      results
    };
  }
}

module.exports = { SyncService };
