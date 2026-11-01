import { FastifySchema } from 'fastify';

export const registerInventorySchema: FastifySchema = {
  body: {
    type: 'object',
    required: ['traceabilityRecord', 'stationId'],
    properties: {
      traceabilityRecord: { type: 'object' },
      stationId: { type: 'string' },
      qrToken: { type: 'string' },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        inventoryItem: { type: 'object', additionalProperties: true },
        errorCode: { type: 'string' },
        errorMessage: { type: 'string' },
        registeredAt: { type: 'string' },
      },
    },
  },
};

export const getDeviceSchema: FastifySchema = {
  params: {
    type: 'object',
    required: ['identifier'],
    properties: {
      identifier: { type: 'string' },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        device: { type: 'object', additionalProperties: true },
      },
    },
    404: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        error: { type: 'string' },
        message: { type: 'string' },
      },
    },
  },
};

export const dualScanSchema: FastifySchema = {
  body: {
    type: 'object',
    required: ['stationId', 'deviceSerial', 'boxTokenOrUri'],
    properties: {
      schemaVersion: { type: 'number' },
      stationId: { type: 'string' },
      operatorUserId: { type: 'string' },
      deviceSerial: { type: 'string' },
      boxTokenOrUri: { type: 'string' },
      cartonId: { type: 'string' },
      requestedAt: { type: 'string' },
    },
  },
  response: {
    200: {
      type: 'object',
      additionalProperties: true,
    },
  },
};

export const createCartonSchema: FastifySchema = {
  body: {
    type: 'object',
    required: ['cartonCode', 'productVariantId', 'hardwareRevision'],
    properties: {
      cartonCode: { type: 'string' },
      productVariantId: { type: 'string' },
      hardwareRevision: { type: 'string' },
      targetCapacity: { type: 'number' },
      operatorUserId: { type: 'string' },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        carton: { type: 'object', additionalProperties: true },
      },
    },
  },
};

export const getCartonSchema: FastifySchema = {
  params: {
    type: 'object',
    required: ['cartonId'],
    properties: {
      cartonId: { type: 'string' },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        carton: { type: 'object', additionalProperties: true },
      },
    },
    404: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        error: { type: 'string' },
        message: { type: 'string' },
      },
    },
  },
};

export const completePackingSchema: FastifySchema = {
  body: {
    type: 'object',
    required: ['deviceId', 'serialNumber', 'cartonId', 'verificationId', 'stationId'],
    properties: {
      deviceId: { type: 'string' },
      serialNumber: { type: 'string' },
      cartonId: { type: 'string' },
      verificationId: { type: 'string' },
      stationId: { type: 'string' },
      operatorUserId: { type: 'string' },
      notes: { type: 'string' },
    },
  },
  response: {
    200: {
      type: 'object',
      additionalProperties: true,
    },
  },
};

export const getPackingHistorySchema: FastifySchema = {
  querystring: {
    type: 'object',
    properties: {
      limit: { type: 'number' },
      offset: { type: 'number' },
    },
  },
  response: {
    200: {
      type: 'object',
      properties: {
        success: { type: 'boolean' },
        records: { type: 'array', items: { type: 'object', additionalProperties: true } },
      },
    },
  },
};
