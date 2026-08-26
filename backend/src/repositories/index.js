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
}

class HomeRepository {
  constructor(db) {
    this.db = db;
  }

  async createHome({ id, name, timezone = 'UTC', address = null, ownerId }) {
    // Verify owner exists
    const owner = await this.db.findById('users', ownerId);
    if (!owner) throw new Error(`Owner user ${ownerId} does not exist`);

    const home = await this.db.insert('homes', id, {
      name,
      timezone,
      address,
      owner_id: ownerId
    });

    // Auto-create owner membership
    await this.addMembership({
      id: `${id}_${ownerId}`,
      homeId: id,
      userId: ownerId,
      role: 'OWNER',
      acceptedAt: new Date().toISOString()
    });

    return home;
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
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);
    return this.db.insert('floors', id, { home_id: homeId, name, level });
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
    const home = await this.db.findById('homes', homeId);
    if (!home) throw new Error(`Home ${homeId} does not exist`);
    if (floorId) {
      const floor = await this.db.findById('floors', floorId);
      if (!floor) throw new Error(`Floor ${floorId} does not exist`);
      if (floor.home_id !== homeId) {
        throw new Error(`Floor ${floorId} belongs to home ${floor.home_id}, not home ${homeId}`);
      }
    }
    return this.db.insert('rooms', id, {
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

  async updateDeviceAuthorization(deviceId, { homeId, roomId, customName, channelLabels, channelConfigs }) {
    const existing = await this.db.findById('device_authorizations', deviceId);
    if (!existing) throw new Error(`Device authorization for ${deviceId} not found`);

    const updates = {};
    if (homeId !== undefined) updates.home_id = homeId;
    if (roomId !== undefined) updates.room_id = roomId;
    if (customName !== undefined) updates.custom_name = customName;
    if (channelLabels !== undefined) updates.channel_labels = channelLabels;
    if (channelConfigs !== undefined) updates.channel_configs = channelConfigs;

    return this.db.update('device_authorizations', deviceId, updates);
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

  async createToken({ id, userId, tokenHash, expiresAt }) {
    return this.db.insert('refresh_tokens', id, {
      user_id: userId,
      token_hash: tokenHash,
      expires_at: expiresAt
    });
  }

  async findByTokenHash(tokenHash) {
    const tokens = await this.db.find('refresh_tokens', t => t.token_hash === tokenHash);
    return tokens.length > 0 ? tokens[0] : null;
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
  RefreshTokenRepository
};
