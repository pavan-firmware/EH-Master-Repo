import { CommandReceipt } from '@eh-home/contracts';
import { IDeviceCommandRepository } from './command.repository';
import { IDeviceTransport } from '../mqtt/mqtt.types';
export declare const STALE_HEARTBEAT_THRESHOLD_MS = 90000;
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
export declare class DeviceCommandService {
    private repo;
    private transport?;
    constructor(repo: IDeviceCommandRepository, transport?: IDeviceTransport);
    sendCommand(actor: ActorContext, rawCommand: unknown): Promise<SendCommandResult>;
    handleCommandReceipt(receipt: CommandReceipt): Promise<void>;
    handleAvailability(deviceId: string, availability: string): Promise<void>;
    deriveConnectionState(lastSeenAt: string | null | undefined, rawStatus: string): 'ONLINE' | 'STALE' | 'OFFLINE';
    getDeviceState(deviceId: string): Promise<any>;
}
//# sourceMappingURL=command.service.d.ts.map