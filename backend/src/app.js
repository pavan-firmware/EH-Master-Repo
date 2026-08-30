'use strict';

/**
 * EH Home — Production Backend Application Factory (Phase 7A)
 *
 * Bootstraps services, repositories, authentication, membership authorization,
 * and API routers into a unified, framework-agnostic Node.js application handler.
 */

const url = require('url');
const { DatabaseClient } = require('./shared/db-client');
const {
  UserRepository,
  HomeRepository,
  RoomRepository,
  ProductRepository,
  CapabilityRepository,
  DeviceRepository,
  DeviceStateRepository,
  CommandRepository,
  EventRepository,
  AuditRepository,
  OutboxRepository,
  ProvisioningSessionRepository,
  RefreshTokenRepository,
  SceneRepository,
  AutomationRepository,
  ScheduleRepository,
  AutomationExecutionLogRepository,
  DeviceActivityLogRepository,
  DeviceHealthRepository
} = require('./repositories');

const { AuthService } = require('./services/auth.service');
const { HomeService } = require('./services/home.service');
const { FloorService } = require('./services/floor.service');
const { RoomService } = require('./services/room.service');
const { DeviceService } = require('./services/device.service');
const { ProvisioningService } = require('./services/provisioning.service');
const { DeviceClaimService } = require('./services/device-claim.service');
const { ProductCatalogService } = require('./services/product-catalog.service');
const { DeviceCommandService } = require('./services/device-command.service');
const { DeviceEventTelemetryIngestionService } = require('./services/device-event-telemetry-ingestion.service');
const { OtaService } = require('./services/ota.service');
const { SceneService } = require('./services/scene.service');
const { AutomationService } = require('./services/automation.service');
const { ScheduleService } = require('./services/schedule.service');
const { DeviceManagementService } = require('./services/device-management.service');

const { AuthApiRouter } = require('./api/auth.router');
const { HomeDeviceApiRouter } = require('./api/home-device.router');
const { ProvisioningClaimApiRouter } = require('./api/provisioning-claim.router');
const { ApiRouter: ProductCatalogApiRouter } = require('./api/product-catalog.router');
const { buildRouteHandlers: buildCommandRouteHandlers } = require('./api/device-command.router');
const { OtaApiRouter } = require('./api/ota.router');
const { AutomationSceneApiRouter } = require('./api/automation-scene.router');
const { DeviceManagementApiRouter } = require('./api/device-management.router');
const { AutomationSchedulerWorker } = require('./workers/automation-scheduler-worker');

const { requireAuthentication } = require('./shared/auth-middleware');
const { HomeAuthorizationService } = require('./shared/home-authorization');

/**
 * Endpoint Security Classification Registry
 */
const PUBLIC_ROUTES = [
  'GET /health',
  'GET /api/v1/health',
  'GET /api/v1/health/liveness',
  'GET /api/v1/health/readiness',
  'GET /api/v1/health/diagnostics',
  'POST /api/v1/auth/register',
  'POST /api/v1/auth/login',
  'POST /api/v1/auth/refresh',
  'GET /api/v1/products',
  'GET /api/v1/capabilities',
  'GET /api/v1/ota/check'
];

function isPublicRoute(method, pathname) {
  const exactKey = `${method} ${pathname}`;
  if (PUBLIC_ROUTES.includes(exactKey)) return true;

  if (method === 'GET' && (
    pathname.startsWith('/api/v1/product-variants/') ||
    pathname.startsWith('/api/v1/capabilities/') ||
    pathname.startsWith('/api/v1/ota/manifests/')
  )) {
    return true;
  }
  return false;
}

/**
 * Helper to parse JSON body from incoming HTTP stream
 */
function parseJsonBody(req) {
  return new Promise((resolve, reject) => {
    if (req.body && typeof req.body === 'object') {
      return resolve(req.body);
    }
    let data = '';
    req.on('data', chunk => {
      data += chunk;
      if (data.length > 1e6) { // 1MB payload limit safeguard
        req.destroy();
        reject(new Error('Payload too large'));
      }
    });
    req.on('end', () => {
      if (!data || data.trim() === '') return resolve({});
      try {
        resolve(JSON.parse(data));
      } catch (err) {
        const syntaxErr = new Error('Invalid JSON payload');
        syntaxErr.statusCode = 400;
        reject(syntaxErr);
      }
    });
    req.on('error', err => reject(err));
  });
}

/**
 * Helper to send standardized JSON response
 */
function sendJsonResponse(res, statusCode, data) {
  if (res.headersSent) return;
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'X-Content-Type-Options': 'nosniff'
  });
  res.end(JSON.stringify(data));
}

/**
 * Create and configure application instance
 */
function createApp(options = {}) {
  const db = options.db || new DatabaseClient();

  // 1. Repositories
  const userRepo = new UserRepository(db);
  const homeRepo = new HomeRepository(db);
  const roomRepo = new RoomRepository(db);
  const productRepo = new ProductRepository(db);
  const capRepo = new CapabilityRepository(db);
  const deviceRepo = new DeviceRepository(db);
  const deviceStateRepo = new DeviceStateRepository(db);
  const commandRepo = new CommandRepository(db);
  const eventRepo = new EventRepository(db);
  const auditRepo = new AuditRepository(db);
  const outboxRepo = new OutboxRepository(db);
  const provisioningRepo = new ProvisioningSessionRepository(db);
  const refreshTokenRepo = new RefreshTokenRepository(db);
  const sceneRepo = new SceneRepository(db);
  const automationRepo = new AutomationRepository(db);
  const scheduleRepo = new ScheduleRepository(db);
  const logRepo = new AutomationExecutionLogRepository(db);
  const activityLogRepo = new DeviceActivityLogRepository(db);
  const healthRepo = new DeviceHealthRepository(db);

  // 2. Services
  const authService = options.authService || new AuthService({
    userRepo,
    refreshTokenRepo,
    privateKey: options.privateKey,
    publicKey: options.publicKey
  });
  const homeService = new HomeService({ homeRepo, userRepo, auditRepo });
  const floorService = new FloorService({ roomRepo, homeRepo, auditRepo });
  const roomService = new RoomService({ roomRepo, homeRepo, deviceRepo, auditRepo });
  const deviceService = new DeviceService({ deviceRepo, deviceStateRepo, homeRepo, roomRepo, auditRepo });
  const provisioningService = new ProvisioningService({ provisioningRepo, deviceRepo, auditRepo });
  const deviceClaimService = new DeviceClaimService({ deviceRepo, homeRepo, provisioningRepo, auditRepo });
  const catalogService = new ProductCatalogService();
  const otaService = new OtaService();

  const mqttTransport = options.mqttTransport || null;
  const eventBus = options.eventBus || null;
  const ingestionService = new DeviceEventTelemetryIngestionService({
    deviceStateRepo, eventRepo, commandRepo, outboxRepo, auditRepo
  });
  const commandService = new DeviceCommandService({
    commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo,
    mqttTransport
  });

  const authMiddleware = requireAuthentication(authService);
  const homeAuthService = new HomeAuthorizationService({ homeRepo, deviceRepo, roomRepo });

  const sceneService = options.sceneService || new SceneService({
    sceneRepo, homeAuthService, deviceCommandService: commandService, eventBus, logRepo
  });
  const automationService = options.automationService || new AutomationService({
    automationRepo, homeAuthService, deviceCommandService: commandService, deviceStateRepo, eventBus, logRepo
  });
  const scheduleService = options.scheduleService || new ScheduleService({
    scheduleRepo, homeAuthService, automationService, sceneService
  });
  const deviceManagementService = options.deviceManagementService || new DeviceManagementService({
    deviceRepo,
    deviceStateRepo,
    homeRepo,
    roomRepo,
    auditRepo,
    activityLogRepo,
    healthRepo,
    commandRepo,
    homeAuthService,
    realtimeEventBus: eventBus,
    productCatalogService: catalogService,
    otaService
  });

  const schedulerWorker = options.schedulerWorker || new AutomationSchedulerWorker({
    scheduleRepo, scheduleService
  });
  if (options.startWorkers) {
    schedulerWorker.start();
  }

  // 3. API Routers
  const authRouter = new AuthApiRouter({ authService, rateLimiter: options.rateLimiter });
  const homeDeviceRouter = new HomeDeviceApiRouter({ homeService, floorService, roomService, deviceService });
  const provisioningRouter = new ProvisioningClaimApiRouter({ provisioningService, deviceClaimService });
  const catalogRouter = new ProductCatalogApiRouter();
  const otaRouter = new OtaApiRouter({ otaService });
  const automationSceneRouter = new AutomationSceneApiRouter({ sceneService, automationService, scheduleService });
  const deviceManagementRouter = new DeviceManagementApiRouter({
    deviceManagementService,
    db,
    mqttTransport,
    workers: { scheduler: schedulerWorker }
  });
  const commandHandlers = buildCommandRouteHandlers({ commandService, deviceStateRepo, commandRepo });

  /**
   * Main Request Handler
   */
  async function handleRequest(req, res) {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;
    const method = req.method.toUpperCase();
    const query = parsedUrl.query || {};

    // 1. Health check endpoint
    if (method === 'GET' && (pathname === '/health' || pathname === '/api/v1/health')) {
      return sendJsonResponse(res, 200, {
        success: true,
        data: { status: 'OK', service: 'eh-home-backend', version: '1.0.0', timestamp: new Date().toISOString() }
      });
    }

    // 2. Parse JSON body safely
    let body = {};
    try {
      if (['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)) {
        body = await parseJsonBody(req);
      }
    } catch (err) {
      return sendJsonResponse(res, err.statusCode || 400, {
        success: false,
        error: { code: 'INVALID_JSON', message: err.message },
        timestamp: new Date().toISOString()
      });
    }

    // 3. Route to Auth Router if auth path
    if (pathname.startsWith('/api/v1/auth/')) {
      const result = await authRouter.handle(method, pathname, body, req.headers, req.socket.remoteAddress);
      return sendJsonResponse(res, result.status, result.body);
    }

    // 4. Check Public Route vs Authenticated Route
    if (!isPublicRoute(method, pathname)) {
      const authResult = authMiddleware(req, res);
      if (authResult && authResult.status === 401) {
        return sendJsonResponse(res, 401, authResult.body);
      }
    }

    // 5. Membership Authorization for Home/Device/Command routes
    if (req.user) {
      const userId = req.user.id;
      let homeIdParam = null;
      let deviceIdParam = null;

      // Extract homeId from url if present (/api/v1/homes/:homeId/...)
      const homeMatch = pathname.match(/^\/api\/v1\/homes\/([^\/]+)/);
      if (homeMatch && homeMatch[1] && homeMatch[1] !== 'register') {
        homeIdParam = homeMatch[1];
      }

      // Extract deviceId from url if present (/api/v1/devices/:deviceId/...)
      const deviceMatch = pathname.match(/^\/api\/v1\/devices\/([^\/]+)/);
      if (deviceMatch && deviceMatch[1] && deviceMatch[1] !== 'register' && deviceMatch[1] !== 'confirm-provisioning') {
        deviceIdParam = deviceMatch[1];
      }

      if (pathname === '/api/v1/commands/send' && body.deviceId) {
        deviceIdParam = body.deviceId;
      }

      // If accessing a specific home or device, enforce membership authorization
      if (homeIdParam || deviceIdParam) {
        const authCheck = await homeAuthService.authorizeRequest({
          userId,
          homeId: homeIdParam,
          deviceId: deviceIdParam
        });

        if (!authCheck.isAuthorized) {
          return sendJsonResponse(res, authCheck.statusCode || 403, {
            success: false,
            error: { code: 'FORBIDDEN', message: authCheck.message },
            timestamp: new Date().toISOString()
          });
        }

        // Enrich actorContext for downstream handlers (e.g. DeviceCommandService)
        req.actorContext = {
          userId,
          homeId: authCheck.homeId,
          role: authCheck.role
        };
      }
    }

    // 6. Route to Command Handlers
    if (pathname === '/api/v1/commands/send' && method === 'POST') {
      req.body = body;
      req.params = {};
      const fakeRes = createResponseWrapper(res);
      await commandHandlers.sendCommand(req, fakeRes);
      return;
    }

    if (pathname.startsWith('/api/v1/commands/') && method === 'GET') {
      const commandId = pathname.replace('/api/v1/commands/', '');
      req.params = { commandId };
      const fakeRes = createResponseWrapper(res);
      await commandHandlers.getCommand(req, fakeRes);
      return;
    }

    if (pathname.startsWith('/api/v1/devices/') && pathname.endsWith('/state') && method === 'GET') {
      const deviceId = pathname.replace('/api/v1/devices/', '').replace('/state', '');
      req.params = { deviceId };
      const fakeRes = createResponseWrapper(res);
      await commandHandlers.getDeviceState(req, fakeRes);
      return;
    }

    // 7. Route to Catalog Router
    if (pathname.startsWith('/api/v1/products') || pathname.startsWith('/api/v1/product-variants') || pathname.startsWith('/api/v1/capabilities')) {
      const result = await catalogRouter.handle(method, pathname, query);
      return sendJsonResponse(res, result.status, result.body);
    }

    // 8. Route to Provisioning & Claim Router
    if (pathname.startsWith('/api/v1/provisioning/') || (pathname.startsWith('/api/v1/devices/') && (pathname.endsWith('/claim') || pathname.endsWith('/unclaim') || pathname.endsWith('/reset') || pathname.endsWith('/confirm-provisioning')))) {
      const result = await provisioningRouter.handle(method, pathname, body, req.headers, req.socket.remoteAddress);
      return sendJsonResponse(res, result.status, result.body);
    }

    // 8.5. Route to OTA Router
    if (pathname.startsWith('/api/v1/ota')) {
      const result = await otaRouter.handle(method, pathname, body, query);
      return sendJsonResponse(res, result.status, result.body);
    }

    // 8.6. Route to Automation, Scene, and Schedule Router
    if (
      pathname.includes('/scenes') ||
      pathname.includes('/automations') ||
      pathname.includes('/schedules') ||
      pathname.includes('/automation-history')
    ) {
      if (req.user) {
        query.userId = req.user.id;
      }
      const result = await automationSceneRouter.handle(method, pathname, body, req.headers, query);
      if (result) {
        return sendJsonResponse(res, result.status, result.body);
      }
    }

    // 8.7. Route to Device Management & Health Observability Router
    if (
      pathname.startsWith('/api/v1/health') ||
      pathname.includes('/details') ||
      pathname.includes('/diagnostics') ||
      pathname.includes('/activity') ||
      pathname.includes('/rename') ||
      pathname.includes('/move') ||
      (pathname.startsWith('/api/v1/homes/') && pathname.includes('/devices/') && method === 'DELETE')
    ) {
      if (req.user) {
        query.userId = req.user.id;
      }
      const devMgmtResult = await deviceManagementRouter.handle(method, pathname, body, req.headers, query);
      if (devMgmtResult) {
        return sendJsonResponse(res, devMgmtResult.status, devMgmtResult.body);
      }
    }

    // 9. Route to Home & Device Domain Router
    if (pathname.startsWith('/api/v1/homes') || pathname.startsWith('/api/v1/devices')) {
      // In authenticated GET /api/v1/homes, filter by user membership
      if (method === 'GET' && pathname === '/api/v1/homes' && req.user) {
        query.userId = req.user.id;
      }
      const result = await homeDeviceRouter.handle(method, pathname, body, query);
      return sendJsonResponse(res, result.status, result.body);
    }

    // 10. Fallthrough 404
    return sendJsonResponse(res, 404, {
      success: false,
      error: { code: 'NOT_FOUND', message: `Route ${method} ${pathname} not found` },
      timestamp: new Date().toISOString()
    });
  }

  return {
    handleRequest,
    services: {
      db,
      authService,
      homeService,
      floorService,
      roomService,
      deviceService,
      provisioningService,
      deviceClaimService,
      catalogService,
      commandService,
      ingestionService,
      otaService,
      sceneService,
      automationService,
      scheduleService,
      schedulerWorker
    },
    repositories: {
      userRepo, homeRepo, roomRepo, productRepo, capRepo, deviceRepo,
      deviceStateRepo, commandRepo, eventRepo, auditRepo, outboxRepo,
      provisioningRepo, refreshTokenRepo, sceneRepo, automationRepo,
      scheduleRepo, logRepo
    }
  };
}

/**
 * Helper response wrapper to interface with Express-style req/res handlers
 */
function createResponseWrapper(res) {
  let statusCode = 200;
  return {
    status(code) {
      statusCode = code;
      return this;
    },
    json(body) {
      sendJsonResponse(res, statusCode, body);
    }
  };
}

module.exports = { createApp, isPublicRoute };
