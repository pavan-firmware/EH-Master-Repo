/**
 * EH Home API Centralized Error Handler
 * Enforces structured, safe error envelopes conforming to @eh-home/contracts.
 */

import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import fp from 'fastify-plugin';
import { ZodError } from 'zod';

export interface StructuredErrorResponse {
  schemaVersion: number;
  success: false;
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
  meta: {
    requestId: string;
    timestamp: string;
  };
}

const errorHandlerPlugin: FastifyPluginAsync = async (app: FastifyInstance) => {
  // Handle 404 Not Found
  app.setNotFoundHandler((req, reply) => {
    const errorBody: StructuredErrorResponse = {
      schemaVersion: 1,
      success: false,
      error: {
        code: 'ROUTE_NOT_FOUND',
        message: `Route ${req.method} ${req.url} does not exist`,
      },
      meta: {
        requestId: req.correlationId || 'unknown',
        timestamp: new Date().toISOString(),
      },
    };
    reply.status(404).send(errorBody);
  });

  // Handle All Other Errors
  app.setErrorHandler((rawError: any, req, reply) => {
    const error = rawError || {};
    const requestId = req.correlationId || 'unknown';
    const timestamp = new Date().toISOString();

    // 1. Zod Validation Error
    if (error instanceof ZodError) {
      const details: Record<string, unknown> = {};
      error.issues.forEach((issue) => {
        details[issue.path.join('.')] = issue.message;
      });

      const response: StructuredErrorResponse = {
        schemaVersion: 1,
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'The request payload failed validation constraints',
          details,
        },
        meta: { requestId, timestamp },
      };
      return reply.status(400).send(response);
    }

    // 2. Fastify Validation Error (e.g., Schema compiler / payload limit)
    if (error.validation) {
      const response: StructuredErrorResponse = {
        schemaVersion: 1,
        success: false,
        error: {
          code: 'BAD_REQUEST',
          message: error.message,
        },
        meta: { requestId, timestamp },
      };
      return reply.status(400).send(response);
    }

    // 3. Explicit HTTP Errors with statusCode
    const statusCode = error.statusCode && error.statusCode >= 400 && error.statusCode < 500
      ? error.statusCode
      : 500;

    if (statusCode < 500) {
      const response: StructuredErrorResponse = {
        schemaVersion: 1,
        success: false,
        error: {
          code: error.errorCode || error.code || 'CLIENT_ERROR',
          message: error.message,
        },
        meta: { requestId, timestamp },
      };
      return reply.status(statusCode).send(response);
    }

    // 4. Server Errors (500) - Redact internals to prevent information leakage
    req.log.error(
      {
        err: {
          message: error.message,
          stack: error.stack,
          code: error.code,
        },
        requestId,
      },
      'Unhandled internal server error'
    );

    const safeResponse: StructuredErrorResponse = {
      schemaVersion: 1,
      success: false,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'An unexpected internal server error occurred. Please quote the requestId to support.',
      },
      meta: { requestId, timestamp },
    };

    return reply.status(500).send(safeResponse);
  });
};

export const errorHandler = fp(errorHandlerPlugin, {
  name: 'errorHandler',
  fastify: '5.x',
});
