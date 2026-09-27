/**
 * System Module Schemas
 * Request & response validation contracts for the system module.
 */

import { z } from 'zod';

export const SystemInfoResponseSchema = z.object({
  service: z.literal('eh-home-api'),
  version: z.string(),
  nodeVersion: z.string(),
  environment: z.string(),
  uptimeSeconds: z.number().int().nonnegative(),
  timestamp: z.string().datetime(),
});

export type SystemInfoResponse = z.infer<typeof SystemInfoResponseSchema>;

export const EchoRequestSchema = z.object({
  message: z.string().min(1, { message: 'Message cannot be empty' }).max(256),
  metadata: z.record(z.unknown()).optional(),
});

export type EchoRequest = z.infer<typeof EchoRequestSchema>;

export const EchoResponseSchema = z.object({
  echo: z.string(),
  metadata: z.record(z.unknown()).optional(),
  receivedAt: z.string().datetime(),
});

export type EchoResponse = z.infer<typeof EchoResponseSchema>;
