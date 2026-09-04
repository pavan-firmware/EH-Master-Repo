/**
 * UserRepository — PHASE 2 PERSISTENCE BOUNDARY
 *
 * PHASE 2 Responsibility:
 *   - Create user records (id, email, passwordHash, emailVerified)
 *   - Look up users by id or email
 *   - Enforce unique email at the persistence layer
 *
 * AUTHENTICATION BOUNDARY — DO NOT CROSS IN THIS REPOSITORY:
 *   The following MUST NOT be implemented here. They belong to a future AuthService / AuthPhase:
 *   - Password verification (bcrypt.compare, argon2.verify, etc.)
 *   - Login session management
 *   - Access-token generation (JWT, session tokens)
 *   - Refresh-token issuance or rotation
 *   - Multi-factor authentication
 *   - Password reset flows
 *   - Keycloak/OAuth2 integration
 *
 * The passwordHash field accepted by createUser() is an ALREADY HASHED value.
 * Hashing and verification logic must live in an AuthService layer, not here.
 */
class UserRepository {
  constructor(db) {
    this.db = db;
  }

  /** Persist a new user. Caller is responsible for hashing the password before passing passwordHash. */
  async createUser({ id, email, passwordHash, emailVerified = false }) {
    // Unique email enforced at persistence layer
    const existing = await this.db.find('users', u => u.email.toLowerCase() === email.toLowerCase());
    if (existing.length > 0) {
      throw new Error(`User with email ${email} already exists`);
    }
    return this.db.insert('users', id, {
      email,
      password_hash: passwordHash,
      email_verified: emailVerified
    });
  }

  async findById(id) {
    return this.db.findById('users', id);
  }

  /** Returns user record (including password_hash for AuthService to verify). Never verifies password here. */
  async findByEmail(email) {
    const res = await this.db.find('users', u => u.email.toLowerCase() === email.toLowerCase());
    return res[0] || null;
  }

  async updatePassword(userId, passwordHash) {
    const user = await this.db.findById('users', userId);
    if (!user) throw new Error(`User ${userId} not found`);
    return this.db.update('users', userId, { password_hash: passwordHash });
  }

  async getProfile(userId) {
    const user = await this.db.findById('users', userId);
    if (!user) return null;
    const profile = await this.db.findById('user_profiles', userId);
    return {
      id: user.id,
      email: user.email,
      emailVerified: user.email_verified || false,
      fullName: profile ? profile.full_name : null,
      phoneNumber: profile ? profile.phone_number : null,
      avatarUrl: profile ? profile.avatar_url : null,
      timezone: profile ? profile.timezone : 'UTC',
      createdAt: user.created_at,
      updatedAt: profile ? profile.updated_at : user.updated_at
    };
  }

  async upsertProfile(userId, { fullName, phoneNumber, avatarUrl, timezone }) {
    const user = await this.db.findById('users', userId);
    if (!user) throw new Error(`User ${userId} not found`);
    const existing = await this.db.findById('user_profiles', userId);
    if (existing) {
      return this.db.update('user_profiles', userId, {
        full_name: fullName !== undefined ? fullName : existing.full_name,
        phone_number: phoneNumber !== undefined ? phoneNumber : existing.phone_number,
        avatar_url: avatarUrl !== undefined ? avatarUrl : existing.avatar_url,
        timezone: timezone !== undefined ? timezone : existing.timezone
      });
    }
    return this.db.insert('user_profiles', userId, {
      full_name: fullName || null,
      phone_number: phoneNumber || null,
      avatar_url: avatarUrl || null,
      timezone: timezone || 'UTC'
    });
  }

  async deleteUser(userId) {
    try { await this.db.delete('user_profiles', userId); } catch (_) {}
    const tokens = await this.db.find('refresh_tokens', t => t.user_id === userId);
    for (const t of tokens) await this.db.delete('refresh_tokens', t.id);
    return this.db.delete('users', userId);
  }
}

class HomeRepository {
  constructor(db) {
    this.db = db;
  }

  async createHome({ id, name, timezone = 'UTC', address = null, ownerId, owner_id }) {
    const targetOwnerId = ownerId || owner_id;
    const homeId = id || require('crypto').randomUUID();
    // Verify owner exists
    const owner = await this.db.findById('users', targetOwnerId);
    if (!owner) throw new Error(`Owner user ${targetOwnerId} does not exist`);

    const home = await this.db.insert('homes', homeId, {
      name,
      timezone,
      address,
      owner_id: targetOwnerId
    });

    // Auto-create owner membership
    await this.addMembership({
      id: `${homeId}_${targetOwnerId}`,
      homeId: homeId,
      userId: targetOwnerId,
      role: 'OWNER',
      acceptedAt: new Date().toISOString()
    });

    return home;
  }

  async updateHome(homeId, { name, timezone, address }) {
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} not found`);
    const updates = {};
    if (name !== undefined) updates.name = name;
    if (timezone !== undefined) updates.timezone = timezone;
    if (address !== undefined) updates.address = address;
    return this.db.update('homes', homeId, updates);
  }

  async transferOwnership(homeId, currentOwnerId, newOwnerId) {
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} not found`);
    if (home.owner_id !== currentOwnerId) {
      throw new Error(`User ${currentOwnerId} is not the current owner of home ${homeId}`);
    }

    const memberships = await this.getMembershipsForHome(homeId);
    const newOwnerMembership = memberships.find(m => m.user_id === newOwnerId);
    if (!newOwnerMembership) {
      throw new Error(`Target user ${newOwnerId} is not a member of home ${homeId}`);
    }

    await this.db.update('homes', homeId, { owner_id: newOwnerId });
    await this.updateMembershipRole(homeId, newOwnerId, 'OWNER');
    await this.updateMembershipRole(homeId, currentOwnerId, 'ADMIN');

    return this.getHome(homeId);
  }

  async deleteHome(homeId) {
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} not found`);

    const memberships = await this.getMembershipsForHome(homeId);
    for (const m of memberships) await this.db.delete('home_memberships', m.id);

    const invites = await this.db.find('home_invitations', i => i.home_id === homeId);
    for (const i of invites) await this.db.delete('home_invitations', i.id);

    const auths = await this.db.find('device_authorizations', a => a.home_id === homeId);
    for (const a of auths) await this.db.delete('device_authorizations', a.id);

    const rooms = await this.db.find('rooms', r => r.home_id === homeId);
    for (const r of rooms) await this.db.delete('rooms', r.id);

    const floors = await this.db.find('floors', f => f.home_id === homeId);
    for (const f of floors) await this.db.delete('floors', f.id);

    const scenes = await this.db.find('scenes', s => s.home_id === homeId);
    for (const s of scenes) await this.db.delete('scenes', s.id);

    const automations = await this.db.find('automations', a => a.home_id === homeId);
    for (const a of automations) await this.db.delete('automations', a.id);

    const schedules = await this.db.find('schedules', s => s.home_id === homeId);
    for (const s of schedules) await this.db.delete('schedules', s.id);

    return this.db.delete('homes', homeId);
  }

  async addMembership({ id, homeId, home_id, userId, user_id, role, acceptedAt = null }) {
    const targetUserId = userId || user_id;
    const targetHomeId = homeId || home_id;
    const membershipId = id || `${targetHomeId}_${targetUserId}`;
    const user = await this.db.findById('users', targetUserId);
    if (!user) throw new Error(`User ${targetUserId} does not exist`);
    const home = await this.db.findById('homes', targetHomeId);
    if (!home) throw new Error(`Home ${targetHomeId} does not exist`);

    const existing = await this.db.find('home_memberships', m => m.home_id === targetHomeId && m.user_id === targetUserId);
    if (existing.length > 0) {
      throw new Error(`Membership for user ${targetUserId} in home ${targetHomeId} already exists`);
    }

    return this.db.insert('home_memberships', membershipId, {
      home_id: targetHomeId,
      user_id: targetUserId,
      role,
      invited_at: new Date().toISOString(),
      accepted_at: acceptedAt
    });
  }

  async getMembershipsForUser(userId) {
    return this.db.find('home_memberships', m => m.user_id === userId);
  }

  async getMembershipsForHome(homeId) {
    return this.db.find('home_memberships', m => m.home_id === homeId);
  }

  async updateMembershipRole(homeId, userId, role) {
    const existing = await this.db.find('home_memberships', m => m.home_id === homeId && m.user_id === userId);
    if (existing.length === 0) {
      throw new Error(`Membership for user ${userId} in home ${homeId} not found`);
    }
    return this.db.update('home_memberships', existing[0].id, { role });
  }

  async removeMembership(homeId, userId) {
    const existing = await this.db.find('home_memberships', m => m.home_id === homeId && m.user_id === userId);
    if (existing.length === 0) {
      throw new Error(`Membership for user ${userId} in home ${homeId} not found`);
    }
    return this.db.delete('home_memberships', existing[0].id);
  }

  async getHome(homeId) {
    return this.db.findById('homes', homeId);
  }
}

class RoomRepository {
  constructor(db) {
    this.db = db;
  }

  async createFloor({ id, homeId, name, level = 0 }) {
    const floorId = id || require('crypto').randomUUID();
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);
    return this.db.insert('floors', floorId, { home_id: homeId, name, level });
  }

  async getFloor(floorId) {
    return this.db.findById('floors', floorId);
  }

  async getFloorsByHome(homeId) {
    const floors = await this.db.find('floors', f => f.home_id === homeId);
    return floors.sort((a, b) => a.level - b.level);
  }

  async renameFloor(floorId, name) {
    const floor = await this.db.findById('floors', floorId);
    if (!floor) throw new Error(`Floor ${floorId} does not exist`);
    return this.db.update('floors', floorId, { name });
  }

  async deleteFloor(floorId) {
    const floor = await this.db.findById('floors', floorId);
    if (!floor) throw new Error(`Floor ${floorId} does not exist`);
    return this.db.delete('floors', floorId);
  }

  async createRoom({ id, homeId, home_id, floorId = null, floor_id = null, name, iconKey = 'default', icon_key = 'default', sortOrder = 0, sort_order = 0 }) {
    const targetHomeId = homeId || home_id;
    const targetFloorId = floorId || floor_id;
    const roomId = id || require('crypto').randomUUID();
    const home = await this.db.findById('homes', targetHomeId);
    if (!home) throw new Error(`Home ${targetHomeId} does not exist`);
    if (targetFloorId) {
      const floor = await this.db.findById('floors', targetFloorId);
      if (!floor) throw new Error(`Floor ${targetFloorId} does not exist`);
      if (floor.home_id !== targetHomeId) {
        throw new Error(`Floor ${targetFloorId} belongs to home ${floor.home_id}, not home ${targetHomeId}`);
      }
    }
    return this.db.insert('rooms', roomId, {
      home_id: targetHomeId,
      floor_id: targetFloorId,
      name,
      icon_key: iconKey || icon_key,
      sort_order: sortOrder || sort_order
    });
  }

  async getRoom(roomId) {
    return this.db.findById('rooms', roomId);
  }

  async getRoomsByHome(homeId) {
    return this.db.find('rooms', r => r.home_id === homeId);
  }

  async renameRoom(roomId, name) {
    const room = await this.db.findById('rooms', roomId);
    if (!room) throw new Error(`Room ${roomId} does not exist`);
    return this.db.update('rooms', roomId, { name });
  }

  async moveRoom(roomId, floorId) {
    const room = await this.db.findById('rooms', roomId);
    if (!room) throw new Error(`Room ${roomId} does not exist`);
    if (floorId) {
      const floor = await this.db.findById('floors', floorId);
      if (!floor) throw new Error(`Floor ${floorId} does not exist`);
      if (floor.home_id !== room.home_id) {
        throw new Error(`Floor ${floorId} belongs to home ${floor.home_id}, but room belongs to home ${room.home_id}`);
      }
    }
    return this.db.update('rooms', roomId, { floor_id: floorId });
  }

  async updateRoom(roomId, updates = {}) {
    const room = await this.db.findById('rooms', roomId);
    if (!room) throw new Error(`Room ${roomId} does not exist`);
    const cleanUpdates = {};
    if (updates.name !== undefined) cleanUpdates.name = updates.name;
    if (updates.floorId !== undefined) cleanUpdates.floor_id = updates.floorId;
    if (updates.floor_id !== undefined) cleanUpdates.floor_id = updates.floor_id;
    if (updates.iconKey !== undefined) cleanUpdates.icon_key = updates.iconKey;
    if (updates.icon_key !== undefined) cleanUpdates.icon_key = updates.icon_key;
    if (updates.sortOrder !== undefined) cleanUpdates.sort_order = updates.sortOrder;
    if (updates.displayOrder !== undefined) cleanUpdates.sort_order = updates.displayOrder;
    if (updates.sort_order !== undefined) cleanUpdates.sort_order = updates.sort_order;
    return this.db.update('rooms', roomId, cleanUpdates);
  }

  async deleteRoom(roomId) {
    const room = await this.db.findById('rooms', roomId);
    if (!room) throw new Error(`Room ${roomId} does not exist`);
    return this.db.delete('rooms', roomId);
  }
}

class ProductRepository {
  constructor(db) {
    this.db = db;
  }

  async createFamily({ id, slug, displayName, description = null }) {
    return this.db.insert('product_families', id, { slug, display_name: displayName, description });
  }

  async createProduct({ id, familyId, displayName, description = null, status = 'PUBLISHED' }) {
    const family = await this.db.findById('product_families', familyId);
    if (!family) throw new Error(`Family ${familyId} does not exist`);
    return this.db.insert('products', id, {
      family_id: familyId,
      display_name: displayName,
      description,
      status
    });
  }

  async createVariant(variantData) {
    const product = await this.db.findById('products', variantData.productId);
    if (!product) throw new Error(`Product ${variantData.productId} does not exist`);

    return this.db.insert('product_variants', variantData.id, {
      product_id: variantData.productId,
      variant_slug: variantData.variantSlug,
      display_name: variantData.displayName,
      channel_count: variantData.channelCount,
      channels: variantData.channels,
      hardware_profile: variantData.hardwareProfile,
      connectivity_profile: variantData.connectivityProfile,
      capabilities: variantData.capabilities,
      electrical_specifications: variantData.electricalSpecifications,
      firmware_family: variantData.firmwareFamily,
      supported_hardware_revisions: variantData.supportedHardwareRevisions
    });
  }

  async getVariant(id) {
    return this.db.findById('product_variants', id);
  }
}

class CapabilityRepository {
  constructor(db) {
    this.db = db;
  }

  async registerCapability(cap) {
    return this.db.insert('capabilities', cap.capabilityId, {
      capability_id: cap.capabilityId,
      version: cap.version || 1,
      display_name: cap.displayName,
      description: cap.description,
      properties: cap.properties || {},
      commands: cap.commands || [],
      events: cap.events || [],
      telemetry_fields: cap.telemetryFields || [],
      ui_component_hint: cap.uiComponentHint,
      automation_triggers: cap.automationTriggers || [],
      automation_actions: cap.automationActions || []
    });
  }

  async getCapability(id) {
    return this.db.findById('capabilities', id);
  }
}

class DeviceRepository {
  constructor(db) {
    this.db = db;
  }

  async registerDevice({ deviceId, serialNumber, productVariantId, hardwareRevision, firmwareFamily, firmwareVersion = '1.0.0' }) {
    const variant = await this.db.findById('product_variants', productVariantId);
    if (!variant) throw new Error(`Product variant ${productVariantId} does not exist`);

    const existingSerial = await this.db.find('devices', d => d.serial_number === serialNumber);
    if (existingSerial.length > 0) throw new Error(`Device with serial ${serialNumber} already registered`);

    const dev = await this.db.insert('devices', deviceId, {
      serial_number: serialNumber,
      product_variant_id: productVariantId,
      hardware_revision: hardwareRevision,
      firmware_family: firmwareFamily,
      firmware_version: firmwareVersion
    });

    // Initialize empty device state & channel state
    await this.db.insert('device_state', deviceId, {
      connection_state: 'OFFLINE',
      last_seen_at: null,
      last_command_id: null,
      last_event_id: null
    });

    const channelCount = variant.channel_count || 1;
    for (let ch = 1; ch <= channelCount; ch++) {
      await this.db.insert('channel_state', `${deviceId}_ch_${ch}`, {
        device_id: deviceId,
        channel_index: ch,
        desired_state: { power: false },
        reported_state: { power: false },
        confidence: 'UNKNOWN'
      });
    }

    return dev;
  }

  async claimDevice({ deviceId, device_id, homeId, home_id, roomId = null, room_id = null, customName, custom_name, channelLabels = {}, channel_labels = {}, claimedByUserId, claimed_by_user_id }) {
    const targetDevId = deviceId || device_id;
    const targetHomeId = homeId || home_id;
    const targetRoomId = roomId || room_id;
    const dev = await this.db.findById('devices', targetDevId);
    if (!dev) throw new Error(`Device ${targetDevId} does not exist`);
    const home = await this.db.findById('homes', targetHomeId);
    if (!home) throw new Error(`Home ${targetHomeId} does not exist`);

    if (targetRoomId) {
      const room = await this.db.findById('rooms', targetRoomId);
      if (!room) throw new Error(`Room ${targetRoomId} does not exist`);
      if (room.home_id !== targetHomeId) {
        throw new Error(`Room ${targetRoomId} belongs to home ${room.home_id}, not home ${targetHomeId}`);
      }
    }

    const existingAuth = await this.db.findById('device_authorizations', targetDevId);
    if (existingAuth) throw new Error(`Device ${targetDevId} is already claimed by home ${existingAuth.home_id}`);

    return this.db.insert('device_authorizations', targetDevId, {
      device_id: targetDevId,
      home_id: targetHomeId,
      room_id: targetRoomId,
      custom_name: customName || custom_name || dev.serial_number,
      channel_labels: channelLabels || channel_labels,
      claimed_by_user_id: claimedByUserId || claimed_by_user_id || null,
      claimed_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });
  }

  async updateDeviceAuthorization(deviceId, updates = {}) {
    const existing = await this.db.findById('device_authorizations', deviceId);
    if (!existing) throw new Error(`Device authorization for ${deviceId} not found`);

    const cleanUpdates = {};
    if (updates.homeId !== undefined) cleanUpdates.home_id = updates.homeId;
    if (updates.home_id !== undefined) cleanUpdates.home_id = updates.home_id;
    if (updates.roomId !== undefined) cleanUpdates.room_id = updates.roomId;
    if (updates.room_id !== undefined) cleanUpdates.room_id = updates.room_id;
    if (updates.customName !== undefined) cleanUpdates.custom_name = updates.customName;
    if (updates.custom_name !== undefined) cleanUpdates.custom_name = updates.custom_name;
    if (updates.channelLabels !== undefined) cleanUpdates.channel_labels = updates.channelLabels;
    if (updates.channel_labels !== undefined) cleanUpdates.channel_labels = updates.channel_labels;
    if (updates.channelConfigs !== undefined) cleanUpdates.channel_configs = updates.channelConfigs;
    if (updates.channel_configs !== undefined) cleanUpdates.channel_configs = updates.channel_configs;

    return this.db.update('device_authorizations', deviceId, cleanUpdates);
  }

  async removeDeviceAuthorization(deviceId) {
    const existing = await this.db.findById('device_authorizations', deviceId);
    if (!existing) throw new Error(`Device authorization for ${deviceId} not found`);
    return this.db.delete('device_authorizations', deviceId);
  }

  async getAuthorizationsByHome(homeId) {
    return this.db.find('device_authorizations', a => a.home_id === homeId);
  }

  async getDevicesByHome(homeId) {
    const auths = await this.getAuthorizationsByHome(homeId);
    const devices = [];
    const seen = new Set();
    for (const a of auths) {
      const dev = await this.db.findById('devices', a.device_id);
      if (dev) {
        devices.push({ ...dev, ...a, id: dev.id, homeId: a.home_id });
        seen.add(dev.id);
      }
    }
    const directDevs = await this.db.find('devices', d => d.home_id === homeId || d.homeId === homeId);
    for (const dev of directDevs) {
      if (!seen.has(dev.id)) {
        devices.push({ ...dev, id: dev.id, homeId: dev.home_id || dev.homeId });
        seen.add(dev.id);
      }
    }
    return devices;
  }

  async findByHomeId(homeId) {
    return this.getDevicesByHome(homeId);
  }

  async getDevicesByRoom(roomId) {
    const auths = await this.db.find('device_authorizations', a => a.room_id === roomId);
    const devices = [];
    const seen = new Set();
    for (const a of auths) {
      const dev = await this.db.findById('devices', a.device_id);
      if (dev) {
        devices.push({ ...dev, ...a, id: dev.id });
        seen.add(dev.id);
      }
    }
    const directDevs = await this.db.find('devices', d => d.room_id === roomId || d.roomId === roomId);
    for (const dev of directDevs) {
      if (!seen.has(dev.id)) {
        devices.push({ ...dev, id: dev.id });
        seen.add(dev.id);
      }
    }
    return devices;
  }

  async getDevice(deviceId) {
    return this.db.findById('devices', deviceId);
  }

  async findById(deviceId) {
    return this.getDevice(deviceId);
  }

  async updateDeviceFirmwareVersion(deviceId, version) {
    return this.db.update('devices', deviceId, { firmware_version: version });
  }

  async createDevice(params) {
    return this.registerDevice({
      deviceId: params.id || params.deviceId || require('crypto').randomUUID(),
      serialNumber: params.serial_number || params.serialNumber,
      productVariantId: params.product_variant_id || params.productVariantId,
      hardwareRevision: params.hardware_revision || params.hardwareRevision,
      firmwareFamily: params.firmware_family || params.firmwareFamily,
      firmwareVersion: params.firmware_version || params.firmwareVersion || '1.0.0'
    });
  }

  async getDeviceAuthorization(deviceId) {
    return this.db.findById('device_authorizations', deviceId);
  }
}

class DeviceStateRepository {
  constructor(db) {
    this.db = db;
  }

  async updateDeviceConnection(deviceId, connectionState) {
    return this.db.update('device_state', deviceId, {
      connection_state: connectionState,
      last_seen_at: new Date().toISOString()
    });
  }

  async updateChannelState(deviceId, channelIndex, { desiredState, reportedState, confidence }) {
    const key = `${deviceId}_ch_${channelIndex}`;
    const updates = {};
    if (desiredState !== undefined) updates.desired_state = desiredState;
    if (reportedState !== undefined) updates.reported_state = reportedState;
    if (confidence !== undefined) updates.confidence = confidence;

    return this.db.update('channel_state', key, updates);
  }

  async getFullState(deviceId) {
    const devState = await this.db.findById('device_state', deviceId);
    if (!devState) return null;
    const channels = await this.db.find('channel_state', c => c.device_id === deviceId);
    return {
      schemaVersion: 1,
      deviceId,
      connectionState: devState.connection_state,
      channels: channels.sort((a, b) => a.channel_index - b.channel_index).map(c => ({
        schemaVersion: 1,
        channelIndex: c.channel_index,
        desiredState: c.desired_state,
        reportedState: c.reported_state,
        confidence: c.confidence,
        updatedAt: c.updated_at || devState.created_at
      })),
      lastSeenAt: devState.last_seen_at,
      updatedAt: devState.updated_at || devState.created_at
    };
  }
}

class CommandRepository {
  constructor(db) {
    this.db = db;
  }

  async recordCommand(cmd) {
    // Enforce idempotency
    const existing = await this.db.find('device_commands', c => c.device_id === cmd.deviceId && c.idempotency_key === cmd.idempotencyKey);
    if (existing.length > 0) {
      return existing[0]; // Return existing without duplicate insert
    }

    return this.db.insert('device_commands', cmd.commandId, {
      device_id: cmd.deviceId,
      channel_index: cmd.channelIndex,
      action: cmd.action,
      params: cmd.params,
      idempotency_key: cmd.idempotencyKey,
      source: cmd.source,
      status: 'CREATED',
      expires_at: cmd.expiresAt
    });
  }

  async updateStatus(commandId, status, failureReason = null) {
    return this.db.update('device_commands', commandId, {
      status,
      failure_reason: failureReason,
      completed_at: new Date().toISOString()
    });
  }

  async getCommand(commandId) {
    return this.db.findById('device_commands', commandId);
  }
}

class EventRepository {
  constructor(db) {
    this.db = db;
  }

  async recordEvent(evt) {
    return this.db.insert('device_events', evt.eventId, {
      device_id: evt.deviceId,
      channel_index: evt.channelIndex,
      event_type: evt.eventType,
      source: evt.source,
      payload: evt.payload,
      sequence_number: evt.sequenceNumber,
      timestamp: evt.timestamp
    });
  }

  async getEventsByDevice(deviceId, limit = 50) {
    const events = await this.db.find('device_events', e => e.device_id === deviceId);
    return events.sort((a, b) => b.sequence_number - a.sequence_number).slice(0, limit);
  }
}

class AuditRepository {
  constructor(db) {
    this.db = db;
  }

  async log({ id, actorUserId = null, deviceId = null, homeId = null, action, payload = {}, ipAddress = null, correlationId = null }) {
    return this.db.insert('audit_logs', id, {
      actor_user_id: actorUserId,
      device_id: deviceId,
      home_id: homeId,
      action,
      payload,
      ip_address: ipAddress,
      correlation_id: correlationId
    });
  }
}

class OutboxRepository {
  constructor(db) {
    this.db = db;
  }

  async enqueue({ id, eventType, aggregateType, aggregateId, payload }) {
    return this.db.insert('outbox', id, {
      event_type: eventType,
      aggregate_type: aggregateType,
      aggregate_id: aggregateId,
      payload,
      status: 'PENDING',
      attempt_count: 0
    });
  }

  async fetchPending(limit = 10) {
    const pending = await this.db.find('outbox', o => o.status === 'PENDING');
    return pending.slice(0, limit);
  }

  async markPublished(id) {
    return this.db.update('outbox', id, {
      status: 'PUBLISHED',
      processed_at: new Date().toISOString()
    });
  }
}

class ProvisioningSessionRepository {
  constructor(db) {
    this.db = db;
  }

  async createSession({ id, deviceId, appChallenge, deviceChallenge, expiresAt, status = 'CREATED' }) {
    // Single active commissioning session rule per device
    const active = await this.db.find('provisioning_sessions', s => s.device_id === deviceId && s.status !== 'COMPLETED' && s.status !== 'EXPIRED' && s.status !== 'ABORTED');
    for (const s of active) {
      await this.db.update('provisioning_sessions', s.id, { status: 'EXPIRED', ended_at: new Date().toISOString() });
    }

    return this.db.insert('provisioning_sessions', id, {
      device_id: deviceId,
      app_challenge: appChallenge,
      device_challenge: deviceChallenge,
      expires_at: expiresAt,
      status,
      created_at: new Date().toISOString()
    });
  }

  async getSession(id) {
    return this.db.findById('provisioning_sessions', id);
  }

  async getActiveSessionForDevice(deviceId) {
    const sessions = await this.db.find('provisioning_sessions', s => s.device_id === deviceId && s.status !== 'COMPLETED' && s.status !== 'EXPIRED' && s.status !== 'ABORTED');
    return sessions.length > 0 ? sessions[0] : null;
  }

  async updateStatus(id, status, extra = {}) {
    const existing = await this.db.findById('provisioning_sessions', id);
    if (!existing) throw new Error(`Provisioning session ${id} not found`);
    return this.db.update('provisioning_sessions', id, { status, ...extra, updated_at: new Date().toISOString() });
  }
}

class RefreshTokenRepository {
  constructor(db) {
    this.db = db;
  }

  async createToken({ id, userId, tokenHash, expiresAt, deviceName = null, ipAddress = null, userAgent = null }) {
    return this.db.insert('refresh_tokens', id, {
      user_id: userId,
      token_hash: tokenHash,
      expires_at: expiresAt,
      device_name: deviceName,
      ip_address: ipAddress,
      user_agent: userAgent
    });
  }

  async findByTokenHash(tokenHash) {
    const tokens = await this.db.find('refresh_tokens', t => t.token_hash === tokenHash);
    return tokens.length > 0 ? tokens[0] : null;
  }

  async findById(id) {
    return this.db.findById('refresh_tokens', id);
  }

  async deleteToken(id) {
    return this.db.delete('refresh_tokens', id);
  }

  async deleteTokensForUser(userId) {
    const userTokens = await this.db.find('refresh_tokens', t => t.user_id === userId);
    for (const t of userTokens) {
      await this.db.delete('refresh_tokens', t.id);
    }
  }

  async listActiveSessions(userId) {
    const now = new Date().toISOString();
    const tokens = await this.db.find('refresh_tokens', t => t.user_id === userId && t.expires_at > now);
    return tokens.map(t => ({
      id: t.id,
      userId: t.user_id,
      deviceName: t.device_name || 'Mobile App',
      ipAddress: t.ip_address || '127.0.0.1',
      userAgent: t.user_agent || 'Flutter / EH Home Client',
      createdAt: t.created_at,
      expiresAt: t.expires_at
    }));
  }

  async revokeSession(sessionId, userId) {
    const token = await this.db.findById('refresh_tokens', sessionId);
    if (!token || token.user_id !== userId) return false;
    return this.db.delete('refresh_tokens', sessionId);
  }

  async revokeAllExcept(userId, keepSessionId = null) {
    const tokens = await this.db.find('refresh_tokens', t => t.user_id === userId);
    for (const t of tokens) {
      if (t.id !== keepSessionId) {
        await this.db.delete('refresh_tokens', t.id);
      }
    }
  }
}

class InvitationRepository {
  constructor(db) {
    this.db = db;
  }

  async createInvitation({ id, homeId, inviterUserId, inviteeEmail, role = 'MEMBER', inviteCode, expiresAt }) {
    const existing = await this.db.find('home_invitations', i =>
      i.home_id === homeId &&
      i.invitee_email.toLowerCase() === inviteeEmail.toLowerCase() &&
      i.status === 'PENDING'
    );
    if (existing.length > 0) {
      throw new Error(`Pending invitation for ${inviteeEmail} already exists for this home`);
    }

    return this.db.insert('home_invitations', id, {
      home_id: homeId,
      inviter_user_id: inviterUserId,
      invitee_email: inviteeEmail.toLowerCase(),
      role: role.toUpperCase(),
      invite_code: inviteCode,
      status: 'PENDING',
      expires_at: expiresAt,
      accepted_at: null
    });
  }

  async findById(id) {
    return this.db.findById('home_invitations', id);
  }

  async findByCode(inviteCode) {
    const invites = await this.db.find('home_invitations', i => i.invite_code === inviteCode);
    return invites[0] || null;
  }

  async findPendingByHome(homeId) {
    const now = new Date().toISOString();
    return this.db.find('home_invitations', i => i.home_id === homeId && i.status === 'PENDING' && i.expires_at > now);
  }

  async findPendingByEmail(email) {
    const now = new Date().toISOString();
    return this.db.find('home_invitations', i => i.invitee_email.toLowerCase() === email.toLowerCase() && i.status === 'PENDING' && i.expires_at > now);
  }

  async updateStatus(id, status, acceptedAt = null) {
    const updates = { status };
    if (acceptedAt) updates.accepted_at = acceptedAt;
    return this.db.update('home_invitations', id, updates);
  }

  async delete(id) {
    return this.db.delete('home_invitations', id);
  }
}

/**
 * SceneRepository — PHASE 10 PERSISTENCE
 */
class SceneRepository {
  constructor(db) {
    this.db = db;
  }

  async createScene({ id, homeId, name, description = null, icon = 'scene_default', isActive = false, actions = [] }) {
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    return this.db.insert('scenes', id, {
      home_id: homeId,
      name,
      description,
      icon,
      is_active: isActive,
      actions: Array.isArray(actions) ? actions : []
    });
  }

  async findById(id) {
    return this.db.findById('scenes', id);
  }

  async findByHomeId(homeId) {
    return this.db.find('scenes', s => s.home_id === homeId);
  }

  async findActive(homeId) {
    return this.db.find('scenes', s => s.home_id === homeId && s.is_active === true);
  }

  async updateScene(id, updates) {
    const cleanUpdates = {};
    if (updates.name !== undefined) cleanUpdates.name = updates.name;
    if (updates.description !== undefined) cleanUpdates.description = updates.description;
    if (updates.icon !== undefined) cleanUpdates.icon = updates.icon;
    if (updates.isActive !== undefined) cleanUpdates.is_active = updates.isActive;
    if (updates.is_active !== undefined) cleanUpdates.is_active = updates.is_active;
    if (updates.actions !== undefined) cleanUpdates.actions = updates.actions;
    return this.db.update('scenes', id, cleanUpdates);
  }

  async deleteScene(id) {
    return this.db.delete('scenes', id);
  }
}

/**
 * AutomationRepository — PHASE 10 PERSISTENCE
 */
class AutomationRepository {
  constructor(db) {
    this.db = db;
  }

  async createAutomation({
    id,
    homeId,
    name,
    description = null,
    isEnabled = true,
    triggerType,
    triggerConfig = {},
    conditions = [],
    actions = [],
    timezone = 'UTC'
  }) {
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    return this.db.insert('automations', id, {
      home_id: homeId,
      name,
      description,
      is_enabled: isEnabled,
      trigger_type: triggerType,
      trigger_config: triggerConfig || {},
      conditions: Array.isArray(conditions) ? conditions : [],
      actions: Array.isArray(actions) ? actions : [],
      timezone: timezone || 'UTC'
    });
  }

  async findById(id) {
    return this.db.findById('automations', id);
  }

  async findByHomeId(homeId) {
    return this.db.find('automations', a => a.home_id === homeId);
  }

  async findEnabled(homeId) {
    return this.db.find('automations', a => a.home_id === homeId && a.is_enabled === true);
  }

  async findByTriggerType(triggerType) {
    return this.db.find('automations', a => a.trigger_type === triggerType && a.is_enabled === true);
  }

  async updateAutomation(id, updates) {
    const cleanUpdates = {};
    if (updates.name !== undefined) cleanUpdates.name = updates.name;
    if (updates.description !== undefined) cleanUpdates.description = updates.description;
    if (updates.isEnabled !== undefined) cleanUpdates.is_enabled = updates.isEnabled;
    if (updates.is_enabled !== undefined) cleanUpdates.is_enabled = updates.is_enabled;
    if (updates.triggerType !== undefined) cleanUpdates.trigger_type = updates.triggerType;
    if (updates.trigger_type !== undefined) cleanUpdates.trigger_type = updates.trigger_type;
    if (updates.triggerConfig !== undefined) cleanUpdates.trigger_config = updates.triggerConfig;
    if (updates.trigger_config !== undefined) cleanUpdates.trigger_config = updates.trigger_config;
    if (updates.conditions !== undefined) cleanUpdates.conditions = updates.conditions;
    if (updates.actions !== undefined) cleanUpdates.actions = updates.actions;
    if (updates.timezone !== undefined) cleanUpdates.timezone = updates.timezone;
    return this.db.update('automations', id, cleanUpdates);
  }

  async deleteAutomation(id) {
    return this.db.delete('automations', id);
  }
}

/**
 * ScheduleRepository — PHASE 10 PERSISTENCE
 */
class ScheduleRepository {
  constructor(db) {
    this.db = db;
  }

  async createSchedule({
    id,
    homeId,
    automationId = null,
    sceneId = null,
    name,
    scheduleType = 'daily',
    cronExpression = null,
    timeOfDay = null,
    daysOfWeek = [],
    timezone = 'UTC',
    isEnabled = true,
    nextRunAt = null,
    lastRunAt = null
  }) {
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    return this.db.insert('schedules', id, {
      home_id: homeId,
      automation_id: automationId,
      scene_id: sceneId,
      name,
      schedule_type: scheduleType,
      cron_expression: cronExpression,
      time_of_day: timeOfDay,
      days_of_week: Array.isArray(daysOfWeek) ? daysOfWeek : [],
      timezone: timezone || 'UTC',
      is_enabled: isEnabled,
      next_run_at: nextRunAt ? new Date(nextRunAt).toISOString() : null,
      last_run_at: lastRunAt ? new Date(lastRunAt).toISOString() : null
    });
  }

  async findById(id) {
    return this.db.findById('schedules', id);
  }

  async findByHomeId(homeId) {
    return this.db.find('schedules', s => s.home_id === homeId);
  }

  async findDueSchedules(asOfTimestamp = new Date()) {
    const asOfIso = new Date(asOfTimestamp).toISOString();
    return this.db.find('schedules', s => s.is_enabled === true && s.next_run_at && s.next_run_at <= asOfIso);
  }

  async updateSchedule(id, updates) {
    const cleanUpdates = {};
    if (updates.name !== undefined) cleanUpdates.name = updates.name;
    if (updates.scheduleType !== undefined) cleanUpdates.schedule_type = updates.scheduleType;
    if (updates.schedule_type !== undefined) cleanUpdates.schedule_type = updates.schedule_type;
    if (updates.cronExpression !== undefined) cleanUpdates.cron_expression = updates.cronExpression;
    if (updates.cron_expression !== undefined) cleanUpdates.cron_expression = updates.cron_expression;
    if (updates.timeOfDay !== undefined) cleanUpdates.time_of_day = updates.timeOfDay;
    if (updates.time_of_day !== undefined) cleanUpdates.time_of_day = updates.time_of_day;
    if (updates.daysOfWeek !== undefined) cleanUpdates.days_of_week = updates.daysOfWeek;
    if (updates.days_of_week !== undefined) cleanUpdates.days_of_week = updates.days_of_week;
    if (updates.timezone !== undefined) cleanUpdates.timezone = updates.timezone;
    if (updates.isEnabled !== undefined) cleanUpdates.is_enabled = updates.isEnabled;
    if (updates.is_enabled !== undefined) cleanUpdates.is_enabled = updates.is_enabled;
    if (updates.nextRunAt !== undefined) cleanUpdates.next_run_at = updates.nextRunAt ? new Date(updates.nextRunAt).toISOString() : null;
    if (updates.next_run_at !== undefined) cleanUpdates.next_run_at = updates.next_run_at ? new Date(updates.next_run_at).toISOString() : null;
    if (updates.lastRunAt !== undefined) cleanUpdates.last_run_at = updates.lastRunAt ? new Date(updates.lastRunAt).toISOString() : null;
    if (updates.last_run_at !== undefined) cleanUpdates.last_run_at = updates.last_run_at ? new Date(updates.last_run_at).toISOString() : null;
    return this.db.update('schedules', id, cleanUpdates);
  }

  async updateRunTimestamp(id, { lastRunAt, nextRunAt }) {
    const updates = {};
    if (lastRunAt) updates.last_run_at = new Date(lastRunAt).toISOString();
    if (nextRunAt) updates.next_run_at = new Date(nextRunAt).toISOString();
    return this.db.update('schedules', id, updates);
  }

  async deleteSchedule(id) {
    return this.db.delete('schedules', id);
  }
}

/**
 * AutomationExecutionLogRepository — PHASE 10 PERSISTENCE
 */
class AutomationExecutionLogRepository {
  constructor(db) {
    this.db = db;
  }

  async createLog({
    id,
    homeId,
    automationId = null,
    sceneId = null,
    scheduleId = null,
    triggerSource,
    status,
    executionIdentity,
    targetResults = [],
    errorMessage = null,
    durationMs = 0,
    executedAt = new Date().toISOString()
  }) {
    return this.db.insert('automation_execution_logs', id, {
      home_id: homeId,
      automation_id: automationId,
      scene_id: sceneId,
      schedule_id: scheduleId,
      trigger_source: triggerSource,
      status,
      execution_identity: executionIdentity,
      target_results: Array.isArray(targetResults) ? targetResults : [],
      error_message: errorMessage,
      duration_ms: durationMs,
      executed_at: executedAt
    });
  }

  async findById(id) {
    return this.db.findById('automation_execution_logs', id);
  }

  async findByAutomationId(automationId, limit = 50) {
    const logs = await this.db.find('automation_execution_logs', l => l.automation_id === automationId);
    return logs.sort((a, b) => new Date(b.executed_at) - new Date(a.executed_at)).slice(0, limit);
  }

  async findByHomeId(homeId, limit = 50) {
    const logs = await this.db.find('automation_execution_logs', l => l.home_id === homeId);
    return logs.sort((a, b) => new Date(b.executed_at) - new Date(a.executed_at)).slice(0, limit);
  }

  async findRecent(limit = 50) {
    const logs = await this.db.find('automation_execution_logs', () => true);
    return logs.sort((a, b) => new Date(b.executed_at) - new Date(a.executed_at)).slice(0, limit);
  }
}

// -----------------------------------------------------------------------------
// 15. Device Activity Log Repository (Phase 11)
// -----------------------------------------------------------------------------
class DeviceActivityLogRepository {
  constructor(db) {
    this.db = db;
  }

  async createLog({ id, homeId, deviceId, eventType, severity = 'info', message, correlationId = null, details = {}, createdAt = new Date().toISOString() }) {
    if (!id || !deviceId || !eventType || !message) {
      throw new Error('id, deviceId, eventType, and message are required for device activity log');
    }
    return this.db.insert('device_activity_logs', id, {
      home_id: homeId,
      device_id: deviceId,
      event_type: eventType,
      severity,
      message,
      correlation_id: correlationId,
      details: typeof details === 'object' ? details : {},
      created_at: createdAt
    });
  }

  async findById(id) {
    return this.db.findById('device_activity_logs', id);
  }

  async findByDeviceId(deviceId, limit = 50, eventType = null) {
    const logs = await this.db.find('device_activity_logs', l => {
      if (l.device_id !== deviceId) return false;
      if (eventType && l.event_type !== eventType) return false;
      return true;
    });
    return logs.sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).slice(0, limit);
  }

  async findByHomeId(homeId, limit = 50, eventType = null) {
    const logs = await this.db.find('device_activity_logs', l => {
      if (l.home_id !== homeId) return false;
      if (eventType && l.event_type !== eventType) return false;
      return true;
    });
    return logs.sort((a, b) => new Date(b.created_at) - new Date(a.created_at)).slice(0, limit);
  }

  async findByCorrelationId(correlationId) {
    return this.db.find('device_activity_logs', l => l.correlation_id === correlationId);
  }
}

// -----------------------------------------------------------------------------
// 16. Device Health Repository (Phase 11)
// -----------------------------------------------------------------------------
class DeviceHealthRepository {
  constructor(db) {
    this.db = db;
  }

  async upsertMetrics({
    id,
    deviceId,
    homeId,
    healthStatus = 'UNKNOWN',
    lastSeenAt = new Date().toISOString(),
    uptimeSeconds = 0,
    rssi = null,
    ipAddress = null,
    commandSuccessCount = 0,
    commandFailureCount = 0,
    lastErrorMessage = null,
    lastErrorAt = null
  }) {
    const existing = await this.findByDeviceId(deviceId);
    if (existing) {
      return this.db.update('device_health_metrics', existing.id, {
        home_id: homeId || existing.home_id,
        health_status: healthStatus || existing.health_status,
        last_seen_at: lastSeenAt || existing.last_seen_at,
        uptime_seconds: uptimeSeconds ?? existing.uptime_seconds,
        rssi: rssi ?? existing.rssi,
        ip_address: ipAddress || existing.ip_address,
        command_success_count: commandSuccessCount ?? existing.command_success_count,
        command_failure_count: commandFailureCount ?? existing.command_failure_count,
        last_error_message: lastErrorMessage !== undefined ? lastErrorMessage : existing.last_error_message,
        last_error_at: lastErrorAt !== undefined ? lastErrorAt : existing.last_error_at,
        updated_at: new Date().toISOString()
      });
    }

    const recordId = id || `health_${deviceId}`;
    return this.db.insert('device_health_metrics', recordId, {
      device_id: deviceId,
      home_id: homeId,
      health_status: healthStatus,
      last_seen_at: lastSeenAt,
      uptime_seconds: uptimeSeconds,
      rssi,
      ip_address: ipAddress,
      command_success_count: commandSuccessCount,
      command_failure_count: commandFailureCount,
      last_error_message: lastErrorMessage,
      last_error_at: lastErrorAt,
      updated_at: new Date().toISOString()
    });
  }

  async findByDeviceId(deviceId) {
    const records = await this.db.find('device_health_metrics', h => h.device_id === deviceId);
    return records[0] || null;
  }

  async findByHomeId(homeId) {
    return this.db.find('device_health_metrics', h => h.home_id === homeId);
  }

  async recordCommandOutcome(deviceId, isSuccess, errorMessage = null) {
    const existing = await this.findByDeviceId(deviceId);
    if (!existing) return null;

    const updates = {
      updated_at: new Date().toISOString()
    };

    if (isSuccess) {
      updates.command_success_count = (existing.command_success_count || 0) + 1;
    } else {
      updates.command_failure_count = (existing.command_failure_count || 0) + 1;
      if (errorMessage) {
        updates.last_error_message = errorMessage;
        updates.last_error_at = new Date().toISOString();
      }
    }

    return this.db.update('device_health_metrics', existing.id, updates);
  }
}

class NotificationRepository {
  constructor(db) {
    this.db = db;
  }

  async createNotification({
    id,
    userId = null,
    homeId = null,
    type,
    category = 'alert',
    priority = 'NORMAL',
    severity = null,
    title,
    body,
    entityType = null,
    entityId = null,
    data = {},
    deliveryStatus = 'PENDING',
    actionType = null,
    actionTarget = null,
    actionState = 'NONE',
    actionPrimary = null,
    actionSecondary = null,
    isAggregated = false,
    aggregatedCount = 1,
    aggregatedIds = [],
    expiresAt = null,
    decisionMetadata = {},
    idempotencyKey = null,
    readAt = null
  }) {
    if (idempotencyKey) {
      const existing = await this.db.find('notifications', n => n.idempotency_key === idempotencyKey);
      if (existing.length > 0) {
        return existing[0];
      }
    }

    const calculatedSeverity = severity || (priority === 'CRITICAL' ? 'CRITICAL' : priority === 'HIGH' ? 'WARNING' : 'INFO');

    return this.db.insert('notifications', id, {
      user_id: userId,
      home_id: homeId,
      type,
      category,
      priority,
      severity: calculatedSeverity,
      title,
      body,
      entity_type: entityType,
      entity_id: entityId,
      data_json: data,
      read_at: readAt,
      delivery_status: deliveryStatus,
      action_type: actionType,
      action_target: actionTarget,
      action_state: actionState,
      action_primary: actionPrimary || actionType,
      action_secondary: actionSecondary,
      is_aggregated: isAggregated,
      aggregated_count: aggregatedCount,
      aggregated_ids: aggregatedIds,
      expires_at: expiresAt,
      decision_metadata: decisionMetadata,
      idempotency_key: idempotencyKey
    });
  }

  async findById(id) {
    return this.db.findById('notifications', id);
  }

  async updateNotification(id, updates = {}) {
    const existing = await this.db.findById('notifications', id);
    if (!existing) return null;
    return this.db.update('notifications', id, updates);
  }

  async findUserNotifications(userId, { homeId = null, category = null, severity = null, limit = 50, offset = 0, unreadOnly = false } = {}) {
    const list = await this.db.find('notifications', n => {
      if (n.user_id && n.user_id !== userId) return false;
      if (homeId && n.home_id && n.home_id !== homeId) return false;
      if (category && n.category !== category) return false;
      if (severity && (n.severity !== severity && n.priority !== severity)) return false;
      if (unreadOnly && n.read_at !== null) return false;
      return true;
    });

    list.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    return list.slice(offset, offset + limit);
  }

  async findHomeNotifications(homeId, { limit = 50, offset = 0 } = {}) {
    const list = await this.db.find('notifications', n => n.home_id === homeId);
    list.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    return list.slice(offset, offset + limit);
  }

  async findDeferredNotifications(userId = null, homeId = null) {
    return this.db.find('notifications', n => {
      if (userId && n.user_id !== userId) return false;
      if (homeId && n.home_id !== homeId) return false;
      return n.delivery_status === 'DEFERRED';
    });
  }

  async markRead(id, userId = null) {
    const notification = await this.db.findById('notifications', id);
    if (!notification) return null;
    if (userId && notification.user_id && notification.user_id !== userId) {
      throw new Error(`Notification ${id} does not belong to user ${userId}`);
    }
    return this.db.update('notifications', id, {
      read_at: new Date().toISOString()
    });
  }

  async markAllRead(userId, homeId = null) {
    const unread = await this.db.find('notifications', n => {
      if (n.user_id && n.user_id !== userId) return false;
      if (homeId && n.home_id && n.home_id !== homeId) return false;
      return n.read_at === null;
    });

    const now = new Date().toISOString();
    const updated = [];
    for (const item of unread) {
      const u = await this.db.update('notifications', item.id, { read_at: now });
      updated.push(u);
    }
    return updated;
  }

  async countUnread(userId, homeId = null) {
    const unread = await this.db.find('notifications', n => {
      if (n.user_id && n.user_id !== userId) return false;
      if (homeId && n.home_id && n.home_id !== homeId) return false;
      return n.read_at === null;
    });
    return unread.length;
  }

  // --- Notification Actions ---
  async recordAction({ id, notificationId, userId, actionType, actionTarget = null, payload = {}, actionState = 'ACTIONED' }) {
    const actionId = id || `act_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const actionRecord = await this.db.insert('notification_actions', actionId, {
      notification_id: notificationId,
      user_id: userId,
      action_type: actionType,
      action_target: actionTarget,
      action_state: actionState,
      payload,
      executed_at: new Date().toISOString()
    });

    // Update notification state
    const notif = await this.db.findById('notifications', notificationId);
    if (notif) {
      await this.db.update('notifications', notificationId, {
        action_state: actionState,
        read_at: notif.read_at || new Date().toISOString()
      });
    }

    return actionRecord;
  }

  async getActionLogs(notificationId) {
    return this.db.find('notification_actions', a => a.notification_id === notificationId);
  }

  async createAction({ id, notificationId, userId, actionType, actionTarget = null, status = 'EXECUTED', payload = {} }) {
    const record = await this.recordAction({
      id,
      notificationId,
      userId,
      actionType,
      actionTarget,
      payload,
      actionState: status
    });
    return {
      ...record,
      status: record.action_state || status
    };
  }

  async findActionsByNotificationId(notificationId) {
    const actions = await this.getActionLogs(notificationId);
    return actions.map(a => ({
      ...a,
      status: a.action_state || 'EXECUTED'
    }));
  }

  async cleanOldEvents(retentionDays = 30) {
    const cutoff = Date.now() - (retentionDays * 24 * 60 * 60 * 1000);
    const old = await this.db.find('platform_events', e => new Date(e.occurred_at).getTime() < cutoff);
    let count = 0;
    for (const item of old) {
      await this.db.delete('platform_events', item.id);
      count++;
    }
    return count;
  }

  async cleanOldAggregations(retentionDays = 7) {
    const cutoff = Date.now() - (retentionDays * 24 * 60 * 60 * 1000);
    const old = await this.db.find('notification_aggregations', a => new Date(a.created_at).getTime() < cutoff);
    let count = 0;
    for (const item of old) {
      await this.db.delete('notification_aggregations', item.id);
      count++;
    }
    return count;
  }

  // --- Platform Events ---
  async recordPlatformEvent({ id, eventType, source, homeId, deviceId = null, userId = null, severity = 'INFO', title, message = '', data = {}, occurredAt = null }) {
    const eventId = id || `pevt_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return this.db.insert('platform_events', eventId, {
      event_type: eventType,
      source,
      home_id: homeId,
      device_id: deviceId,
      user_id: userId,
      severity,
      title,
      message,
      data_json: data,
      occurred_at: occurredAt || new Date().toISOString()
    });
  }

  async getPlatformEvents({ homeId = null, source = null, severity = null, limit = 50, offset = 0 } = {}) {
    const events = await this.db.find('platform_events', e => {
      if (homeId && e.home_id !== homeId) return false;
      if (source && e.source !== source) return false;
      if (severity && e.severity !== severity) return false;
      return true;
    });
    events.sort((a, b) => new Date(b.occurred_at).getTime() - new Date(a.occurred_at).getTime());
    return events.slice(offset, offset + limit);
  }

  // --- Aggregations ---
  async recordAggregation({ id, aggregationKey, homeId, roomId = null, eventType, severity = 'INFO', eventCount = 1, aggregatedIds = [], summaryTitle, summaryBody, windowSeconds = 60 }) {
    const aggId = id || `agg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return this.db.insert('notification_aggregations', aggId, {
      aggregation_key: aggregationKey,
      home_id: homeId,
      room_id: roomId,
      event_type: eventType,
      severity,
      event_count: eventCount,
      aggregated_ids: aggregatedIds,
      summary_title: summaryTitle,
      summary_body: summaryBody,
      window_seconds: windowSeconds
    });
  }

  async getAggregations(homeId) {
    return this.db.find('notification_aggregations', a => a.home_id === homeId);
  }

  // --- Retention & Expiration ---
  async cleanExpiredNotifications(olderThanDate, preserveCritical = true) {
    const threshold = new Date(olderThanDate).getTime();
    const candidates = await this.db.find('notifications', n => {
      if (preserveCritical && (n.severity === 'CRITICAL' || n.priority === 'CRITICAL')) {
        return false;
      }
      const createdTime = new Date(n.created_at).getTime();
      return createdTime < threshold;
    });

    let cleanedCount = 0;
    for (const c of candidates) {
      await this.db.delete('notifications', c.id);
      cleanedCount++;
    }
    return cleanedCount;
  }

  async upsertDeviceToken({ id, userId, pushToken, platform = 'android', deviceName = null }) {
    const existing = await this.db.find('push_device_tokens', t => t.push_token === pushToken);
    if (existing.length > 0) {
      return this.db.update('push_device_tokens', existing[0].id, {
        user_id: userId,
        platform,
        device_name: deviceName,
        is_active: true,
        last_used_at: new Date().toISOString()
      });
    }

    return this.db.insert('push_device_tokens', id, {
      user_id: userId,
      push_token: pushToken,
      platform,
      device_name: deviceName,
      is_active: true,
      last_used_at: new Date().toISOString()
    });
  }

  async removeDeviceToken(pushToken, userId = null) {
    const existing = await this.db.find('push_device_tokens', t => t.push_token === pushToken);
    if (existing.length === 0) return false;
    if (userId && existing[0].user_id !== userId) {
      throw new Error('Unauthorized to remove device token');
    }
    await this.db.update('push_device_tokens', existing[0].id, {
      is_active: false
    });
    return true;
  }

  async findActiveTokensForUser(userId) {
    return this.db.find('push_device_tokens', t => t.user_id === userId && t.is_active);
  }

  _normalizePrefs(userId, raw = {}) {
    const pushEnabled = raw.push_enabled !== undefined ? raw.push_enabled : (raw.pushEnabled !== undefined ? raw.pushEnabled : true);
    const emailEnabled = raw.email_enabled !== undefined ? raw.email_enabled : (raw.emailEnabled !== undefined ? raw.emailEnabled : false);
    const inAppEnabled = raw.in_app_enabled !== undefined ? raw.in_app_enabled : (raw.inAppEnabled !== undefined ? raw.inAppEnabled : true);
    const criticalAlerts = raw.critical_alerts !== undefined ? raw.critical_alerts : (raw.criticalAlerts !== undefined ? raw.criticalAlerts : true);
    const deviceOffline = raw.device_offline !== undefined ? raw.device_offline : (raw.deviceOffline !== undefined ? raw.deviceOffline : true);
    const deviceHealth = raw.device_health !== undefined ? raw.device_health : (raw.deviceHealth !== undefined ? raw.deviceHealth : true);
    const automationFailure = raw.automation_failure !== undefined ? raw.automation_failure : (raw.automationFailure !== undefined ? raw.automationFailure : true);
    const firmwareUpdates = raw.firmware_updates !== undefined ? raw.firmware_updates : (raw.firmwareUpdates !== undefined ? raw.firmwareUpdates : true);
    const energyAlerts = raw.energy_alerts !== undefined ? raw.energy_alerts : (raw.energyAlerts !== undefined ? raw.energyAlerts : true);
    const securityAlerts = raw.security_alerts !== undefined ? raw.security_alerts : (raw.securityAlerts !== undefined ? raw.securityAlerts : true);
    const matterAlerts = raw.matter_alerts !== undefined ? raw.matter_alerts : (raw.matterAlerts !== undefined ? raw.matterAlerts : true);
    const memberAlerts = raw.member_alerts !== undefined ? raw.member_alerts : (raw.memberAlerts !== undefined ? raw.memberAlerts : true);
    const quietHoursEnabled = raw.quiet_hours_enabled !== undefined ? raw.quiet_hours_enabled : (raw.quietHoursEnabled !== undefined ? raw.quietHoursEnabled : false);
    const quietHoursStart = raw.quiet_hours_start || raw.quietHoursStart || '22:00';
    const quietHoursEnd = raw.quiet_hours_end || raw.quietHoursEnd || '07:00';

    return {
      user_id: userId,
      userId,
      push_enabled: pushEnabled,
      pushEnabled,
      email_enabled: emailEnabled,
      emailEnabled,
      in_app_enabled: inAppEnabled,
      inAppEnabled,
      critical_alerts: criticalAlerts,
      criticalAlerts,
      device_offline: deviceOffline,
      deviceOffline,
      device_health: deviceHealth,
      deviceHealth,
      automation_failure: automationFailure,
      automationFailure,
      firmware_updates: firmwareUpdates,
      firmwareUpdates,
      energy_alerts: energyAlerts,
      energyAlerts,
      security_alerts: securityAlerts,
      securityAlerts,
      matter_alerts: matterAlerts,
      matterAlerts,
      member_alerts: memberAlerts,
      memberAlerts,
      quiet_hours_enabled: quietHoursEnabled,
      quietHoursEnabled,
      quiet_hours_start: quietHoursStart,
      quietHoursStart,
      quiet_hours_end: quietHoursEnd,
      quietHoursEnd
    };
  }

  async getPreferences(userId) {
    const records = await this.db.find('user_notification_preferences', p => p.user_id === userId);
    return this._normalizePrefs(userId, records.length > 0 ? records[0] : {});
  }

  async savePreferences(userId, prefs) {
    return this.upsertPreferences(userId, prefs);
  }

  async upsertPreferences(userId, prefs) {
    const existing = await this.db.find('user_notification_preferences', p => p.user_id === userId);
    const now = new Date().toISOString();
    const normalized = this._normalizePrefs(userId, { ...(existing[0] || {}), ...prefs });
    const dbPayload = {
      user_id: userId,
      push_enabled: normalized.push_enabled,
      email_enabled: normalized.email_enabled,
      in_app_enabled: normalized.in_app_enabled,
      critical_alerts: normalized.critical_alerts,
      device_offline: normalized.device_offline,
      device_health: normalized.device_health,
      automation_failure: normalized.automation_failure,
      firmware_updates: normalized.firmware_updates,
      energy_alerts: normalized.energy_alerts,
      security_alerts: normalized.security_alerts,
      matter_alerts: normalized.matter_alerts,
      member_alerts: normalized.member_alerts,
      quiet_hours_enabled: normalized.quiet_hours_enabled,
      quiet_hours_start: normalized.quiet_hours_start,
      quiet_hours_end: normalized.quiet_hours_end,
      updated_at: now
    };

    if (existing.length > 0) {
      await this.db.update('user_notification_preferences', existing[0].id, dbPayload);
    } else {
      const id = `pref_${userId}`;
      await this.db.insert('user_notification_preferences', id, {
        ...dbPayload,
        created_at: now
      });
    }
    return normalized;
  }

  async enqueueDelivery({ id, notificationId, tokenId = null, status = 'PENDING', maxAttempts = 5 }) {
    return this.db.insert('notification_delivery_queue', id, {
      notification_id: notificationId,
      token_id: tokenId,
      status,
      attempts: 0,
      max_attempts: maxAttempts,
      next_attempt_at: new Date().toISOString(),
      last_error: null
    });
  }

  async fetchPendingDeliveries(limit = 20) {
    const now = new Date().toISOString();
    const list = await this.db.find('notification_delivery_queue', q => {
      if (q.status !== 'PENDING' && q.status !== 'RETRYING') return false;
      if (new Date(q.next_attempt_at) > new Date(now)) return false;
      return true;
    });
    return list.slice(0, limit);
  }

  async updateDeliveryStatus(id, { status, attempts, nextAttemptAt, lastError }) {
    const updates = {};
    if (status !== undefined) updates.status = status;
    if (attempts !== undefined) updates.attempts = attempts;
    if (nextAttemptAt !== undefined) updates.next_attempt_at = nextAttemptAt;
    if (lastError !== undefined) updates.last_error = lastError;
    return this.db.update('notification_delivery_queue', id, updates);
  }
}

class SyncRepository {
  constructor(db) {
    this.db = db;
  }

  async recordCheckpoint({ userId, homeId, clientDeviceId, lastSyncSeq = 0, schemaVersion = 1 }) {
    const id = `chk_${userId}_${homeId}_${clientDeviceId}`;
    const existing = await this.db.findById('sync_checkpoints', id);
    const now = new Date().toISOString();
    if (existing) {
      return this.db.update('sync_checkpoints', id, {
        last_sync_seq: lastSyncSeq,
        schema_version: schemaVersion,
        synced_at: now,
        updated_at: now
      });
    }
    return this.db.insert('sync_checkpoints', id, {
      user_id: userId,
      home_id: homeId,
      client_device_id: clientDeviceId,
      last_sync_seq: lastSyncSeq,
      schema_version: schemaVersion,
      synced_at: now,
      updated_at: now
    });
  }

  async getCheckpoint(userId, homeId, clientDeviceId) {
    const id = `chk_${userId}_${homeId}_${clientDeviceId}`;
    return this.db.findById('sync_checkpoints', id);
  }

  async recordPendingAudit({ userId, homeId, clientMutationId, entityType, entityId = null, mutationType, payload = {}, status = 'ACCEPTED', rejectionReason = null }) {
    const id = `aud_${homeId}_${clientMutationId}`;
    return this.db.insert('pending_change_audits', id, {
      user_id: userId,
      home_id: homeId,
      client_mutation_id: clientMutationId,
      entity_type: entityType,
      entity_id: entityId,
      mutation_type: mutationType,
      payload,
      status,
      rejection_reason: rejectionReason,
      applied_at: new Date().toISOString()
    });
  }

  async listPendingAudits(homeId, limit = 50) {
    const list = await this.db.find('pending_change_audits', a => a.home_id === homeId);
    return list.sort((a, b) => new Date(b.applied_at) - new Date(a.applied_at)).slice(0, limit);
  }
}

class ExportRepository {
  constructor(db) {
    this.db = db;
  }

  async recordExport({ id, userId, homeId = null, exportScope, sanitizedSummary, expiresAt = null }) {
    return this.db.insert('data_export_records', id, {
      user_id: userId,
      home_id: homeId,
      export_scope: exportScope,
      status: 'COMPLETED',
      sanitized_summary: sanitizedSummary,
      expires_at: expiresAt,
      created_at: new Date().toISOString()
    });
  }

  async getExport(id) {
    return this.db.findById('data_export_records', id);
  }

  async listExportsForUser(userId) {
    const list = await this.db.find('data_export_records', e => e.user_id === userId);
    return list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  }
}

class FirmwareReleaseRepository {
  constructor(db) {
    this.db = db;
  }

  async createRelease(manifest) {
    const id = manifest.id || manifest.releaseId || `rel_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return this.db.insert('firmware_releases', id, {
      product_variant_id: manifest.productVariantId,
      hardware_revision: manifest.hardwareRevision || null,
      firmware_family: manifest.firmwareFamily || 'esp32-switch-platform',
      version: manifest.version,
      min_firmware_version: manifest.minFirmwareVersion || null,
      release_channel: manifest.releaseChannel || 'production',
      binary_size_bytes: manifest.binarySizeBytes || 0,
      sha256: manifest.sha256,
      ed25519_signature: manifest.ed25519Signature,
      download_url: manifest.downloadUrl,
      release_notes: manifest.releaseNotes || null,
      status: manifest.status || 'PUBLISHED',
      released_at: manifest.releasedAt || new Date().toISOString()
    });
  }

  async findById(id) {
    return this.db.findById('firmware_releases', id);
  }

  async findByVariant(productVariantId, releaseChannel = null) {
    return this.db.find('firmware_releases', r => {
      if (r.product_variant_id !== productVariantId) return false;
      if (releaseChannel && r.release_channel !== releaseChannel) return false;
      return r.status === 'PUBLISHED';
    });
  }

  async listReleases(filters = {}) {
    return this.db.find('firmware_releases', r => {
      if (filters.productVariantId && r.product_variant_id !== filters.productVariantId) return false;
      if (filters.releaseChannel && r.release_channel !== filters.releaseChannel) return false;
      if (filters.status && r.status !== filters.status) return false;
      return true;
    });
  }

  async updateStatus(id, status) {
    return this.db.update('firmware_releases', id, { status });
  }
}

class OtaOperationRepository {
  constructor(db) {
    this.db = db;
  }

  async createOperation({
    id,
    deviceId,
    homeId,
    releaseId,
    rolloutId = null,
    fromVersion,
    targetVersion,
    status = 'QUEUED',
    progressPercent = 0,
    initiatedByUserId = null
  }) {
    const opId = id || `ota_op_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();
    return this.db.insert('ota_operations', opId, {
      device_id: deviceId,
      home_id: homeId,
      release_id: releaseId,
      rollout_id: rolloutId,
      from_version: fromVersion,
      target_version: targetVersion,
      status,
      progress_percent: progressPercent,
      error_code: null,
      error_message: null,
      initiated_by_user_id: initiatedByUserId,
      started_at: now,
      completed_at: null,
      updated_at: now
    });
  }

  async findById(id) {
    return this.db.findById('ota_operations', id);
  }

  async findByDeviceId(deviceId) {
    const ops = await this.db.find('ota_operations', o => o.device_id === deviceId);
    return ops.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
  }

  async findActiveByDeviceId(deviceId) {
    const active = await this.db.find('ota_operations', o =>
      o.device_id === deviceId &&
      !['SUCCESS', 'FAILED', 'ROLLED_BACK'].includes(o.status)
    );
    return active[0] || null;
  }

  async findByHomeId(homeId) {
    const ops = await this.db.find('ota_operations', o => o.home_id === homeId);
    return ops.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
  }

  async updateProgress(id, updates = {}) {
    const cleanUpdates = { updated_at: new Date().toISOString() };
    if (updates.status !== undefined) cleanUpdates.status = updates.status;
    if (updates.progressPercent !== undefined) cleanUpdates.progress_percent = updates.progressPercent;
    if (updates.errorCode !== undefined) cleanUpdates.error_code = updates.errorCode;
    if (updates.errorMessage !== undefined) cleanUpdates.error_message = updates.errorMessage;
    if (updates.completedAt !== undefined) cleanUpdates.completed_at = updates.completedAt;
    if (['SUCCESS', 'FAILED', 'ROLLED_BACK'].includes(updates.status) && !cleanUpdates.completed_at) {
      cleanUpdates.completed_at = new Date().toISOString();
    }
    return this.db.update('ota_operations', id, cleanUpdates);
  }
}

class OtaRolloutRepository {
  constructor(db) {
    this.db = db;
  }

  async createRollout({
    id,
    releaseId,
    homeId = null,
    rolloutStage = 'CANARY',
    status = 'ACTIVE',
    targetFilters = {}
  }) {
    const rolloutId = id || `rollout_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const now = new Date().toISOString();
    return this.db.insert('ota_rollouts', rolloutId, {
      release_id: releaseId,
      home_id: homeId,
      rollout_stage: rolloutStage,
      status,
      target_filters_json: JSON.stringify(targetFilters),
      created_at: now,
      updated_at: now
    });
  }

  async findById(id) {
    return this.db.findById('ota_rollouts', id);
  }

  async findByReleaseId(releaseId) {
    return this.db.find('ota_rollouts', r => r.release_id === releaseId);
  }

  async listActive() {
    return this.db.find('ota_rollouts', r => r.status === 'ACTIVE');
  }

  async updateRollout(id, updates = {}) {
    const cleanUpdates = { updated_at: new Date().toISOString() };
    if (updates.rolloutStage !== undefined) cleanUpdates.rollout_stage = updates.rolloutStage;
    if (updates.status !== undefined) cleanUpdates.status = updates.status;
    if (updates.targetFilters !== undefined) cleanUpdates.target_filters_json = JSON.stringify(updates.targetFilters);
    return this.db.update('ota_rollouts', id, cleanUpdates);
  }
}

class DeviceMaintenanceRepository {
  constructor(db) {
    this.db = db;
  }

  async logMaintenance({
    id,
    deviceId,
    homeId,
    operationType,
    releaseId = null,
    fromVersion = null,
    toVersion = null,
    status,
    details = {}
  }) {
    const logId = id || `maint_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return this.db.insert('device_maintenance_logs', logId, {
      device_id: deviceId,
      home_id: homeId,
      operation_type: operationType,
      release_id: releaseId,
      from_version: fromVersion,
      to_version: toVersion,
      status,
      details_json: JSON.stringify(details),
      created_at: new Date().toISOString()
    });
  }

  async findByDeviceId(deviceId, limit = 50) {
    const logs = await this.db.find('device_maintenance_logs', l => l.device_id === deviceId);
    return logs.reverse().slice(0, limit);
  }

  async findByHomeId(homeId, limit = 50) {
    const logs = await this.db.find('device_maintenance_logs', l => l.home_id === homeId);
    return logs.reverse().slice(0, limit);
  }
}

// -----------------------------------------------------------------------------
// Phase 19: Energy Intelligence & Telemetry Repositories
// -----------------------------------------------------------------------------

class DeviceTelemetryRepository {
  constructor(db) {
    this.db = db;
  }

  async recordMeasurement(m) {
    const id = m.id || `telem_${m.deviceId || m.device_id}_${m.channelIndex || m.channel_index || 1}_${m.sequenceNumber || m.sequence_number || 0}_${Date.now()}`;
    const p_mw = m.p_mw !== undefined ? m.p_mw : (m.powerW ? m.powerW * 1000 : (m.power_w ? m.power_w * 1000 : 0));
    const power_w = m.powerW !== undefined ? m.powerW : (m.power_w !== undefined ? m.power_w : (p_mw / 1000));
    const record = {
      device_id: m.deviceId || m.device_id,
      home_id: m.homeId || m.home_id || null,
      channel_index: m.channelIndex !== undefined ? m.channelIndex : (m.channel_index !== undefined ? m.channel_index : 1),
      v_mv: m.v_mv,
      i_ma: m.i_ma,
      p_mw,
      power_w,
      e_tot_wh: m.e_tot_wh,
      e_int_mwh: m.e_int_mwh,
      freq_mhz: m.freq_mhz,
      pf_x1000: m.pf_x1000,
      flags: m.flags !== undefined ? m.flags : 0,
      sequence_number: m.sequenceNumber !== undefined ? m.sequenceNumber : (m.sequence_number !== undefined ? m.sequence_number : 0),
      device_timestamp: m.timestamp || m.device_timestamp || new Date().toISOString(),
      ingested_at: m.ingested_at || new Date().toISOString()
    };
    return this.db.insert('device_telemetry_measurements', id, record);
  }

  async recordTelemetry(m) {
    return this.recordMeasurement(m);
  }

  async insertMeasurement(m) {
    return this.recordMeasurement(m);
  }

  async getLatestMeasurement(deviceId, channelIndex = 1) {
    const list = await this.db.find('device_telemetry_measurements', m =>
      m.device_id === deviceId && m.channel_index === channelIndex
    );
    if (!list || list.length === 0) return null;
    list.sort((a, b) => new Date(b.device_timestamp) - new Date(a.device_timestamp));
    return list[0];
  }

  async getMeasurements(deviceId, { channelIndex = null, from = null, to = null, limit = 100, offset = 0 } = {}) {
    let list = await this.db.find('device_telemetry_measurements', m => {
      if (m.device_id !== deviceId) return false;
      if (channelIndex !== null && m.channel_index !== channelIndex) return false;
      if (from && new Date(m.device_timestamp) < new Date(from)) return false;
      if (to && new Date(m.device_timestamp) > new Date(to)) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.device_timestamp) - new Date(a.device_timestamp));
    return list.slice(offset, offset + limit);
  }

  async findByTimeRange(homeId, { startTime = null, endTime = null, deviceId = null } = {}) {
    let list = await this.db.find('device_telemetry_measurements', m => {
      if (deviceId && m.device_id !== deviceId) return false;
      const ts = m.device_timestamp || m.created_at;
      if (startTime && new Date(ts) < new Date(startTime)) return false;
      if (endTime && new Date(ts) > new Date(endTime)) return false;
      return true;
    });
    list.sort((a, b) => new Date(a.device_timestamp) - new Date(b.device_timestamp));
    return list;
  }

  async purgeOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('device_telemetry_measurements', m => new Date(m.device_timestamp) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('device_telemetry_measurements', s.id);
    }
    return stale.length;
  }
}

class TelemetryAggregateRepository {
  constructor(db) {
    this.db = db;
  }

  async upsertAggregate({
    id: explicitId = null,
    homeId = null,
    deviceId,
    roomId = null,
    channelIndex = 1,
    bucket = 'HOUR',
    bucketType = 'HOUR',
    startTime = null,
    endTime = null,
    bucketStart = null,
    bucketEnd = null,
    energyDeltaWh = 0,
    totalEnergyWh = 0,
    avgPowerW = 0,
    peakPowerW = 0,
    minPowerW = 0,
    sampleCount = 1,
    dataQuality = 'GOOD'
  }) {
    const sTime = bucketStart || startTime || new Date().toISOString();
    const eTime = bucketEnd || endTime || new Date().toISOString();
    const bType = (bucketType || bucket || 'HOUR').toUpperCase();
    const energyWh = Number(totalEnergyWh || energyDeltaWh || 0);
    const id = explicitId || `agg_${deviceId}_${channelIndex}_${bType}_${sTime}`;

    const record = {
      id,
      home_id: homeId,
      device_id: deviceId,
      room_id: roomId,
      channel_index: channelIndex,
      bucket_type: bType,
      bucket_start: sTime,
      bucket_end: eTime,
      start_time: sTime,
      end_time: eTime,
      energy_delta_wh: energyWh,
      total_energy_wh: energyWh,
      avg_power_w: Number(avgPowerW || 0),
      peak_power_w: Number(peakPowerW || 0),
      min_power_w: Number(minPowerW || 0),
      sample_count: Number(sampleCount || 1),
      data_quality: dataQuality,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };

    const existing = await this.db.findById('telemetry_aggregates', id);
    if (existing) {
      return this.db.update('telemetry_aggregates', id, record);
    }
    return this.db.insert('telemetry_aggregates', id, record);
  }

  async getAggregates(deviceId, { bucketType, from = null, to = null, limit = 500 } = {}) {
    const list = await this.db.find('telemetry_aggregates', a => {
      if (a.device_id !== deviceId) return false;
      if (bucketType && a.bucket_type !== bucketType) return false;
      if (from && new Date(a.bucket_start) < new Date(from)) return false;
      if (to && new Date(a.bucket_start) > new Date(to)) return false;
      return true;
    });
    list.sort((a, b) => new Date(a.bucket_start) - new Date(b.bucket_start));
    return list.slice(0, limit);
  }

  async getHomeAggregates(deviceIds = [], { bucketType, from = null, to = null } = {}) {
    if (!deviceIds || deviceIds.length === 0) return [];
    const devSet = new Set(deviceIds);
    const list = await this.db.find('telemetry_aggregates', a => {
      if (!devSet.has(a.device_id)) return false;
      if (bucketType && a.bucket_type !== bucketType) return false;
      if (from && new Date(a.bucket_start) < new Date(from)) return false;
      if (to && new Date(a.bucket_start) > new Date(to)) return false;
      return true;
    });
    list.sort((a, b) => new Date(a.bucket_start) - new Date(b.bucket_start));
    return list;
  }

  async findByPeriod(homeId, { bucket = 'HOUR', bucketType = null, startTime = null, endTime = null } = {}) {
    const targetBucket = (bucketType || bucket || 'HOUR').toUpperCase();
    const list = await this.db.find('telemetry_aggregates', a => {
      if (a.home_id && a.home_id !== homeId) return false;
      if (targetBucket && a.bucket_type && a.bucket_type.toUpperCase() !== targetBucket) return false;
      const aStart = a.bucket_start || a.start_time || a.created_at;
      if (startTime && new Date(aStart) < new Date(startTime)) return false;
      if (endTime && new Date(aStart) > new Date(endTime)) return false;
      return true;
    });
    list.sort((a, b) => new Date(a.bucket_start || a.start_time) - new Date(b.bucket_start || b.start_time));
    return list;
  }
}

class EnergyThresholdRepository {
  constructor(db) {
    this.db = db;
  }

  async getThresholdsForHome(homeId) {
    return this.db.find('energy_threshold_configs', t => t.home_id === homeId && t.is_enabled === 1);
  }

  async getThresholdForHome(homeId) {
    return this.getThreshold(homeId, null);
  }

  async getThreshold(homeId, deviceId = null) {
    const list = await this.db.find('energy_threshold_configs', t =>
      t.home_id === homeId && (deviceId ? t.device_id === deviceId : (!t.device_id || t.device_id === null))
    );
    return list[0] || null;
  }

  async upsertThreshold({
    homeId,
    deviceId = null,
    highPowerW = null,
    dailyEnergyKwh = null,
    monthlyEnergyKwh = null,
    costPerKwh = 0.15,
    currency = 'USD',
    isEnabled = 1
  }) {
    const existing = await this.getThreshold(homeId, deviceId);
    if (existing) {
      return this.db.update('energy_threshold_configs', existing.id, {
        high_power_w: highPowerW,
        daily_energy_kwh: dailyEnergyKwh,
        monthly_energy_kwh: monthlyEnergyKwh,
        cost_per_kwh: costPerKwh,
        currency,
        is_enabled: isEnabled ? 1 : 0,
        updated_at: new Date().toISOString()
      });
    }

    const id = `ethr_${homeId}_${deviceId || 'home'}`;
    return this.db.insert('energy_threshold_configs', id, {
      home_id: homeId,
      device_id: deviceId,
      high_power_w: highPowerW,
      daily_energy_kwh: dailyEnergyKwh,
      monthly_energy_kwh: monthlyEnergyKwh,
      cost_per_kwh: costPerKwh,
      currency,
      is_enabled: isEnabled ? 1 : 0,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    });
  }

  async deleteThreshold(id) {
    return this.db.delete('energy_threshold_configs', id);
  }
}

class EnergyEventRepository {
  constructor(db) {
    this.db = db;
  }

  async recordEvent({
    id = null,
    homeId,
    deviceId = null,
    eventType,
    severity = 'WARN',
    valueRecorded,
    thresholdValue,
    message,
    details = {}
  }) {
    const eventId = id || `enevt_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return this.db.insert('energy_events', eventId, {
      home_id: homeId,
      device_id: deviceId,
      event_type: eventType,
      severity,
      value_recorded: valueRecorded,
      threshold_value: thresholdValue,
      message,
      details_json: JSON.stringify(details),
      created_at: new Date().toISOString()
    });
  }

  async getEventsForHome(homeId, { limit = 50, from = null } = {}) {
    let list = await this.db.find('energy_events', e => {
      if (e.home_id !== homeId) return false;
      if (from && new Date(e.created_at) < new Date(from)) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list.slice(0, limit);
  }
}

// -----------------------------------------------------------------------------
// 26. Energy Automation Execution Repository (Phase 20)
// -----------------------------------------------------------------------------
class EnergyAutomationExecutionRepository {
  constructor(db) {
    this.db = db;
  }

  async createExecution({
    id,
    homeId,
    automationId = null,
    scopeType = 'device',
    scopeId = null,
    triggerType,
    triggerReason,
    telemetryContext = {},
    previousState = null,
    requestedAction = null,
    resultingState = null,
    status,
    skipReason = null,
    errorMessage = null,
    durationMs = 0,
    createdAt = new Date().toISOString()
  }) {
    const execId = id || `enexec_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return this.db.insert('energy_automation_executions', execId, {
      home_id: homeId,
      automation_id: automationId,
      scope_type: scopeType,
      scope_id: scopeId,
      trigger_type: triggerType,
      trigger_reason: triggerReason,
      telemetry_context: typeof telemetryContext === 'object' ? JSON.stringify(telemetryContext) : telemetryContext,
      previous_state: typeof previousState === 'object' && previousState !== null ? JSON.stringify(previousState) : previousState,
      requested_action: typeof requestedAction === 'object' && requestedAction !== null ? JSON.stringify(requestedAction) : requestedAction,
      resulting_state: typeof resultingState === 'object' && resultingState !== null ? JSON.stringify(resultingState) : resultingState,
      status,
      skip_reason: skipReason,
      error_message: errorMessage,
      duration_ms: durationMs,
      created_at: createdAt
    });
  }

  async findById(id) {
    return this.db.findById('energy_automation_executions', id);
  }

  async findByAutomationId(automationId, limit = 50) {
    const list = await this.db.find('energy_automation_executions', e => e.automation_id === automationId);
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list.slice(0, limit);
  }

  async findByHomeId(homeId, { limit = 50, from = null } = {}) {
    let list = await this.db.find('energy_automation_executions', e => {
      if (e.home_id !== homeId) return false;
      if (from && new Date(e.created_at) < new Date(from)) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list.slice(0, limit);
  }

  async deleteOlderThan(cutoffIso) {
    const stale = await this.db.find('energy_automation_executions', e => e.created_at < cutoffIso);
    for (const item of stale) {
      await this.db.delete('energy_automation_executions', item.id);
    }
    return stale.length;
  }
}

// -----------------------------------------------------------------------------
// 27. Energy Optimization Repository (Phase 20)
// -----------------------------------------------------------------------------
class EnergyOptimizationRepository {
  constructor(db) {
    this.db = db;
  }

  async upsertOptimization({
    id,
    homeId,
    deviceId = null,
    category,
    severity = 'MEDIUM',
    title,
    description,
    estimatedDailySavingsKwh = 0,
    estimatedMonthlySavingsKwh = 0,
    estimatedMonthlyCostSavings = 0,
    currency = 'USD',
    calculationBasis = {},
    suggestedAction = {},
    isDismissed = false
  }) {
    const existing = await this.db.find('energy_optimizations', opt =>
      opt.home_id === homeId && opt.device_id === deviceId && opt.category === category
    );

    const now = new Date().toISOString();
    const payload = {
      home_id: homeId,
      device_id: deviceId,
      category,
      severity,
      title,
      description,
      estimated_daily_savings_kwh: Number(estimatedDailySavingsKwh) || 0,
      estimated_monthly_savings_kwh: Number(estimatedMonthlySavingsKwh) || 0,
      estimated_monthly_cost_savings: Number(estimatedMonthlyCostSavings) || 0,
      currency: currency || 'USD',
      calculation_basis: typeof calculationBasis === 'object' ? JSON.stringify(calculationBasis) : calculationBasis,
      suggested_action: typeof suggestedAction === 'object' ? JSON.stringify(suggestedAction) : suggestedAction,
      is_dismissed: isDismissed ? 1 : 0,
      updated_at: now
    };

    if (existing.length > 0) {
      const record = existing[0];
      return this.db.update('energy_optimizations', record.id, payload);
    }

    const optId = id || `enopt_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    return this.db.insert('energy_optimizations', optId, {
      ...payload,
      created_at: now
    });
  }

  async findById(id) {
    return this.db.findById('energy_optimizations', id);
  }

  async findByHomeId(homeId, { includeDismissed = false } = {}) {
    let list = await this.db.find('energy_optimizations', opt => {
      if (opt.home_id !== homeId) return false;
      if (!includeDismissed && (opt.is_dismissed === 1 || opt.is_dismissed === true)) return false;
      return true;
    });
    list.sort((a, b) => (b.estimated_monthly_cost_savings || 0) - (a.estimated_monthly_cost_savings || 0));
    return list;
  }

  async findByDeviceId(deviceId) {
    return this.db.find('energy_optimizations', opt => opt.device_id === deviceId);
  }

  async dismissOptimization(id) {
    return this.db.update('energy_optimizations', id, {
      is_dismissed: 1,
      updated_at: new Date().toISOString()
    });
  }

  async deleteOlderThan(cutoffIso) {
    const stale = await this.db.find('energy_optimizations', opt => opt.updated_at < cutoffIso);
    for (const item of stale) {
      await this.db.delete('energy_optimizations', item.id);
    }
    return stale.length;
  }
}

class EnergyTariffRepository {
  constructor(dbClient) {
    this.db = dbClient;
  }

  async createTariff(tariff) {
    const id = tariff.id || `tariff_${crypto.randomUUID()}`;
    const nowIso = new Date().toISOString();
    const record = {
      id,
      home_id: tariff.homeId || tariff.home_id,
      name: tariff.name,
      tariff_type: tariff.tariffType || tariff.tariff_type || 'FLAT',
      currency: tariff.currency || 'USD',
      flat_rate_per_kwh: tariff.flatRatePerKwh !== undefined ? tariff.flatRatePerKwh : (tariff.flat_rate_per_kwh !== undefined ? tariff.flat_rate_per_kwh : null),
      fixed_daily_charge: tariff.fixedDailyCharge !== undefined ? tariff.fixedDailyCharge : (tariff.fixed_daily_charge || 0),
      effective_from: tariff.effectiveFrom || tariff.effective_from || nowIso,
      effective_to: tariff.effectiveTo !== undefined ? tariff.effectiveTo : (tariff.effective_to || null),
      carbon_intensity_g_per_kwh: tariff.carbonIntensityGPerKwh !== undefined ? tariff.carbonIntensityGPerKwh : (tariff.carbon_intensity_g_per_kwh || null),
      is_active: tariff.isActive !== undefined ? (tariff.isActive ? 1 : 0) : (tariff.is_active !== undefined ? tariff.is_active : 1),
      metadata: typeof tariff.metadata === 'object' && tariff.metadata !== null ? JSON.stringify(tariff.metadata) : (tariff.metadata || null),
      created_at: tariff.createdAt || tariff.created_at || nowIso,
      updated_at: tariff.updatedAt || tariff.updated_at || nowIso
    };
    return this.db.insert('energy_tariffs', id, record);
  }

  async findById(id) {
    return this.db.findById('energy_tariffs', id);
  }

  async findByHomeId(homeId, { activeOnly = false } = {}) {
    return this.db.find('energy_tariffs', t => {
      if (t.home_id !== homeId) return false;
      if (activeOnly && !t.is_active) return false;
      return true;
    });
  }

  async findActiveTariffForTime(homeId, asOfTime = null) {
    const timeIso = asOfTime ? (typeof asOfTime === 'string' ? asOfTime : new Date(asOfTime).toISOString()) : new Date().toISOString();
    const all = await this.findByHomeId(homeId, { activeOnly: true });
    // Filter matching effective_from <= timeIso and (effective_to == null or effective_to >= timeIso)
    const matching = all.filter(t => {
      if (t.effective_from > timeIso) return false;
      if (t.effective_to && t.effective_to < timeIso) return false;
      return true;
    });
    // Sort by effective_from DESC
    matching.sort((a, b) => (b.effective_from || '').localeCompare(a.effective_from || ''));
    return matching[0] || null;
  }

  async updateTariff(id, updates) {
    const current = await this.findById(id);
    if (!current) throw new Error(`Tariff ${id} not found`);
    const mapped = { ...updates, updated_at: new Date().toISOString() };
    if (updates.flatRatePerKwh !== undefined) mapped.flat_rate_per_kwh = updates.flatRatePerKwh;
    if (updates.fixedDailyCharge !== undefined) mapped.fixed_daily_charge = updates.fixedDailyCharge;
    if (updates.effectiveFrom !== undefined) mapped.effective_from = updates.effectiveFrom;
    if (updates.effectiveTo !== undefined) mapped.effective_to = updates.effectiveTo;
    if (updates.isActive !== undefined) mapped.is_active = updates.isActive ? 1 : 0;
    if (updates.carbonIntensityGPerKwh !== undefined) mapped.carbon_intensity_g_per_kwh = updates.carbonIntensityGPerKwh;
    if (updates.metadata && typeof updates.metadata === 'object') mapped.metadata = JSON.stringify(updates.metadata);
    return this.db.update('energy_tariffs', id, mapped);
  }

  async deleteTariff(id) {
    return this.db.delete('energy_tariffs', id);
  }
}

class TariffPeriodRepository {
  constructor(dbClient) {
    this.db = dbClient;
  }

  async createPeriod(period) {
    const id = period.id || `period_${crypto.randomUUID()}`;
    const record = {
      id,
      tariff_id: period.tariffId || period.tariff_id,
      home_id: period.homeId || period.home_id,
      period_type: period.periodType || period.period_type,
      start_time: period.startTime || period.start_time,
      end_time: period.endTime || period.end_time,
      applicable_weekdays: Array.isArray(period.applicableWeekdays)
        ? JSON.stringify(period.applicableWeekdays)
        : (period.applicable_weekdays || '[1,2,3,4,5,6,7]'),
      price_per_kwh: Number(period.pricePerKwh !== undefined ? period.pricePerKwh : period.price_per_kwh),
      created_at: period.createdAt || period.created_at || new Date().toISOString()
    };
    return this.db.insert('tariff_periods', id, record);
  }

  async findByTariffId(tariffId) {
    return this.db.find('tariff_periods', p => p.tariff_id === tariffId);
  }

  async findByHomeId(homeId) {
    return this.db.find('tariff_periods', p => p.home_id === homeId);
  }

  async deleteByTariffId(tariffId) {
    const periods = await this.findByTariffId(tariffId);
    for (const p of periods) {
      await this.db.delete('tariff_periods', p.id);
    }
    return periods.length;
  }

  async deletePeriod(id) {
    return this.db.delete('tariff_periods', id);
  }
}

class EnergyBudgetRepository {
  constructor(dbClient) {
    this.db = dbClient;
  }

  async setBudget(budget) {
    const homeId = budget.homeId || budget.home_id;
    const periodType = budget.periodType || budget.period_type;
    const existing = await this.findByHomeAndPeriod(homeId, periodType);
    const nowIso = new Date().toISOString();

    if (existing) {
      const updates = {
        budget_amount: Number(budget.budgetAmount !== undefined ? budget.budgetAmount : budget.budget_amount),
        currency: budget.currency || existing.currency || 'USD',
        alert_threshold_percent: Number(budget.alertThresholdPercent !== undefined ? budget.alertThresholdPercent : (budget.alert_threshold_percent || 80)),
        is_enabled: budget.isEnabled !== undefined ? (budget.isEnabled ? 1 : 0) : (budget.is_enabled !== undefined ? budget.is_enabled : 1),
        updated_at: nowIso
      };
      return this.db.update('energy_budgets', existing.id, updates);
    }

    const id = budget.id || `budget_${crypto.randomUUID()}`;
    const record = {
      id,
      home_id: homeId,
      period_type: periodType,
      budget_amount: Number(budget.budgetAmount !== undefined ? budget.budgetAmount : budget.budget_amount),
      currency: budget.currency || 'USD',
      alert_threshold_percent: Number(budget.alertThresholdPercent !== undefined ? budget.alertThresholdPercent : (budget.alert_threshold_percent || 80)),
      is_enabled: budget.isEnabled !== undefined ? (budget.isEnabled ? 1 : 0) : (budget.is_enabled !== undefined ? budget.is_enabled : 1),
      created_at: nowIso,
      updated_at: nowIso
    };
    return this.db.insert('energy_budgets', id, record);
  }

  async findByHomeId(homeId) {
    return this.db.find('energy_budgets', b => b.home_id === homeId);
  }

  async findByHomeAndPeriod(homeId, periodType) {
    const all = await this.db.find('energy_budgets', b => b.home_id === homeId && b.period_type === periodType);
    return all[0] || null;
  }

  async deleteBudget(homeId, periodType) {
    const existing = await this.findByHomeAndPeriod(homeId, periodType);
    if (existing) {
      return this.db.delete('energy_budgets', existing.id);
    }
    return false;
  }
}

class CostOptimizationRepository {
  constructor(dbClient) {
    this.db = dbClient;
  }

  async createOptimization(opt) {
    const id = opt.id || `copt_${crypto.randomUUID()}`;
    const nowIso = new Date().toISOString();
    const record = {
      id,
      home_id: opt.homeId || opt.home_id,
      device_id: opt.deviceId || opt.device_id || null,
      category: opt.category,
      priority: opt.priority || 'MEDIUM',
      title: opt.title,
      description: opt.description,
      evidence: typeof opt.evidence === 'object' && opt.evidence !== null ? JSON.stringify(opt.evidence) : (opt.evidence || null),
      estimated_savings: typeof opt.estimatedSavings === 'object' && opt.estimatedSavings !== null ? JSON.stringify(opt.estimatedSavings) : (opt.estimated_savings || null),
      recommended_window: typeof opt.recommendedWindow === 'object' && opt.recommendedWindow !== null ? JSON.stringify(opt.recommendedWindow) : (opt.recommended_window || null),
      is_dismissed: opt.isDismissed ? 1 : 0,
      created_at: opt.createdAt || opt.created_at || nowIso,
      updated_at: opt.updatedAt || opt.updated_at || nowIso
    };
    return this.db.insert('cost_optimizations', id, record);
  }

  async findById(id) {
    return this.db.findById('cost_optimizations', id);
  }

  async findByHomeId(homeId, { includeDismissed = false } = {}) {
    return this.db.find('cost_optimizations', opt => {
      if (opt.home_id !== homeId) return false;
      if (!includeDismissed && opt.is_dismissed) return false;
      return true;
    });
  }

  async dismissOptimization(id) {
    const current = await this.findById(id);
    if (!current) throw new Error(`Cost optimization ${id} not found`);
    return this.db.update('cost_optimizations', id, { is_dismissed: 1, updated_at: new Date().toISOString() });
  }

  async deleteOlderThan(cutoffIso) {
    const stale = await this.db.find('cost_optimizations', opt => opt.created_at < cutoffIso && opt.is_dismissed === 1);
    for (const item of stale) {
      await this.db.delete('cost_optimizations', item.id);
    }
    return stale.length;
  }
}

class EnergyForecastRepository {
  constructor(db) {
    this.db = db;
  }

  async saveForecast({
    id = null,
    homeId,
    scopeType = 'home',
    scopeId,
    horizon,
    startTime,
    endTime,
    predictedKwh = 0,
    predictedCost = 0,
    currency = 'USD',
    confidenceScore = 0.5,
    methodology = 'HISTORICAL_HOURLY_PROFILE',
    dataCoverage = 'FULL',
    isEstimate = true,
    points = []
  }) {
    const recordId = id || `fc_${homeId}_${scopeType}_${scopeId || homeId}_${horizon}_${Date.now()}`;
    const record = {
      id: recordId,
      home_id: homeId,
      scope_type: scopeType,
      scope_id: scopeId || homeId,
      horizon,
      start_time: startTime,
      end_time: endTime,
      predicted_kwh: Number(predictedKwh),
      predicted_cost: Number(predictedCost),
      currency: currency.toUpperCase(),
      confidence_score: Number(confidenceScore),
      methodology,
      data_coverage: dataCoverage,
      is_estimate: Boolean(isEstimate),
      points_json: points,
      created_at: new Date().toISOString()
    };
    return this.db.insert('energy_forecasts', recordId, record);
  }

  async findLatestForecast(homeId, { scopeType = 'home', scopeId = null, horizon = null } = {}) {
    const targetScopeId = scopeId || homeId;
    const list = await this.db.find('energy_forecasts', f => {
      if (f.home_id !== homeId) return false;
      if (scopeType && f.scope_type !== scopeType) return false;
      if (targetScopeId && f.scope_id !== targetScopeId) return false;
      if (horizon && f.horizon !== horizon) return false;
      return true;
    });
    if (list.length === 0) return null;
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list[0];
  }

  async findByHomeId(homeId, { horizon = null, limit = 50 } = {}) {
    let list = await this.db.find('energy_forecasts', f => {
      if (f.home_id !== homeId) return false;
      if (horizon && f.horizon !== horizon) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list.slice(0, limit);
  }

  async pruneOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('energy_forecasts', f => new Date(f.created_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('energy_forecasts', s.id);
    }
    return stale.length;
  }
}

class EnergyAnomalyRepository {
  constructor(db) {
    this.db = db;
  }

  async createAnomaly({
    id = null,
    homeId,
    scopeType = 'device',
    scopeId,
    anomalyType,
    severity = 'LOW',
    observedValue,
    baselineValue,
    deviationPercentage,
    isConfirmed = false,
    confirmationCount = 1,
    evidence = {},
    detectedAt = null
  }) {
    const recordId = id || `anom_${homeId}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const record = {
      id: recordId,
      home_id: homeId,
      scope_type: scopeType,
      scope_id: scopeId,
      anomaly_type: anomalyType,
      severity,
      observed_value: Number(observedValue),
      baseline_value: Number(baselineValue),
      deviation_percentage: Number(deviationPercentage),
      is_confirmed: Boolean(isConfirmed),
      confirmation_count: Number(confirmationCount),
      evidence_json: evidence,
      detected_at: detectedAt || new Date().toISOString(),
      created_at: new Date().toISOString()
    };
    return this.db.insert('energy_anomalies', recordId, record);
  }

  async findById(id) {
    return this.db.findById('energy_anomalies', id);
  }

  async confirmAnomaly(id) {
    const existing = await this.findById(id);
    if (!existing) return null;
    return this.db.update('energy_anomalies', id, {
      is_confirmed: true,
      confirmation_count: (existing.confirmation_count || 1) + 1
    });
  }

  async findByHomeId(homeId, { scopeType = null, scopeId = null, severity = null, limit = 100 } = {}) {
    let list = await this.db.find('energy_anomalies', a => {
      if (a.home_id !== homeId) return false;
      if (scopeType && a.scope_type !== scopeType) return false;
      if (scopeId && a.scope_id !== scopeId) return false;
      if (severity && a.severity !== severity) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.detected_at || b.created_at) - new Date(a.detected_at || a.created_at));
    return list.slice(0, limit);
  }

  async pruneOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('energy_anomalies', a => new Date(a.created_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('energy_anomalies', s.id);
    }
    return stale.length;
  }
}

class EnergyBaselineRepository {
  constructor(db) {
    this.db = db;
  }

  async upsertBaseline({
    homeId,
    scopeType = 'device',
    scopeId,
    typicalPowerW,
    typicalDailyEnergyKwh,
    typicalOvernightWh,
    typicalOperatingHours = [],
    sampleCount = 0,
    confidence = 0.5,
    calculatedAt = null
  }) {
    const id = `base_${homeId}_${scopeType}_${scopeId}`;
    const record = {
      id,
      home_id: homeId,
      scope_type: scopeType,
      scope_id: scopeId,
      typical_power_w: Number(typicalPowerW),
      typical_daily_kwh: Number(typicalDailyEnergyKwh),
      typical_overnight_wh: Number(typicalOvernightWh),
      typical_operating_hours: typicalOperatingHours,
      sample_count: Number(sampleCount),
      confidence: Number(confidence),
      calculated_at: calculatedAt || new Date().toISOString(),
      created_at: new Date().toISOString()
    };

    const existing = await this.db.findById('energy_baselines', id);
    if (existing) {
      return this.db.update('energy_baselines', id, record);
    }
    return this.db.insert('energy_baselines', id, record);
  }

  async findByScope(homeId, scopeType, scopeId) {
    const id = `base_${homeId}_${scopeType}_${scopeId}`;
    return this.db.findById('energy_baselines', id);
  }

  async findByHomeId(homeId) {
    return this.db.find('energy_baselines', b => b.home_id === homeId);
  }

  async pruneOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('energy_baselines', b => new Date(b.created_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('energy_baselines', s.id);
    }
    return stale.length;
  }
}

class ForecastAccuracyRepository {
  constructor(db) {
    this.db = db;
  }

  async recordAccuracy({
    id = null,
    homeId,
    forecastId = null,
    horizon,
    predictedValue,
    actualValue,
    calculatedAt = null
  }) {
    const recordId = id || `acc_${homeId}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const pred = Number(predictedValue);
    const act = Number(actualValue);
    const absErr = Math.abs(pred - act);
    const pctErr = act > 0 ? (absErr / act) * 100.0 : 0.0;

    const record = {
      id: recordId,
      home_id: homeId,
      forecast_id: forecastId,
      horizon,
      predicted_value: pred,
      actual_value: act,
      absolute_error: absErr,
      percentage_error: pctErr,
      calculated_at: calculatedAt || new Date().toISOString(),
      created_at: new Date().toISOString()
    };
    return this.db.insert('forecast_accuracy_records', recordId, record);
  }

  async findByHomeId(homeId, { horizon = null, limit = 100 } = {}) {
    let list = await this.db.find('forecast_accuracy_records', r => {
      if (r.home_id !== homeId) return false;
      if (horizon && r.horizon !== horizon) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.calculated_at || b.created_at) - new Date(a.calculated_at || a.created_at));
    return list.slice(0, limit);
  }

  async getAggregateMetrics(homeId, horizon = null) {
    const records = await this.findByHomeId(homeId, { horizon, limit: 500 });
    if (records.length === 0) {
      return { sampleCount: 0, mae: 0, mape: 0, hasSufficientData: false };
    }
    const sumAbs = records.reduce((acc, r) => acc + Number(r.absolute_error || 0), 0);
    const sumPct = records.reduce((acc, r) => acc + Number(r.percentage_error || 0), 0);
    const mae = Math.round((sumAbs / records.length) * 1000) / 1000;
    const mape = Math.round((sumPct / records.length) * 10) / 10;
    return {
      sampleCount: records.length,
      mae,
      mape,
      hasSufficientData: records.length >= 3
    };
  }

  async pruneOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('forecast_accuracy_records', r => new Date(r.created_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('forecast_accuracy_records', s.id);
    }
    return stale.length;
  }
}

class EnergyEfficiencyScoreRepository {
  constructor(db) {
    this.db = db;
  }

  async saveScore({
    id = null,
    homeId,
    score,
    grade,
    factors = {},
    evidence = {},
    calculatedAt = null
  }) {
    const recordId = id || `eff_${homeId}_${Date.now()}`;
    const record = {
      id: recordId,
      home_id: homeId,
      score: Number(score),
      grade,
      factors_json: factors,
      evidence_json: evidence,
      calculated_at: calculatedAt || new Date().toISOString(),
      created_at: new Date().toISOString()
    };
    return this.db.insert('energy_efficiency_scores', recordId, record);
  }

  async findLatest(homeId) {
    const list = await this.db.find('energy_efficiency_scores', s => s.home_id === homeId);
    if (list.length === 0) return null;
    list.sort((a, b) => new Date(b.calculated_at || b.created_at) - new Date(a.calculated_at || a.created_at));
    return list[0];
  }

  async findByHomeId(homeId, { limit = 20 } = {}) {
    let list = await this.db.find('energy_efficiency_scores', s => s.home_id === homeId);
    list.sort((a, b) => new Date(b.calculated_at || b.created_at) - new Date(a.calculated_at || a.created_at));
    return list.slice(0, limit);
  }

  async pruneOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('energy_efficiency_scores', s => new Date(s.created_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('energy_efficiency_scores', s.id);
    }
    return stale.length;
  }
}

class PresenceSignalRepository {
  constructor(db) {
    this.db = db;
  }

  async recordSignal({
    id = null,
    userId,
    homeId,
    source,
    state,
    confidence = 1.0,
    evidence = {},
    observedAt = null,
    expiresAt = null
  }) {
    const sigId = id || `sig_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const nowIso = new Date().toISOString();
    return this.db.insert('presence_signals', sigId, {
      user_id: userId,
      home_id: homeId,
      source,
      state,
      confidence: Number(confidence),
      evidence_json: JSON.stringify(evidence || {}),
      observed_at: observedAt || nowIso,
      expires_at: expiresAt || null,
      created_at: nowIso
    });
  }

  async getSignalsByHome(homeId, { limit = 50, from = null, userId = null } = {}) {
    let list = await this.db.find('presence_signals', s => {
      if (s.home_id !== homeId) return false;
      if (userId && s.user_id !== userId) return false;
      if (from && new Date(s.observed_at) < new Date(from)) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.observed_at) - new Date(a.observed_at));
    return list.slice(0, limit);
  }

  async getLatestSignalForUser(homeId, userId) {
    const list = await this.db.find('presence_signals', s => s.home_id === homeId && s.user_id === userId);
    if (list.length === 0) return null;
    list.sort((a, b) => new Date(b.observed_at) - new Date(a.observed_at));
    return list[0];
  }

  async pruneOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('presence_signals', s => new Date(s.observed_at || s.created_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('presence_signals', s.id);
    }
    return stale.length;
  }
}

class PresenceStateRepository {
  constructor(db) {
    this.db = db;
  }

  async upsertUserState({
    homeId,
    userId,
    state,
    confidence = 1.0,
    source = 'mobile_app',
    isStale = 0,
    lastObservedAt = null,
    expiresAt = null
  }) {
    const id = `${homeId}_${userId}`;
    const nowIso = new Date().toISOString();
    const existing = await this.db.findById('presence_states', id);
    if (existing) {
      return this.db.update('presence_states', id, {
        state,
        confidence: Number(confidence),
        source,
        is_stale: isStale ? 1 : 0,
        last_observed_at: lastObservedAt || nowIso,
        expires_at: expiresAt || null,
        updated_at: nowIso
      });
    }

    return this.db.insert('presence_states', id, {
      home_id: homeId,
      user_id: userId,
      state,
      confidence: Number(confidence),
      source,
      is_stale: isStale ? 1 : 0,
      last_observed_at: lastObservedAt || nowIso,
      expires_at: expiresAt || null,
      updated_at: nowIso
    });
  }

  async getUserState(homeId, userId) {
    const id = `${homeId}_${userId}`;
    return this.db.findById('presence_states', id);
  }

  async getHomeStates(homeId) {
    return this.db.find('presence_states', s => s.home_id === homeId);
  }

  async deleteByHome(homeId) {
    const list = await this.getHomeStates(homeId);
    for (const s of list) {
      await this.db.delete('presence_states', s.id);
    }
    return list.length;
  }
}

class HomeContextRepository {
  constructor(db) {
    this.db = db;
  }

  async upsertHomeContext({
    homeId,
    mode = 'HOME',
    previousMode = null,
    precedenceTier = 'DEFAULT_FALLBACK',
    activeOverrideId = null,
    isVacation = 0,
    isOccupied = 1,
    confidence = 1.0,
    updatedAt = null
  }) {
    const nowIso = updatedAt || new Date().toISOString();
    const existing = await this.db.findById('home_contexts', homeId);
    if (existing) {
      return this.db.update('home_contexts', homeId, {
        mode,
        previous_mode: previousMode !== undefined ? previousMode : existing.mode,
        precedence_tier: precedenceTier,
        active_override_id: activeOverrideId,
        is_vacation: isVacation ? 1 : 0,
        is_occupied: isOccupied ? 1 : 0,
        confidence: Number(confidence),
        updated_at: nowIso
      });
    }

    return this.db.insert('home_contexts', homeId, {
      mode,
      previous_mode: previousMode || null,
      precedence_tier: precedenceTier,
      active_override_id: activeOverrideId || null,
      is_vacation: isVacation ? 1 : 0,
      is_occupied: isOccupied ? 1 : 0,
      confidence: Number(confidence),
      updated_at: nowIso
    });
  }

  async getHomeContext(homeId) {
    return this.db.findById('home_contexts', homeId);
  }
}

class ContextOverrideRepository {
  constructor(db) {
    this.db = db;
  }

  async createOverride({
    id = null,
    homeId,
    userId,
    mode,
    state = null,
    reason = '',
    expiresAt = null,
    isActive = 1
  }) {
    const ovrId = id || `ovr_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const nowIso = new Date().toISOString();
    return this.db.insert('context_overrides', ovrId, {
      home_id: homeId,
      user_id: userId,
      mode,
      state: state || (mode === 'VACATION' || mode === 'AWAY' ? 'AWAY' : 'HOME'),
      reason: reason || '',
      is_active: isActive ? 1 : 0,
      created_at: nowIso,
      expires_at: expiresAt || null
    });
  }

  async getActiveOverride(homeId) {
    const list = await this.db.find('context_overrides', o => o.home_id === homeId && o.is_active === 1);
    if (list.length === 0) return null;
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    const latest = list[0];
    if (latest.expires_at && new Date(latest.expires_at) < new Date()) {
      await this.clearOverride(latest.id);
      return null;
    }
    return latest;
  }

  async getOverridesByHome(homeId, { limit = 20, includeInactive = false } = {}) {
    let list = await this.db.find('context_overrides', o => {
      if (o.home_id !== homeId) return false;
      if (!includeInactive && o.is_active !== 1) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list.slice(0, limit);
  }

  async clearOverride(id) {
    const existing = await this.db.findById('context_overrides', id);
    if (existing) {
      return this.db.update('context_overrides', id, { is_active: 0 });
    }
    return null;
  }

  async clearActiveOverridesForHome(homeId) {
    const list = await this.db.find('context_overrides', o => o.home_id === homeId && o.is_active === 1);
    for (const o of list) {
      await this.db.update('context_overrides', o.id, { is_active: 0 });
    }
    return list.length;
  }
}

class ContextTransitionRepository {
  constructor(db) {
    this.db = db;
  }

  async recordTransition({
    id = null,
    homeId,
    fromMode,
    toMode,
    triggerSource,
    reason = '',
    evidence = {},
    createdAt = null
  }) {
    const transId = id || `trans_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const nowIso = createdAt || new Date().toISOString();
    return this.db.insert('context_transitions', transId, {
      home_id: homeId,
      from_mode: fromMode || 'UNKNOWN',
      to_mode: toMode,
      trigger_source: triggerSource,
      reason: reason || '',
      evidence_json: JSON.stringify(evidence || {}),
      created_at: nowIso
    });
  }

  async getTransitionsByHome(homeId, { limit = 50, from = null } = {}) {
    let list = await this.db.find('context_transitions', t => {
      if (t.home_id !== homeId) return false;
      if (from && new Date(t.created_at) < new Date(from)) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list.slice(0, limit);
  }

  async pruneOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('context_transitions', t => new Date(t.created_at) < cutoffDate);
    for (const t of stale) {
      await this.db.delete('context_transitions', t.id);
    }
    return stale.length;
  }
}

// -----------------------------------------------------------------------------
// Phase 24: Smart Home Intelligence & Unified Decision Repositories
// -----------------------------------------------------------------------------

class IntelligenceDecisionRepository {
  constructor(db) {
    this.db = db;
  }

  async createDecision(data) {
    const id = data.id || `dec_${data.homeId || data.home_id}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const record = {
      id,
      home_id: data.homeId || data.home_id,
      decision_type: data.decisionType || data.decision_type,
      priority: data.priority,
      priority_rank: data.priorityRank !== undefined ? data.priorityRank : (data.priority_rank !== undefined ? data.priority_rank : 7),
      confidence: data.confidence || 'MEDIUM',
      confidence_score: data.confidenceScore !== undefined ? data.confidenceScore : (data.confidence_score !== undefined ? data.confidence_score : 0.5),
      risk: data.risk || 'LOW',
      evidence: data.evidence || {},
      proposed_action: data.proposedAction || data.proposed_action || {},
      expected_effect: data.expectedEffect || data.expected_effect || '',
      is_auto_executable: Boolean(data.isAutoExecutable ?? data.is_auto_executable ?? false),
      safety_result: data.safetyResult || data.safety_result || { isSafe: true, riskLevel: 'LOW' },
      status: data.status || 'GENERATED',
      created_at: data.createdAt || data.created_at || new Date().toISOString(),
      expires_at: data.expiresAt || data.expires_at || null
    };
    return this.db.insert('intelligence_decisions', id, record);
  }

  async getDecisionById(id) {
    return this.db.findById('intelligence_decisions', id);
  }

  async getDecisionsByHome(homeId, { limit = 50, status = null, priority = null } = {}) {
    let list = await this.db.find('intelligence_decisions', d => {
      if (d.home_id !== homeId) return false;
      if (status && d.status !== status) return false;
      if (priority && d.priority !== priority) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list.slice(0, limit);
  }

  async updateDecisionStatus(id, status) {
    return this.db.update('intelligence_decisions', id, { status });
  }

  async purgeOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('intelligence_decisions', d => new Date(d.created_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('intelligence_decisions', s.id);
    }
    return stale.length;
  }
}

class IntelligenceRecommendationRepository {
  constructor(db) {
    this.db = db;
  }

  async createRecommendation(data) {
    const id = data.id || `rec_${data.homeId || data.home_id}_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const record = {
      id,
      home_id: data.homeId || data.home_id,
      recommendation_type: data.recommendationType || data.recommendation_type,
      priority: data.priority || 'CONVENIENCE_RECOMMENDATION',
      priority_rank: data.priorityRank !== undefined ? data.priorityRank : (data.priority_rank !== undefined ? data.priority_rank : 7),
      confidence: data.confidence || 'MEDIUM',
      risk: data.risk || 'LOW',
      title: data.title,
      description: data.description || '',
      evidence: data.evidence || {},
      proposed_action: data.proposedAction || data.proposed_action || {},
      expected_benefit: data.expectedBenefit || data.expected_benefit || '',
      is_auto_executable: Boolean(data.isAutoExecutable ?? data.is_auto_executable ?? false),
      status: data.status || 'GENERATED',
      created_at: data.createdAt || data.created_at || new Date().toISOString(),
      expires_at: data.expiresAt || data.expires_at || null
    };
    return this.db.insert('intelligence_recommendations', id, record);
  }

  async getRecommendationById(id) {
    return this.db.findById('intelligence_recommendations', id);
  }

  async getRecommendationsByHome(homeId, { limit = 50, status = null, type = null } = {}) {
    let list = await this.db.find('intelligence_recommendations', r => {
      if (r.home_id !== homeId) return false;
      if (status && r.status !== status) return false;
      if (type && r.recommendation_type !== type) return false;
      return true;
    });
    list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    return list.slice(0, limit);
  }

  async updateRecommendationStatus(id, status) {
    return this.db.update('intelligence_recommendations', id, { status });
  }

  async purgeOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('intelligence_recommendations', r => new Date(r.created_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('intelligence_recommendations', s.id);
    }
    return stale.length;
  }
}

class IntelligenceOutcomeRepository {
  constructor(db) {
    this.db = db;
  }

  async recordOutcome(data) {
    const id = data.id || `out_${data.decisionId || data.decision_id || data.homeId}_${Date.now()}`;
    const record = {
      id,
      decision_id: data.decisionId || data.decision_id || '',
      home_id: data.homeId || data.home_id,
      status: data.status,
      executed_at: data.executedAt || data.executed_at || new Date().toISOString(),
      previous_state: data.previousState || data.previous_state || {},
      new_state: data.newState || data.new_state || {},
      expected_benefit: data.expectedBenefit || data.expected_benefit || '',
      actual_benefit: data.actualBenefit || data.actual_benefit || '',
      feedback: data.feedback || '',
      failure_reason: data.failureReason || data.failure_reason || null,
      created_at: data.createdAt || data.created_at || new Date().toISOString()
    };
    return this.db.insert('intelligence_decision_outcomes', id, record);
  }

  async getOutcomesByHome(homeId, { limit = 50 } = {}) {
    let list = await this.db.find('intelligence_decision_outcomes', o => o.home_id === homeId);
    list.sort((a, b) => new Date(b.executed_at || b.created_at) - new Date(a.executed_at || a.created_at));
    return list.slice(0, limit);
  }

  async getOutcomeByDecisionId(decisionId) {
    const list = await this.db.find('intelligence_decision_outcomes', o => o.decision_id === decisionId);
    return list.length > 0 ? list[0] : null;
  }

  async purgeOlderThan(cutoffIso) {
    const cutoffDate = new Date(cutoffIso);
    const stale = await this.db.find('intelligence_decision_outcomes', o => new Date(o.created_at || o.executed_at) < cutoffDate);
    for (const s of stale) {
      await this.db.delete('intelligence_decision_outcomes', s.id);
    }
    return stale.length;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 25 — Proactive Device Reliability + Self-Healing Repositories
// ─────────────────────────────────────────────────────────────────────────────

class ReliabilityIncidentRepository {
  constructor(db) { this.db = db; }

  async create(data) { return this.db.insert('reliability_incidents', data.id, data); }
  async findById(id) { return this.db.findById('reliability_incidents', id); }
  async update(id, updates) { return this.db.update('reliability_incidents', id, updates); }

  async findForDevice(deviceId) {
    return this.db.find('reliability_incidents', r => r.device_id === deviceId);
  }
  async findActiveForDevice(deviceId) {
    return this.db.find('reliability_incidents', r =>
      r.device_id === deviceId && ['OPEN', 'INVESTIGATING'].includes(r.status)
    );
  }
  async findActiveForHome(homeId) {
    return this.db.find('reliability_incidents', r =>
      r.home_id === homeId && ['OPEN', 'INVESTIGATING'].includes(r.status)
    );
  }
  async findOpenByTypeAndDevice(deviceId, incidentType) {
    const res = await this.db.find('reliability_incidents', r =>
      r.device_id === deviceId && r.incident_type === incidentType && r.status === 'OPEN'
    );
    return res[0] || null;
  }
  async incrementSignal(id, updates) {
    const existing = await this.db.findById('reliability_incidents', id);
    if (!existing) return null;
    return this.db.update('reliability_incidents', id, {
      signal_count: (existing.signal_count || 1) + 1,
      ...updates
    });
  }
}

class ReliabilityDiagnosticRepository {
  constructor(db) { this.db = db; }
  async create(data) { return this.db.insert('reliability_diagnostics', data.id, data); }
  async findById(id) { return this.db.findById('reliability_diagnostics', id); }
  async findForIncident(incidentId) {
    return this.db.find('reliability_diagnostics', d => d.incident_id === incidentId);
  }
  async findForDevice(deviceId) {
    return this.db.find('reliability_diagnostics', d => d.device_id === deviceId);
  }
}

class ReliabilityRecoveryRepository {
  constructor(db) { this.db = db; }
  async create(data) { return this.db.insert('reliability_recovery_attempts', data.id, data); }
  async findById(id) { return this.db.findById('reliability_recovery_attempts', id); }
  async update(id, updates) { return this.db.update('reliability_recovery_attempts', id, updates); }

  async findForIncident(incidentId) {
    return this.db.find('reliability_recovery_attempts', r => r.incident_id === incidentId);
  }
  async findForDevice(deviceId, limit = 20) {
    const all = await this.db.find('reliability_recovery_attempts', r => r.device_id === deviceId);
    return all.sort((a, b) => new Date(b.initiated_at) - new Date(a.initiated_at)).slice(0, limit);
  }
  async findPendingForHome(homeId) {
    return this.db.find('reliability_recovery_attempts', r =>
      r.home_id === homeId && ['PENDING', 'EXECUTING', 'VERIFYING'].includes(r.status)
    );
  }
}

class ReliabilityHealthSnapshotRepository {
  constructor(db) { this.db = db; }
  async create(data) { return this.db.insert('reliability_health_snapshots', data.id, data); }
  async findById(id) { return this.db.findById('reliability_health_snapshots', id); }
  async findLatestForDevice(deviceId) {
    const all = await this.db.find('reliability_health_snapshots', s => s.device_id === deviceId);
    return all.sort((a, b) => new Date(b.snapshotted_at) - new Date(a.snapshotted_at))[0] || null;
  }
  async findForHome(homeId) {
    return this.db.find('reliability_health_snapshots', s => s.home_id === homeId);
  }
}

class MaintenanceRecommendationRepository {
  constructor(db) { this.db = db; }
  async create(data) { return this.db.insert('maintenance_recommendations', data.id, data); }
  async findById(id) { return this.db.findById('maintenance_recommendations', id); }
  async update(id, updates) { return this.db.update('maintenance_recommendations', id, updates); }
  async findForHome(homeId) {
    return this.db.find('maintenance_recommendations', r => r.home_id === homeId);
  }
  async findForDevice(deviceId) {
    return this.db.find('maintenance_recommendations', r => r.device_id === deviceId);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Phase 26 — Multi-Protocol Device Connectivity & Interoperability Repositories
// ═══════════════════════════════════════════════════════════════════════════

class DeviceTransportRepository {
  constructor(db) {
    this.db = db;
  }

  async create({
    id,
    home_id,
    device_id,
    transport_type,
    is_active = 0,
    is_supported = 1,
    priority_rank = 1,
    config = '{}'
  }) {
    return this.db.insert('device_transports', id, {
      home_id,
      device_id,
      transport_type,
      is_active,
      is_supported,
      priority_rank,
      config,
      created_at: new Date().toISOString()
    });
  }

  async findById(id) {
    return this.db.findById('device_transports', id);
  }

  async findByDevice(deviceId) {
    const records = await this.db.find('device_transports', t => t.device_id === deviceId);
    return records.sort((a, b) => a.priority_rank - b.priority_rank);
  }

  async findByHome(homeId) {
    return this.db.find('device_transports', t => t.home_id === homeId);
  }

  async findActiveForDevice(deviceId) {
    const records = await this.db.find('device_transports', t => t.device_id === deviceId && t.is_active === 1);
    return records[0] || null;
  }

  async update(id, updates) {
    return this.db.update('device_transports', id, {
      ...updates,
      updated_at: new Date().toISOString()
    });
  }

  async setActiveTransport(deviceId, transportType) {
    const transports = await this.findByDevice(deviceId);
    for (const t of transports) {
      const isActive = t.transport_type === transportType ? 1 : 0;
      if (t.is_active !== isActive) {
        await this.update(t.id, { is_active: isActive });
      }
    }
  }
}

class DeviceConnectionStateRepository {
  constructor(db) {
    this.db = db;
  }

  async create({
    id,
    home_id,
    device_id,
    active_transport,
    connection_state = 'DISCONNECTED',
    last_connected_at = null,
    last_disconnected_at = null,
    reconnect_count = 0,
    last_error = null
  }) {
    return this.db.insert('device_connection_states', id, {
      home_id,
      device_id,
      active_transport,
      connection_state,
      last_connected_at,
      last_disconnected_at,
      reconnect_count,
      last_error,
      updated_at: new Date().toISOString()
    });
  }

  async findById(id) {
    return this.db.findById('device_connection_states', id);
  }

  async findByDeviceId(deviceId) {
    const records = await this.db.find('device_connection_states', s => s.device_id === deviceId);
    return records[0] || null;
  }

  async findByHome(homeId) {
    return this.db.find('device_connection_states', s => s.home_id === homeId);
  }

  async update(id, updates) {
    return this.db.update('device_connection_states', id, {
      ...updates,
      updated_at: new Date().toISOString()
    });
  }

  async upsertState(deviceId, homeId, updates) {
    const existing = await this.findByDeviceId(deviceId);
    if (existing) {
      return this.update(existing.id, updates);
    }
    const id = `conn_${deviceId}`;
    return this.create({
      id,
      home_id: homeId,
      device_id: deviceId,
      active_transport: updates.active_transport || 'WIFI_MQTT',
      connection_state: updates.connection_state || 'DISCONNECTED',
      last_connected_at: updates.last_connected_at || null,
      last_disconnected_at: updates.last_disconnected_at || null,
      reconnect_count: updates.reconnect_count || 0,
      last_error: updates.last_error || null
    });
  }
}

class CommissioningSessionRepository {
  constructor(db) {
    this.db = db;
  }

  async create({
    id,
    home_id,
    device_id,
    transport_type,
    stage = 'DISCOVERED',
    auth_method = null,
    error_details = null,
    started_at = new Date().toISOString()
  }) {
    return this.db.insert('commissioning_sessions', id, {
      home_id,
      device_id,
      transport_type,
      stage,
      auth_method,
      error_details,
      started_at,
      completed_at: null,
      created_at: new Date().toISOString()
    });
  }

  async findById(id) {
    return this.db.findById('commissioning_sessions', id);
  }

  async findByDevice(deviceId) {
    const records = await this.db.find('commissioning_sessions', s => s.device_id === deviceId);
    return records.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
  }

  async findByHome(homeId) {
    const records = await this.db.find('commissioning_sessions', s => s.home_id === homeId);
    return records.sort((a, b) => new Date(b.started_at) - new Date(a.started_at));
  }

  async findActiveForDevice(deviceId) {
    const records = await this.db.find('commissioning_sessions', s =>
      s.device_id === deviceId && !['COMPLETED', 'FAILED', 'CANCELLED'].includes(s.stage)
    );
    return records[0] || null;
  }

  async update(id, updates) {
    return this.db.update('commissioning_sessions', id, {
      ...updates,
      updated_at: new Date().toISOString()
    });
  }
}

class TransportHealthSnapshotRepository {
  constructor(db) {
    this.db = db;
  }

  async create({
    id,
    home_id,
    device_id,
    transport_type,
    latency_ms = 0.0,
    error_rate = 0.0,
    availability = 'ONLINE',
    metrics = '{}',
    snapshotted_at = new Date().toISOString()
  }) {
    return this.db.insert('transport_health_snapshots', id, {
      home_id,
      device_id,
      transport_type,
      latency_ms,
      error_rate,
      availability,
      metrics,
      snapshotted_at,
      created_at: new Date().toISOString()
    });
  }

  async findById(id) {
    return this.db.findById('transport_health_snapshots', id);
  }

  async findLatestForDevice(deviceId, transportType = null) {
    const records = await this.db.find('transport_health_snapshots', s =>
      s.device_id === deviceId && (!transportType || s.transport_type === transportType)
    );
    return records.sort((a, b) => new Date(b.snapshotted_at) - new Date(a.snapshotted_at))[0] || null;
  }

  async findForDevice(deviceId, limit = 50) {
    const records = await this.db.find('transport_health_snapshots', s => s.device_id === deviceId);
    return records.sort((a, b) => new Date(b.snapshotted_at) - new Date(a.snapshotted_at)).slice(0, limit);
  }

  async findByHome(homeId, limit = 100) {
    const records = await this.db.find('transport_health_snapshots', s => s.home_id === homeId);
    return records.sort((a, b) => new Date(b.snapshotted_at) - new Date(a.snapshotted_at)).slice(0, limit);
  }
}

module.exports = {
  UserRepository,
  HomeRepository,
  RoomRepository,
  ProductRepository,
  CapabilityRepository,
  DeviceRepository,
  DeviceStateRepository,
  CommandRepository,
  EventRepository,
  AuditRepository,
  OutboxRepository,
  ProvisioningSessionRepository,
  RefreshTokenRepository,
  SceneRepository,
  AutomationRepository,
  ScheduleRepository,
  AutomationExecutionLogRepository,
  DeviceActivityLogRepository,
  DeviceHealthRepository,
  NotificationRepository,
  InvitationRepository,
  SyncRepository,
  ExportRepository,
  FirmwareReleaseRepository,
  OtaOperationRepository,
  OtaRolloutRepository,
  DeviceMaintenanceRepository,
  DeviceTelemetryRepository,
  TelemetryAggregateRepository,
  EnergyThresholdRepository,
  EnergyEventRepository,
  EnergyAutomationExecutionRepository,
  EnergyOptimizationRepository,
  EnergyTariffRepository,
  TariffPeriodRepository,
  EnergyBudgetRepository,
  CostOptimizationRepository,
  EnergyForecastRepository,
  EnergyAnomalyRepository,
  EnergyBaselineRepository,
  ForecastAccuracyRepository,
  EnergyEfficiencyScoreRepository,
  PresenceSignalRepository,
  PresenceStateRepository,
  HomeContextRepository,
  ContextOverrideRepository,
  ContextTransitionRepository,
  IntelligenceDecisionRepository,
  IntelligenceRecommendationRepository,
  IntelligenceOutcomeRepository,
  // Phase 25 — Reliability
  ReliabilityIncidentRepository,
  ReliabilityDiagnosticRepository,
  ReliabilityRecoveryRepository,
  ReliabilityHealthSnapshotRepository,
  MaintenanceRecommendationRepository,
  // Phase 26 — Multi-Protocol Connectivity
  DeviceTransportRepository,
  DeviceConnectionStateRepository,
  CommissioningSessionRepository,
  TransportHealthSnapshotRepository,
  // Phase 27 — Product Discovery & Consumer Device Add
  DeviceAddSessionRepository: require('./device-add-session.repository').DeviceAddSessionRepository,
  // Phase 28 — Local-First Home Control & Edge Execution
  LocalRouteCacheRepository: require('./local-route-cache.repository').LocalRouteCacheRepository,
  EdgeExecutionRepository: require('./edge-execution.repository').EdgeExecutionRepository,
  LocalDiscoveryNodeRepository: require('./local-discovery-node.repository').LocalDiscoveryNodeRepository,
  // Phase 29 — Matter Ecosystem Interoperability & Multi-Platform Integration
  MatterDeviceRepository: require('./matter-device.repository').MatterDeviceRepository,
  MatterFabricRepository: require('./matter-fabric.repository').MatterFabricRepository,
  ExternalPlatformLinkRepository: require('./external-platform-link.repository').ExternalPlatformLinkRepository
};
