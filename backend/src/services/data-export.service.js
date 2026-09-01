'use strict';

/**
 * EH Home — Secure User & Home Data Export Service (Phase 17)
 *
 * Excludes all sensitive secrets:
 * - Passwords and password hashes
 * - JWT secrets and refresh tokens
 * - Wi-Fi SSIDs/PSKs
 * - Factory PKI private keys
 * - Session encryption keys
 */

class DataExportService {
  constructor({
    userRepo,
    homeRepo,
    roomRepo,
    deviceRepo,
    sceneRepo,
    automationRepo,
    scheduleRepo,
    notificationRepo,
    exportRepo
  }) {
    this.userRepo = userRepo;
    this.homeRepo = homeRepo;
    this.roomRepo = roomRepo;
    this.deviceRepo = deviceRepo;
    this.sceneRepo = sceneRepo;
    this.automationRepo = automationRepo;
    this.scheduleRepo = scheduleRepo;
    this.notificationRepo = notificationRepo;
    this.exportRepo = exportRepo;
  }

  async exportUserData(userId) {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new Error(`User ${userId} not found`);

    const profile = await this.userRepo.getProfile(userId);
    const memberships = await this.homeRepo.getMembershipsForUser(userId);

    const homes = [];
    for (const m of memberships) {
      const h = await this.homeRepo.getHome(m.home_id);
      if (h) {
        const rooms = this.roomRepo ? await this.roomRepo.getRoomsByHome(h.id) : [];
        const rawAuths = this.deviceRepo ? await this.deviceRepo.getAuthorizationsByHome(h.id) : [];
        const devices = [];
        for (const auth of rawAuths) {
          const d = await this.deviceRepo.getDevice(auth.device_id);
          const room = rooms.find(r => r.id === auth.room_id);
          devices.push({
            id: auth.device_id,
            customName: auth.custom_name || (d ? d.serial_number : 'Device'),
            productVariantId: d ? d.product_variant_id : null,
            roomName: room ? room.name : null
          });
        }

        const automations = this.automationRepo ? (await this.automationRepo.findByHomeId(h.id)).map(a => ({ id: a.id, name: a.name, enabled: a.is_enabled !== undefined ? a.is_enabled : a.enabled })) : [];
        const scenes = this.sceneRepo ? (await this.sceneRepo.findByHomeId(h.id)).map(s => ({ id: s.id, name: s.name })) : [];
        const schedules = this.scheduleRepo ? (await this.scheduleRepo.findByHomeId(h.id)).map(sc => ({ id: sc.id, name: sc.name, enabled: sc.is_enabled !== undefined ? sc.is_enabled : sc.enabled, cronExpression: sc.cron_expression || sc.cronExpression })) : [];

        homes.push({
          id: h.id,
          name: h.name,
          timezone: h.timezone || 'UTC',
          role: m.role,
          rooms: rooms.map(r => ({ id: r.id, name: r.name })),
          devices,
          automations,
          scenes,
          schedules
        });
      }
    }

    let notifications = [];
    if (this.notificationRepo) {
      const rawNotifs = await this.notificationRepo.findUserNotifications(userId, { limit: 100 });
      notifications = rawNotifs.map(n => ({
        id: n.id,
        category: n.category,
        title: n.title,
        body: n.body,
        createdAt: n.created_at
      }));
    }

    const bundle = {
      exportVersion: 1,
      exportedAt: new Date().toISOString(),
      exportedBy: userId,
      scope: 'USER',
      user: {
        id: user.id,
        email: user.email,
        fullName: profile ? profile.full_name : null,
        timezone: profile ? profile.timezone : 'UTC',
        createdAt: user.created_at
      },
      homes,
      notifications
    };

    if (this.exportRepo) {
      const exportId = `exp_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      await this.exportRepo.recordExport({
        id: exportId,
        userId,
        exportScope: 'USER',
        sanitizedSummary: {
          homesCount: homes.length,
          notificationsCount: notifications.length
        }
      });
    }

    return bundle;
  }

  async exportHomeData(userId, homeId) {
    const memberships = await this.homeRepo.getMembershipsForUser(userId);
    const membership = memberships.find(m => m.home_id === homeId);
    if (!membership) {
      throw new Error(`Authorization failed: User ${userId} is not a member of home ${homeId}`);
    }

    const h = await this.homeRepo.getHome(homeId);
    if (!h) throw new Error(`Home ${homeId} not found`);

    const rooms = this.roomRepo ? await this.roomRepo.getRoomsByHome(h.id) : [];
    const rawAuths = this.deviceRepo ? await this.deviceRepo.getAuthorizationsByHome(h.id) : [];
    const devices = [];
    for (const auth of rawAuths) {
      const d = await this.deviceRepo.getDevice(auth.device_id);
      const room = rooms.find(r => r.id === auth.room_id);
      devices.push({
        id: auth.device_id,
        customName: auth.custom_name || (d ? d.serial_number : 'Device'),
        productVariantId: d ? d.product_variant_id : null,
        roomName: room ? room.name : null
      });
    }

    const automations = this.automationRepo ? (await this.automationRepo.findByHomeId(h.id)).map(a => ({ id: a.id, name: a.name, enabled: a.is_enabled !== undefined ? a.is_enabled : a.enabled })) : [];
    const scenes = this.sceneRepo ? (await this.sceneRepo.findByHomeId(h.id)).map(s => ({ id: s.id, name: s.name })) : [];
    const schedules = this.scheduleRepo ? (await this.scheduleRepo.findByHomeId(h.id)).map(sc => ({ id: sc.id, name: sc.name, enabled: sc.is_enabled !== undefined ? sc.is_enabled : sc.enabled, cronExpression: sc.cron_expression || sc.cronExpression })) : [];

    const bundle = {
      exportVersion: 1,
      exportedAt: new Date().toISOString(),
      exportedBy: userId,
      scope: 'HOME',
      homeId: h.id,
      home: {
        id: h.id,
        name: h.name,
        timezone: h.timezone || 'UTC',
        address: h.address || null,
        userRole: membership.role,
        rooms: rooms.map(r => ({ id: r.id, name: r.name })),
        devices,
        automations,
        scenes,
        schedules
      }
    };

    if (this.exportRepo) {
      const exportId = `exp_home_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
      await this.exportRepo.recordExport({
        id: exportId,
        userId,
        homeId,
        exportScope: 'HOME',
        sanitizedSummary: {
          devicesCount: devices.length,
          roomsCount: rooms.length
        }
      });
    }

    return bundle;
  }
}

module.exports = { DataExportService };
