/**
 * System Module Service
 * Business logic layer for operational diagnostics and system status.
 */
import { SystemInfoResponse, EchoRequest, EchoResponse } from './system.schema';
export declare class SystemService {
    private readonly environment;
    constructor(environment: string);
    getSystemInfo(): SystemInfoResponse;
    echo(payload: EchoRequest): EchoResponse;
}
//# sourceMappingURL=system.service.d.ts.map