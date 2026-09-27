import { CommandEnvelope } from '@eh-home/contracts';
import { randomUUID } from 'crypto';

export interface IDeviceCommandRepository {
  recordCommand(cmd: CommandEnvelope): Promise<{ record: any; isIdempotentReplay: boolean }>;
  updateCommandStatus(commandId: string, status: string, failureReason?: string | null): Promise<void>;
  getCommand(commandId: string): Promise<any | null>;
  getDeviceState(deviceId: string): Promise<any | null>;
  updateChannelState(deviceId: string, channelIndex: number, state: { reportedState?: any; desiredState?: any; confidence?: string }): Promise<void>;
  updateConnectionState(deviceId: string, connectionState: 'ONLINE' | 'OFFLINE', source?: string): Promise<void>;
  enqueueOutbox(event: { eventType: string; aggregateId: string; payload: any }): Promise<void>;
}

export class DeviceCommandRepository implements IDeviceCommandRepository {
  private db: any;
  private commandsStore: Map<string, any> = new Map();
  private idempotencyIndex: Map<string, string> = new Map(); // `${deviceId}:${idempotencyKey}` -> commandId
  private deviceStateStore: Map<string, any> = new Map();
  private channelStateStore: Map<string, any> = new Map(); // `${deviceId}:${channelIndex}` -> state
  private availabilityHistoryStore: any[] = [];
  private outboxStore: any[] = [];

  constructor(db?: any) {
    this.db = db;
  }

  public async recordCommand(cmd: CommandEnvelope): Promise<{ record: any; isIdempotentReplay: boolean }> {
    const idemKey = `${cmd.deviceId}:${cmd.idempotencyKey}`;

    if (!this.db || !this.db.insert) {
      if (this.idempotencyIndex.has(idemKey)) {
        const existingId = this.idempotencyIndex.get(idemKey)!;
        const existing = this.commandsStore.get(existingId);
        return { record: existing, isIdempotentReplay: true };
      }

      const record = {
        id: cmd.commandId,
        deviceId: cmd.deviceId,
        channelIndex: cmd.channelIndex,
        action: cmd.action,
        params: cmd.params,
        idempotencyKey: cmd.idempotencyKey,
        source: cmd.source,
        status: 'CREATED',
        failureReason: null,
        createdAt: new Date().toISOString(),
        expiresAt: cmd.expiresAt,
        completedAt: null
      };
      this.commandsStore.set(cmd.commandId, record);
      this.idempotencyIndex.set(idemKey, cmd.commandId);
      return { record, isIdempotentReplay: false };
    }

    const { deviceCommands, eq, and } = require('@eh-home/db-schema');
    const existing = await this.db
      .select()
      .from(deviceCommands)
      .where(
        and(
          eq(deviceCommands.deviceId, cmd.deviceId),
          eq(deviceCommands.idempotencyKey, cmd.idempotencyKey)
        )
      )
      .limit(1);

    if (existing.length > 0) {
      return { record: existing[0], isIdempotentReplay: true };
    }

    const newRecord = {
      id: cmd.commandId,
      deviceId: cmd.deviceId,
      channelIndex: cmd.channelIndex,
      action: cmd.action,
      params: cmd.params,
      idempotencyKey: cmd.idempotencyKey,
      source: cmd.source,
      status: 'CREATED',
      failureReason: null,
      createdAt: new Date(),
      expiresAt: new Date(cmd.expiresAt),
      completedAt: null
    };

    await this.db.insert(deviceCommands).values(newRecord);
    return { record: newRecord, isIdempotentReplay: false };
  }

  public async updateCommandStatus(commandId: string, status: string, failureReason?: string | null): Promise<void> {
    if (!this.db || !this.db.update) {
      const record = this.commandsStore.get(commandId);
      if (record) {
        record.status = status;
        record.failureReason = failureReason || null;
        if (['APPLIED', 'FAILED', 'EXPIRED', 'OVERRIDDEN'].includes(status)) {
          record.completedAt = new Date().toISOString();
        }
      }
      return;
    }

    const { deviceCommands, eq } = require('@eh-home/db-schema');
    await this.db
      .update(deviceCommands)
      .set({
        status,
        failureReason: failureReason || null,
        completedAt: ['APPLIED', 'FAILED', 'EXPIRED', 'OVERRIDDEN'].includes(status) ? new Date() : null
      })
      .where(eq(deviceCommands.id, commandId));
  }

  public async getCommand(commandId: string): Promise<any | null> {
    if (!this.db || !this.db.select) {
      return this.commandsStore.get(commandId) || null;
    }

    const { deviceCommands, eq } = require('@eh-home/db-schema');
    const rows = await this.db.select().from(deviceCommands).where(eq(deviceCommands.id, commandId)).limit(1);
    return rows.length > 0 ? rows[0] : null;
  }

  public async getDeviceState(deviceId: string): Promise<any | null> {
    if (!this.db || !this.db.select) {
      const state = this.deviceStateStore.get(deviceId) || {
        deviceId,
        connectionState: 'OFFLINE',
        lastSeenAt: null,
        channels: []
      };

      // Gather channel states
      const channels: any[] = [];
      this.channelStateStore.forEach((ch, key) => {
        if (key.startsWith(`${deviceId}:`)) {
          channels.push(ch);
        }
      });
      state.channels = channels.sort((a, b) => a.channelIndex - b.channelIndex);
      return state;
    }

    const { deviceState, channelState, eq } = require('@eh-home/db-schema');
    const stateRows = await this.db.select().from(deviceState).where(eq(deviceState.deviceId, deviceId)).limit(1);
    const channelRows = await this.db.select().from(channelState).where(eq(channelState.deviceId, deviceId));

    if (stateRows.length === 0 && channelRows.length === 0) {
      return {
        deviceId,
        connectionState: 'OFFLINE',
        lastSeenAt: null,
        channels: []
      };
    }

    const baseState = stateRows.length > 0 ? stateRows[0] : { connectionState: 'OFFLINE', lastSeenAt: null };
    return {
      deviceId,
      connectionState: baseState.connectionState,
      lastSeenAt: baseState.lastSeenAt,
      lastCommandId: baseState.lastCommandId,
      lastEventId: baseState.lastEventId,
      channels: channelRows.map((c: any) => ({
        channelIndex: c.channelIndex,
        desiredState: c.desiredState,
        reportedState: c.reportedState,
        confidence: c.confidence
      }))
    };
  }

  public async updateChannelState(
    deviceId: string,
    channelIndex: number,
    state: { reportedState?: any; desiredState?: any; confidence?: string }
  ): Promise<void> {
    const key = `${deviceId}:${channelIndex}`;
    if (!this.db || !this.db.insert) {
      const existing = this.channelStateStore.get(key) || {
        deviceId,
        channelIndex,
        reportedState: {},
        desiredState: {},
        confidence: 'UNKNOWN'
      };
      if (state.reportedState !== undefined) existing.reportedState = state.reportedState;
      if (state.desiredState !== undefined) existing.desiredState = state.desiredState;
      if (state.confidence !== undefined) existing.confidence = state.confidence;
      this.channelStateStore.set(key, existing);
      return;
    }

    const { channelState, eq, and } = require('@eh-home/db-schema');
    const existing = await this.db
      .select()
      .from(channelState)
      .where(and(eq(channelState.deviceId, deviceId), eq(channelState.channelIndex, channelIndex)))
      .limit(1);

    if (existing.length > 0) {
      await this.db
        .update(channelState)
        .set({
          reportedState: state.reportedState !== undefined ? state.reportedState : existing[0].reportedState,
          desiredState: state.desiredState !== undefined ? state.desiredState : existing[0].desiredState,
          confidence: state.confidence || existing[0].confidence,
          updatedAt: new Date()
        })
        .where(and(eq(channelState.deviceId, deviceId), eq(channelState.channelIndex, channelIndex)));
    } else {
      await this.db.insert(channelState).values({
        id: randomUUID(),
        deviceId,
        channelIndex,
        reportedState: state.reportedState || {},
        desiredState: state.desiredState || {},
        confidence: state.confidence || 'CONFIRMED',
        updatedAt: new Date()
      });
    }
  }

  public async updateConnectionState(
    deviceId: string,
    connectionState: 'ONLINE' | 'OFFLINE',
    source = 'MQTT_LWT'
  ): Promise<void> {
    const now = new Date().toISOString();
    if (!this.db || !this.db.insert) {
      const state = this.deviceStateStore.get(deviceId) || { deviceId };
      state.connectionState = connectionState;
      state.lastSeenAt = now;
      this.deviceStateStore.set(deviceId, state);

      this.availabilityHistoryStore.push({
        id: randomUUID(),
        deviceId,
        status: connectionState,
        source,
        recordedAt: now
      });
      return;
    }

    const { deviceState, deviceAvailabilityHistory, eq } = require('@eh-home/db-schema');
    const existing = await this.db.select().from(deviceState).where(eq(deviceState.deviceId, deviceId)).limit(1);

    if (existing.length > 0) {
      await this.db
        .update(deviceState)
        .set({
          connectionState,
          lastSeenAt: new Date(),
          updatedAt: new Date()
        })
        .where(eq(deviceState.deviceId, deviceId));
    } else {
      await this.db.insert(deviceState).values({
        deviceId,
        connectionState,
        lastSeenAt: new Date(),
        updatedAt: new Date()
      });
    }

    await this.db.insert(deviceAvailabilityHistory).values({
      id: randomUUID(),
      deviceId,
      status: connectionState,
      source,
      recordedAt: new Date()
    });
  }

  public async enqueueOutbox(event: { eventType: string; aggregateId: string; payload: any }): Promise<void> {
    if (!this.db || !this.db.insert) {
      this.outboxStore.push({
        id: randomUUID(),
        ...event,
        status: 'PENDING',
        createdAt: new Date().toISOString()
      });
      return;
    }

    const { outbox } = require('@eh-home/db-schema');
    await this.db.insert(outbox).values({
      id: randomUUID(),
      eventType: event.eventType,
      aggregateType: 'device',
      aggregateId: event.aggregateId,
      payload: event.payload,
      status: 'PENDING',
      createdAt: new Date()
    });
  }
}
