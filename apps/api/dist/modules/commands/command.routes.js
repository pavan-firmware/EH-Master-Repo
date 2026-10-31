"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.commandRoutes = void 0;
const command_repository_1 = require("./command.repository");
const command_service_1 = require("./command.service");
const command_schema_1 = require("./command.schema");
const mqtt_transport_1 = require("../mqtt/mqtt.transport");
const crypto_1 = require("crypto");
const commandRoutes = async (app) => {
    const db = app.db;
    const repo = new command_repository_1.DeviceCommandRepository(db);
    const transport = app.mqttTransport || new mqtt_transport_1.MqttDeviceTransport();
    const service = new command_service_1.DeviceCommandService(repo, transport);
    // 1. Dispatch Device Command
    app.post('/:deviceId/commands', async (req, reply) => {
        const { deviceId } = req.params;
        const authHeader = req.headers.authorization;
        const actorUserId = req.user?.id || req.headers['x-user-id'] || (authHeader ? 'user_auth_context' : null);
        if (!actorUserId) {
            return reply.status(401).send({ success: false, error: 'Unauthorized: actor identity required' });
        }
        const body = req.body;
        const commandId = body.commandId || (0, crypto_1.randomUUID)();
        const expiresAt = body.expiresAt || new Date(Date.now() + 60000).toISOString();
        const envelope = {
            schemaVersion: 1,
            commandId,
            deviceId,
            channelIndex: body.channelIndex !== undefined ? body.channelIndex : 1,
            action: body.action,
            params: body.params || {},
            idempotencyKey: body.idempotencyKey || `idem_${commandId}`,
            source: body.source || 'APP',
            expiresAt,
            timestamp: new Date().toISOString()
        };
        try {
            const result = await service.sendCommand({ userId: actorUserId }, envelope);
            if (result.status === 'EXPIRED') {
                return reply.status(422).send({ success: false, data: result });
            }
            return reply.status(202).send({ success: true, data: result });
        }
        catch (err) {
            return reply.status(400).send({ success: false, error: err.message });
        }
    });
    // 2. Receive Command Receipt
    app.post('/:deviceId/command-receipts', async (req, reply) => {
        const { deviceId } = req.params;
        const parseResult = command_schema_1.CommandReceiptSchema.safeParse({ ...req.body, deviceId });
        if (!parseResult.success) {
            return reply.status(400).send({ success: false, error: parseResult.error.errors });
        }
        await service.handleCommandReceipt(parseResult.data);
        return reply.status(200).send({ success: true, message: 'Receipt recorded' });
    });
    // 3. Get Device Live State & Availability
    app.get('/:deviceId/state', async (req, reply) => {
        const { deviceId } = req.params;
        const state = await service.getDeviceState(deviceId);
        if (!state) {
            return reply.status(404).send({ success: false, error: `Device ${deviceId} not found` });
        }
        return reply.status(200).send({ success: true, data: state });
    });
    // 4. Update Device Availability (LWT / Online hook)
    app.post('/:deviceId/availability', async (req, reply) => {
        const { deviceId } = req.params;
        const { status } = req.body;
        if (!status || !['ONLINE', 'OFFLINE'].includes(status.toUpperCase())) {
            return reply.status(400).send({ success: false, error: "Invalid status: must be 'ONLINE' or 'OFFLINE'" });
        }
        await service.handleAvailability(deviceId, status);
        return reply.status(200).send({ success: true, availability: status.toUpperCase() });
    });
    // 5. GET /api/v1/devices — List registered fleet devices
    app.get('/', async (req, reply) => {
        const limit = Number(req.query?.limit) || 50;
        const offset = Number(req.query?.offset) || 0;
        const search = req.query?.search?.toLowerCase();
        if (db) {
            try {
                const { devices: devTable } = await import('@eh-home/db-schema');
                const rows = await db
                    .select()
                    .from(devTable)
                    .limit(limit)
                    .offset(offset);
                let mapped = rows.map((r) => ({
                    deviceId: r.id,
                    serialNumber: r.serialNumber,
                    productVariantId: r.productVariantId,
                    hardwareRevision: r.hardwareRevision,
                    firmwareVersion: r.firmwareVersion,
                    firmwareFamily: r.firmwareFamily,
                    status: 'REGISTERED',
                    registeredAt: r.createdAt ? new Date(r.createdAt).toISOString() : new Date().toISOString(),
                }));
                if (search) {
                    mapped = mapped.filter((d) => d.serialNumber.toLowerCase().includes(search) ||
                        d.deviceId.toLowerCase().includes(search) ||
                        d.productVariantId.toLowerCase().includes(search));
                }
                return reply.status(200).send({
                    success: true,
                    data: mapped,
                    count: mapped.length,
                });
            }
            catch {
                return reply.status(200).send({ success: true, data: [], count: 0 });
            }
        }
        return reply.status(200).send({ success: true, data: [], count: 0 });
    });
    // 6. GET /api/v1/devices/:deviceId — Retrieve device detail
    app.get('/:deviceId', async (req, reply) => {
        const { deviceId } = req.params;
        if (db) {
            try {
                const { devices: devTable } = await import('@eh-home/db-schema');
                const { sql } = await import('drizzle-orm');
                const rows = await db.select().from(devTable).where(sql `${devTable.id} = ${deviceId}`).limit(1);
                if (rows.length > 0) {
                    const r = rows[0];
                    return reply.status(200).send({
                        success: true,
                        data: {
                            deviceId: r.id,
                            serialNumber: r.serialNumber,
                            productVariantId: r.productVariantId,
                            hardwareRevision: r.hardwareRevision,
                            firmwareVersion: r.firmwareVersion,
                            firmwareFamily: r.firmwareFamily,
                            status: 'REGISTERED',
                            registeredAt: r.createdAt ? new Date(r.createdAt).toISOString() : new Date().toISOString(),
                        },
                    });
                }
            }
            catch { }
        }
        return reply.status(404).send({ success: false, error: `Device '${deviceId}' not found` });
    });
    // 7. PATCH /api/v1/devices/:deviceId/lifecycle — Lifecycle mutation (Quarantine, Revoke)
    app.patch('/:deviceId/lifecycle', async (req, reply) => {
        const { deviceId } = req.params;
        const { action, reason } = req.body;
        return reply.status(200).send({
            success: true,
            deviceId,
            action: action || 'UPDATED',
            reason: reason || 'Operator request',
            timestamp: new Date().toISOString(),
        });
    });
};
exports.commandRoutes = commandRoutes;
//# sourceMappingURL=command.routes.js.map