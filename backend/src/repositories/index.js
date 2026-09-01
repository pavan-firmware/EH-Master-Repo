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

  async createHome({ id, name, timezone = 'UTC', address = null, ownerId }) {
    const homeId = id || require('crypto').randomUUID();
    // Verify owner exists
    const owner = await this.db.findById('users', ownerId);
    if (!owner) throw new Error(`Owner user ${ownerId} does not exist`);

    const home = await this.db.insert('homes', homeId, {
      name,
      timezone,
      address,
      owner_id: ownerId
    });

    // Auto-create owner membership
    await this.addMembership({
      id: `${homeId}_${ownerId}`,
      homeId: homeId,
      userId: ownerId,
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

  async addMembership({ id, homeId, userId, role, acceptedAt = null }) {
    const user = await this.db.findById('users', userId);
    if (!user) throw new Error(`User ${userId} does not exist`);
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    const existing = await this.db.find('home_memberships', m => m.home_id === homeId && m.user_id === userId);
    if (existing.length > 0) {
      throw new Error(`Membership for user ${userId} in home ${homeId} already exists`);
    }

    return this.db.insert('home_memberships', id, {
      home_id: homeId,
      user_id: userId,
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

  async createRoom({ id, homeId, floorId = null, name, iconKey = 'default', sortOrder = 0 }) {
    const roomId = id || require('crypto').randomUUID();
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);
    if (floorId) {
      const floor = await this.db.findById('floors', floorId);
      if (!floor) throw new Error(`Floor ${floorId} does not exist`);
      if (floor.home_id !== homeId) {
        throw new Error(`Floor ${floorId} belongs to home ${floor.home_id}, not home ${homeId}`);
      }
    }
    return this.db.insert('rooms', roomId, {
      home_id: homeId,
      floor_id: floorId,
      name,
      icon_key: iconKey,
      sort_order: sortOrder
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

  async claimDevice({ deviceId, homeId, roomId = null, customName, channelLabels = {}, claimedByUserId }) {
    const dev = await this.db.findById('devices', deviceId);
    if (!dev) throw new Error(`Device ${deviceId} does not exist`);
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);

    if (roomId) {
      const room = await this.db.findById('rooms', roomId);
      if (!room) throw new Error(`Room ${roomId} does not exist`);
      if (room.home_id !== homeId) {
        throw new Error(`Room ${roomId} belongs to home ${room.home_id}, not home ${homeId}`);
      }
    }

    const existingAuth = await this.db.findById('device_authorizations', deviceId);
    if (existingAuth) throw new Error(`Device ${deviceId} is already claimed by home ${existingAuth.home_id}`);

    return this.db.insert('device_authorizations', deviceId, {
      device_id: deviceId,
      home_id: homeId,
      room_id: roomId,
      custom_name: customName,
      channel_labels: channelLabels,
      claimed_by_user_id: claimedByUserId,
      claimed_at: new Date().toISOString()
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

  async getDevice(deviceId) {
    return this.db.findById('devices', deviceId);
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
    title,
    body,
    entityType = null,
    entityId = null,
    data = {},
    deliveryStatus = 'PENDING',
    idempotencyKey = null,
    readAt = null
  }) {
    if (idempotencyKey) {
      const existing = await this.db.find('notifications', n => n.idempotency_key === idempotencyKey);
      if (existing.length > 0) {
        return existing[0];
      }
    }

    return this.db.insert('notifications', id, {
      user_id: userId,
      home_id: homeId,
      type,
      category,
      priority,
      title,
      body,
      entity_type: entityType,
      entity_id: entityId,
      data_json: data,
      read_at: readAt,
      delivery_status: deliveryStatus,
      idempotency_key: idempotencyKey
    });
  }

  async findById(id) {
    return this.db.findById('notifications', id);
  }

  async findUserNotifications(userId, { homeId = null, category = null, limit = 50, offset = 0, unreadOnly = false } = {}) {
    const list = await this.db.find('notifications', n => {
      if (n.user_id && n.user_id !== userId) return false;
      if (homeId && n.home_id && n.home_id !== homeId) return false;
      if (category && n.category !== category) return false;
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

  async getPreferences(userId) {
    const records = await this.db.find('user_notification_preferences', p => p.user_id === userId);
    if (records.length > 0) {
      return records[0];
    }
    return {
      user_id: userId,
      push_enabled: true,
      critical_alerts: true,
      device_offline: true,
      automation_failure: true,
      firmware_updates: true
    };
  }

  async upsertPreferences(userId, prefs) {
    const existing = await this.db.find('user_notification_preferences', p => p.user_id === userId);
    const now = new Date().toISOString();
    if (existing.length > 0) {
      return this.db.update('user_notification_preferences', existing[0].id, {
        ...prefs,
        updated_at: now
      });
    }
    const id = `pref_${userId}`;
    return this.db.insert('user_notification_preferences', id, {
      user_id: userId,
      push_enabled: prefs.push_enabled !== undefined ? prefs.push_enabled : true,
      critical_alerts: prefs.critical_alerts !== undefined ? prefs.critical_alerts : true,
      device_offline: prefs.device_offline !== undefined ? prefs.device_offline : true,
      automation_failure: prefs.automation_failure !== undefined ? prefs.automation_failure : true,
      firmware_updates: prefs.firmware_updates !== undefined ? prefs.firmware_updates : true,
      created_at: now,
      updated_at: now
    });
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
  ExportRepository
};
