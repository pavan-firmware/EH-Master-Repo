import { z } from 'zod';
import {
  CommandEnvelopeSchema,
  CommandReceiptSchema,
  CommandActionSchema,
  DeviceAvailabilityStatusSchema
} from '@eh-home/contracts';

export { CommandEnvelopeSchema, CommandReceiptSchema, CommandActionSchema, DeviceAvailabilityStatusSchema };

export const SendCommandRequestSchema = z.object({
  commandId: z.string().uuid().optional(),
  channelIndex: z.number().int().min(1).max(16).default(1),
  action: CommandActionSchema,
  params: z.record(z.unknown()).default({}),
  idempotencyKey: z.string().min(1),
  source: z.string().default('APP'),
  expiresAt: z.string().datetime().optional()
});
export type SendCommandRequest = z.infer<typeof SendCommandRequestSchema>;

export const SendCommandResponseSchema = z.object({
  commandId: z.string().uuid(),
  status: z.enum(['CREATED', 'APPLIED', 'FAILED', 'EXPIRED', 'OVERRIDDEN']),
  isIdempotentReplay: z.boolean(),
  message: z.string().optional()
});
export type SendCommandResponse = z.infer<typeof SendCommandResponseSchema>;
