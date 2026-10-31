"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DeviceCommandService = exports.STALE_HEARTBEAT_THRESHOLD_MS = void 0;
const contracts_1 = require("@eh-home/contracts");
exports.STALE_HEARTBEAT_THRESHOLD_MS = 90_000; // 90 seconds
class DeviceCommandService {
    repo;
    transport;
    constructor(repo, transport) {
        this.repo = repo;
        this.transport = transport;
    }
    async sendCommand(actor, rawCommand) {
        if (!actor || !actor.userId) {
            throw new Error('Unauthorized: actor context must provide authenticated userId');
        }
        const parseResult = contracts_1.CommandEnvelopeSchema.safeParse(rawCommand);
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
            }
            catch (err) {
                console.warn(`[DeviceCommandService] MQTT dispatch failed for command ${cmd.commandId}: ${err.message}`);
            }
        }
        return {
            commandId: cmd.commandId,
            status: 'CREATED',
            isIdempotentReplay: false
        };
    }
    async handleCommandReceipt(receipt) {
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
    async handleAvailability(deviceId, availability) {
        const cleanStatus = availability.toUpperCase().includes('ONLINE') ? 'ONLINE' : 'OFFLINE';
        await this.repo.updateConnectionState(deviceId, cleanStatus);
    }
    deriveConnectionState(lastSeenAt, rawStatus) {
        if (rawStatus === 'OFFLINE')
            return 'OFFLINE';
        if (!lastSeenAt)
            return 'OFFLINE';
        const lastSeenTime = new Date(lastSeenAt).getTime();
        if (Date.now() - lastSeenTime > exports.STALE_HEARTBEAT_THRESHOLD_MS) {
            return 'STALE';
        }
        return 'ONLINE';
    }
    async getDeviceState(deviceId) {
        const state = await this.repo.getDeviceState(deviceId);
        if (!state)
            return null;
        const derivedConnection = this.deriveConnectionState(state.lastSeenAt, state.connectionState);
        return {
            ...state,
            connectionState: derivedConnection,
            rawConnectionState: state.connectionState
        };
    }
}
exports.DeviceCommandService = DeviceCommandService;
//# sourceMappingURL=command.service.js.map