import { CommandEnvelope } from '@eh-home/contracts';
export interface IDeviceCommandRepository {
    recordCommand(cmd: CommandEnvelope): Promise<{
        record: any;
        isIdempotentReplay: boolean;
    }>;
    updateCommandStatus(commandId: string, status: string, failureReason?: string | null): Promise<void>;
    getCommand(commandId: string): Promise<any | null>;
    getDeviceState(deviceId: string): Promise<any | null>;
    updateChannelState(deviceId: string, channelIndex: number, state: {
        reportedState?: any;
        desiredState?: any;
        confidence?: string;
    }): Promise<void>;
    updateConnectionState(deviceId: string, connectionState: 'ONLINE' | 'OFFLINE', source?: string): Promise<void>;
    enqueueOutbox(event: {
        eventType: string;
        aggregateId: string;
        payload: any;
    }): Promise<void>;
}
export declare class DeviceCommandRepository implements IDeviceCommandRepository {
    private db;
    private commandsStore;
    private idempotencyIndex;
    private deviceStateStore;
    private channelStateStore;
    private availabilityHistoryStore;
    private outboxStore;
    constructor(db?: any);
    recordCommand(cmd: CommandEnvelope): Promise<{
        record: any;
        isIdempotentReplay: boolean;
    }>;
    updateCommandStatus(commandId: string, status: string, failureReason?: string | null): Promise<void>;
    getCommand(commandId: string): Promise<any | null>;
    getDeviceState(deviceId: string): Promise<any | null>;
    updateChannelState(deviceId: string, channelIndex: number, state: {
        reportedState?: any;
        desiredState?: any;
        confidence?: string;
    }): Promise<void>;
    updateConnectionState(deviceId: string, connectionState: 'ONLINE' | 'OFFLINE', source?: string): Promise<void>;
    enqueueOutbox(event: {
        eventType: string;
        aggregateId: string;
        payload: any;
    }): Promise<void>;
}
//# sourceMappingURL=command.repository.d.ts.map