import {
  CommandReceipt,
  CommandEnvelopeSchema
} from '@eh-home/contracts';
import { IDeviceCommandRepository } from './command.repository';
import { IDeviceTransport } from '../mqtt/mqtt.types';

export const STALE_HEARTBEAT_THRESHOLD_MS = 90_000; // 90 seconds

export interface ActorContext {
  userId: string;
  homeId?: string;
  role?: string;
}

export interface SendCommandResult {
  commandId: string;
  status: 'CREATED' | 'APPLIED' | 'FAILED' | 'EXPIRED' | 'OVERRIDDEN';
  isIdempotentReplay: boolean;
  message?: string;
}

export class DeviceCommandService {
  private repo: IDeviceCommandRepository;
  private transport?: IDeviceTransport;

  constructor(repo: IDeviceCommandRepository, transport?: IDeviceTransport) {
    this.repo = repo;
    this.transport = transport;
  }

  public async sendCommand(actor: ActorContext, rawCommand: unknown): Promise<SendCommandResult> {
    if (!actor || !actor.userId) {
      throw new Error('Unauthorized: actor context must provide authenticated userId');
    }

    const parseResult = CommandEnvelopeSchema.safeParse(rawCommand);
    if (!parseResult.success) {
      throw new Error(`Validation Error: ${parseResult.error.errors.map((e) => `${e.path.join('.')}: ${e.message}`).join(', ')}`);
    }

    const cmd = parseResult.data;

    // Expiry check
    if (cmd.expiresAt && new Date(cmd.expiresAt).getTime() <= Date.now()) {
      return {
        commandId: cmd.commandId,
        status: 'EXPIRED',
        isIdempotentReplay: false,
        message: `Command expired before dispatch: expiresAt ${cmd.expiresAt}`
      };
    }

    // Persist command & check idempotency
    const { record, isIdempotentReplay } = await this.repo.recordCommand(cmd);

    if (isIdempotentReplay) {
      return {
        commandId: record.id || cmd.commandId,
        status: record.status || 'CREATED',
        isIdempotentReplay: true,
        message: `Idempotency match for key ${cmd.idempotencyKey}`
      };
    }

    // Insert outbox event
    await this.repo.enqueueOutbox({
      eventType: 'DEVICE_COMMAND',
      aggregateId: cmd.deviceId,
      payload: {
        commandId: cmd.commandId,
        deviceId: cmd.deviceId,
        channelIndex: cmd.channelIndex,
        action: cmd.action,
        params: cmd.params,
        idempotencyKey: cmd.idempotencyKey,
        expiresAt: cmd.expiresAt,
        actorUserId: actor.userId
      }
    });

    // MQTT dispatch AFTER DB commit
    if (this.transport && this.transport.isReady) {
      try {
        await this.transport.sendCommand(cmd);
      } catch (err: any) {
        console.warn(`[DeviceCommandService] MQTT dispatch failed for command ${cmd.commandId}: ${err.message}`);
      }
    }

    return {
      commandId: cmd.commandId,
      status: 'CREATED',
      isIdempotentReplay: false
    };
  }

  public async handleCommandReceipt(receipt: CommandReceipt): Promise<void> {
    if (!receipt || !receipt.commandId || !receipt.status) {
      return;
    }

    await this.repo.updateCommandStatus(receipt.commandId, receipt.status, receipt.failureReason);

    // If applied, update reported state
    if (receipt.status === 'APPLIED') {
      await this.repo.updateChannelState(receipt.deviceId, receipt.channelIndex, {
        confidence: 'CONFIRMED'
      });
    }
  }

  public async handleAvailability(deviceId: string, availability: string): Promise<void> {
    const cleanStatus = availability.toUpperCase().includes('ONLINE') ? 'ONLINE' : 'OFFLINE';
    await this.repo.updateConnectionState(deviceId, cleanStatus);
  }

  public deriveConnectionState(lastSeenAt: string | null | undefined, rawStatus: string): 'ONLINE' | 'STALE' | 'OFFLINE' {
    if (rawStatus === 'OFFLINE') return 'OFFLINE';
    if (!lastSeenAt) return 'OFFLINE';

    const lastSeenTime = new Date(lastSeenAt).getTime();
    if (Date.now() - lastSeenTime > STALE_HEARTBEAT_THRESHOLD_MS) {
      return 'STALE';
    }
    return 'ONLINE';
  }

  public async getDeviceState(deviceId: string): Promise<any> {
    const state = await this.repo.getDeviceState(deviceId);
    if (!state) return null;

    const derivedConnection = this.deriveConnectionState(state.lastSeenAt, state.connectionState);
    return {
      ...state,
      connectionState: derivedConnection,
      rawConnectionState: state.connectionState
    };
  }
}
