/**
 * System Module Service
 * Business logic layer for operational diagnostics and system status.
 */

import { SystemInfoResponse, EchoRequest, EchoResponse } from './system.schema';

export class SystemService {
  constructor(private readonly environment: string) {}

  public getSystemInfo(): SystemInfoResponse {
    return {
      service: 'eh-home-api',
      version: '1.0.0',
      nodeVersion: process.version,
      environment: this.environment,
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: new Date().toISOString(),
    };
  }

  public echo(payload: EchoRequest): EchoResponse {
    return {
      echo: payload.message,
      metadata: payload.metadata,
      receivedAt: new Date().toISOString(),
    };
  }
}
