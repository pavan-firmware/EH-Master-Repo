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
  DeviceHealthRepository,
  NotificationRepository,
  InvitationRepository,
  SyncRepository,
  ExportRepository,
  FirmwareReleaseRepository,
  OtaOperationRepository,
  OtaRolloutRepository,
  DeviceMaintenanceRepository,
  DeviceTelemetryRepository,
  TelemetryAggregateRepository,
  EnergyThresholdRepository,
  EnergyEventRepository,
  EnergyAutomationExecutionRepository,
  EnergyOptimizationRepository,
  EnergyTariffRepository,
  TariffPeriodRepository,
  EnergyBudgetRepository,
  CostOptimizationRepository,
  EnergyForecastRepository,
  EnergyAnomalyRepository,
  EnergyBaselineRepository,
  ForecastAccuracyRepository,
  EnergyEfficiencyScoreRepository,
  PresenceSignalRepository,
  PresenceStateRepository,
  HomeContextRepository,
  ContextOverrideRepository,
  ContextTransitionRepository,
  IntelligenceDecisionRepository,
  IntelligenceRecommendationRepository,
  IntelligenceOutcomeRepository,
  ReliabilityIncidentRepository,
  ReliabilityDiagnosticRepository,
  ReliabilityRecoveryRepository,
  ReliabilityHealthSnapshotRepository,
  MaintenanceRecommendationRepository
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
const { EnergyService } = require('./services/energy.service');
const { SceneService } = require('./services/scene.service');
const { AutomationService } = require('./services/automation.service');
const { ScheduleService } = require('./services/schedule.service');
const { DeviceManagementService } = require('./services/device-management.service');
const { NotificationService } = require('./services/notification.service');
const { InvitationService } = require('./services/invitation.service');
const { SyncService } = require('./services/sync.service');
const { DataExportService } = require('./services/data-export.service');
const { DataRetentionService } = require('./services/data-retention.service');
const { ContextService } = require('./services/context.service');
const { IntelligenceService } = require('./services/intelligence.service');
const { ReliabilityService } = require('./services/reliability.service');
const { createPushProvider } = require('./services/push-notification-provider');

const { AuthApiRouter } = require('./api/auth.router');
const { AccountApiRouter } = require('./api/account.router');
const { InvitationApiRouter } = require('./api/invitation.router');
const { SyncApiRouter } = require('./api/sync.router');
const { HomeDeviceApiRouter } = require('./api/home-device.router');
const { ProvisioningClaimApiRouter } = require('./api/provisioning-claim.router');
const { ApiRouter: ProductCatalogApiRouter } = require('./api/product-catalog.router');
const { buildRouteHandlers: buildCommandRouteHandlers } = require('./api/device-command.router');
const { OtaApiRouter } = require('./api/ota.router');
const { EnergyApiRouter } = require('./api/energy.router');
const { ContextApiRouter } = require('./api/context.router');
const { IntelligenceApiRouter } = require('./api/intelligence.router');
const { ReliabilityApiRouter } = require('./api/reliability.router');
const { AutomationSceneApiRouter } = require('./api/automation-scene.router');
const { DeviceManagementApiRouter } = require('./api/device-management.router');
const { NotificationApiRouter } = require('./api/notification.router');
const { AutomationSchedulerWorker } = require('./workers/automation-scheduler-worker');
const { NotificationDeliveryWorker } = require('./workers/notification-delivery-worker');

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
  const notificationRepo = new NotificationRepository(db);
  const invitationRepo = new InvitationRepository(db);
  const syncRepo = new SyncRepository(db);
  const exportRepo = new ExportRepository(db);
  const firmwareRepo = new FirmwareReleaseRepository(db);
  const operationRepo = new OtaOperationRepository(db);
  const rolloutRepo = new OtaRolloutRepository(db);
  const maintenanceRepo = new DeviceMaintenanceRepository(db);
  const telemetryRepo = options.telemetryRepo || new DeviceTelemetryRepository(db);
  const aggregateRepo = options.aggregateRepo || new TelemetryAggregateRepository(db);
  const thresholdRepo = options.thresholdRepo || new EnergyThresholdRepository(db);
  const energyEventRepo = options.energyEventRepo || new EnergyEventRepository(db);
  const executionRepo = options.executionRepo || new EnergyAutomationExecutionRepository(db);
  const optimizationRepo = options.optimizationRepo || new EnergyOptimizationRepository(db);
  const tariffRepo = options.tariffRepo || new EnergyTariffRepository(db);
  const tariffPeriodRepo = options.tariffPeriodRepo || new TariffPeriodRepository(db);
  const budgetRepo = options.budgetRepo || new EnergyBudgetRepository(db);
  const costOptimizationRepo = options.costOptimizationRepo || new CostOptimizationRepository(db);
  const forecastRepo = options.forecastRepo || new EnergyForecastRepository(db);
  const anomalyRepo = options.anomalyRepo || new EnergyAnomalyRepository(db);
  const baselineRepo = options.baselineRepo || new EnergyBaselineRepository(db);
  const accuracyRepo = options.accuracyRepo || new ForecastAccuracyRepository(db);
  const efficiencyRepo = options.efficiencyRepo || new EnergyEfficiencyScoreRepository(db);
  const signalRepo = options.signalRepo || new PresenceSignalRepository(db);
  const presenceStateRepo = options.presenceStateRepo || new PresenceStateRepository(db);
  const contextRepo = options.contextRepo || new HomeContextRepository(db);
  const overrideRepo = options.overrideRepo || new ContextOverrideRepository(db);
  const transitionRepo = options.transitionRepo || new ContextTransitionRepository(db);
  const decisionRepo = options.decisionRepo || new IntelligenceDecisionRepository(db);
  const recommendationRepo = options.recommendationRepo || new IntelligenceRecommendationRepository(db);
  const outcomeRepo = options.outcomeRepo || new IntelligenceOutcomeRepository(db);
  // Phase 25 — Reliability repos
  const reliabilityIncidentRepo = options.reliabilityIncidentRepo || new ReliabilityIncidentRepository(db);
  const reliabilityDiagnosticRepo = options.reliabilityDiagnosticRepo || new ReliabilityDiagnosticRepository(db);
  const reliabilityRecoveryRepo = options.reliabilityRecoveryRepo || new ReliabilityRecoveryRepository(db);
  const reliabilitySnapshotRepo = options.reliabilitySnapshotRepo || new ReliabilityHealthSnapshotRepository(db);
  const maintenanceRecRepo = options.maintenanceRecRepo || new MaintenanceRecommendationRepository(db);

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

  const mqttTransport = options.mqttTransport || null;
  const eventBus = options.eventBus || null;
  const pushProvider = options.pushProvider || createPushProvider(options.pushProviderType || 'simulated');

  const authMiddleware = requireAuthentication(authService);
  const homeAuthService = new HomeAuthorizationService({ homeRepo, deviceRepo, roomRepo });

  const notificationService = options.notificationService || new NotificationService({
    notificationRepository: notificationRepo,
    homeRepository: homeRepo,
    userRepository: userRepo,
    realtimeEventBus: eventBus,
    pushProvider
  });

  const commandService = new DeviceCommandService({
    commandRepo, outboxRepo, deviceRepo, deviceStateRepo, auditRepo,
    mqttTransport
  });

  const sceneService = options.sceneService || new SceneService({
    sceneRepo, homeAuthService, deviceCommandService: commandService, eventBus, logRepo
  });

  const automationService = options.automationService || new AutomationService({
    automationRepo,
    homeAuthService,
    deviceCommandService: commandService,
    deviceStateRepo,
    eventBus,
    logRepo,
    telemetryRepo,
    aggregateRepo,
    energyExecutionRepo: executionRepo,
    notificationService,
    sceneService
  });

  const energyService = options.energyService || new EnergyService({
    telemetryRepo,
    aggregateRepo,
    thresholdRepo,
    eventRepo: energyEventRepo,
    deviceRepo,
    roomRepo,
    homeRepo,
    notificationService,
    realtimeEventBus: eventBus,
    automationService,
    optimizationRepo,
    tariffRepo,
    tariffPeriodRepo,
    budgetRepo,
    costOptimizationRepo,
    forecastRepo,
    anomalyRepo,
    baselineRepo,
    accuracyRepo,
    efficiencyRepo
  });

  const contextService = options.contextService || new ContextService({
    signalRepo,
    stateRepo: presenceStateRepo,
    contextRepo,
    overrideRepo,
    transitionRepo,
    homeRepo,
    deviceRepo,
    roomRepo,
    energyService,
    automationService,
    notificationService,
    realtimeEventBus: eventBus
  });

  automationService.setEnergyService(energyService);
  automationService.setContextService(contextService);

  const intelligenceService = options.intelligenceService || new IntelligenceService({
    decisionRepo,
    recommendationRepo,
    outcomeRepo,
    deviceRepo,
    deviceStateRepo,
    roomRepo,
    homeRepo,
    energyService,
    contextService,
    automationService,
    sceneService,
    commandService,
    notificationService,
    realtimeEventBus: eventBus,
    homeAuthService
  });

  // Phase 25 — Reliability Service
  const reliabilityService = options.reliabilityService || new ReliabilityService({
    incidentRepo: reliabilityIncidentRepo,
    diagnosticRepo: reliabilityDiagnosticRepo,
    recoveryRepo: reliabilityRecoveryRepo,
    snapshotRepo: reliabilitySnapshotRepo,
    maintenanceRepo: maintenanceRecRepo,
    deviceRepo,
    deviceStateRepo,
    healthRepo,
    commandService,
    intelligenceService,
    contextService,
    notificationService,
    realtimeEventBus: eventBus,
    homeAuthService
  });

  const ingestionService = new DeviceEventTelemetryIngestionService({
    deviceStateRepo,
    eventRepo,
    commandRepo,
    outboxRepo,
    auditRepo,
    activityLogRepo,
    healthRepo,
    energyService
  });

  const otaService = options.otaService || new OtaService({
    firmwareRepo,
    operationRepo,
    rolloutRepo,
    maintenanceRepo,
    deviceRepo,
    deviceStateRepo,
    homeRepo,
    roomRepo,
    homeAuthService,
    commandService,
    realtimeEventBus: eventBus,
    notificationService,
    productCatalogService: catalogService
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



  const invitationService = options.invitationService || new InvitationService({
    invitationRepo,
    homeRepo,
    userRepo,
    auditRepo,
    notificationService
  });

  const syncService = options.syncService || new SyncService({
    db,
    userRepo,
    homeRepo,
    roomRepo,
    deviceRepo,
    deviceStateRepo,
    sceneRepo,
    automationRepo,
    scheduleRepo,
    notificationRepo,
    syncRepo,
    homeAuthService
  });

  const dataExportService = options.dataExportService || new DataExportService({
    userRepo,
    homeRepo,
    roomRepo,
    deviceRepo,
    sceneRepo,
    automationRepo,
    scheduleRepo,
    notificationRepo,
    exportRepo
  });

  const dataRetentionService = options.dataRetentionService || new DataRetentionService({ db });

  const schedulerWorker = options.schedulerWorker || new AutomationSchedulerWorker({
    scheduleRepo, scheduleService
  });
  const notificationDeliveryWorker = options.notificationDeliveryWorker || new NotificationDeliveryWorker({
    notificationRepository: notificationRepo,
    pushProvider
  });

  if (options.startWorkers) {
    schedulerWorker.start();
    notificationDeliveryWorker.start();
  }

  // 3. API Routers
  const authRouter = new AuthApiRouter({ authService, rateLimiter: options.rateLimiter });
  const accountRouter = new AccountApiRouter({ authService, homeRepo });
  const invitationRouter = new InvitationApiRouter({ invitationService, userRepo });
  const syncRouter = new SyncApiRouter({ syncService, dataExportService, dataRetentionService });
  const homeDeviceRouter = new HomeDeviceApiRouter({
    homeService,
    floorService,
    roomService,
    deviceService,
    invitationService,
    homeAuthService
  });
  const provisioningRouter = new ProvisioningClaimApiRouter({ provisioningService, deviceClaimService });
  const catalogRouter = new ProductCatalogApiRouter();
  const otaRouter = new OtaApiRouter({ otaService });
  const energyRouter = new EnergyApiRouter({
    energyService,
    homeAuthService,
    telemetryRepo,
    thresholdRepo,
    eventRepo: energyEventRepo,
    automationService,
    executionRepo,
    optimizationRepo
  });
  const contextRouter = new ContextApiRouter({ contextService, homeAuthService });
  const intelligenceRouter = new IntelligenceApiRouter({ intelligenceService, homeAuthService });
  const reliabilityRouter = new ReliabilityApiRouter({ reliabilityService, homeAuthService });
  const automationSceneRouter = new AutomationSceneApiRouter({ sceneService, automationService, scheduleService });
  const deviceManagementRouter = new DeviceManagementApiRouter({
    deviceManagementService,
    db,
    mqttTransport,
    workers: { scheduler: schedulerWorker, notificationDelivery: notificationDeliveryWorker }
  });
  const notificationRouter = new NotificationApiRouter({
    notificationRepository: notificationRepo,
    notificationService,
    homeAuthorizationService: homeAuthService
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

    // 4.5. Route to Account Router (requires auth)
    if (pathname.startsWith('/api/v1/account')) {
      const actorContext = { userId: req.user ? req.user.id : null };
      const result = await accountRouter.handle(method, pathname, body, req.headers, actorContext);
      return sendJsonResponse(res, result.status, result.body);
    }

    // 4.6. Route to Invitations Router (requires auth)
    if (pathname.startsWith('/api/v1/invitations')) {
      const actorContext = { userId: req.user ? req.user.id : null };
      const result = await invitationRouter.handle(method, pathname, body, req.headers, actorContext);
      return sendJsonResponse(res, result.status, result.body);
    }

    // 5. Membership Authorization & Capability Enforcement for Home/Device/Command routes
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
        let requiredCapability = null;
        if (pathname === '/api/v1/commands/send' && method === 'POST') {
          requiredCapability = 'canControlDevices';
        } else if (pathname.includes('/scenes') && method === 'POST' && pathname.endsWith('/execute')) {
          requiredCapability = 'canExecuteAutomations';
        } else if (pathname.startsWith('/api/v1/homes/') && !pathname.includes('/', 15) && method === 'DELETE') {
          requiredCapability = 'canDeleteHome';
        } else if (pathname.startsWith('/api/v1/homes/') && !pathname.includes('/', 15) && method === 'PATCH') {
          requiredCapability = 'canManageHome';
        } else if (pathname.includes('/members') && (method === 'POST' || method === 'PATCH' || method === 'DELETE')) {
          requiredCapability = 'canManageMembers';
        } else if (pathname.includes('/invitations') && (method === 'POST' || method === 'DELETE')) {
          requiredCapability = 'canManageMembers';
        }

        const authCheck = await homeAuthService.authorizeRequest({
          userId,
          homeId: homeIdParam,
          deviceId: deviceIdParam,
          requiredCapability
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
          role: authCheck.role,
          permissions: authCheck.permissions
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

    // 8.5. Route to OTA & Fleet Router
    if (pathname.startsWith('/api/v1/ota') || pathname.startsWith('/api/v1/fleet')) {
      const result = await otaRouter.handle(method, pathname, body, query, req.user);
      return sendJsonResponse(res, result.status, result.body);
    }

    // 8.55. Route to Energy Intelligence & Telemetry Router (Phase 19)
    if (pathname.startsWith('/api/v1/energy')) {
      const actorContext = req.user ? { userId: req.user.id } : (req.actorContext || null);
      const result = await energyRouter.handleRequest({ method, path: pathname, query, body }, actorContext);
      return sendJsonResponse(res, result.statusCode, result.body);
    }

    // 8.56. Route to Context & Presence Router (Phase 23)
    if (pathname.startsWith('/api/v1/context')) {
      const actorContext = req.user ? { userId: req.user.id } : (req.actorContext || null);
      const result = await contextRouter.handleRequest({ method, path: pathname, query, body }, actorContext);
      return sendJsonResponse(res, result.statusCode, result.body);
    }

    // 8.57. Route to Smart Home Intelligence & Unified Decision Router (Phase 24)
    if (pathname.startsWith('/api/v1/intelligence')) {
      const actorContext = req.user ? { userId: req.user.id } : (req.actorContext || null);
      const result = await intelligenceRouter.handleRequest({ method, path: pathname, query, body }, actorContext);
      return sendJsonResponse(res, result.statusCode, result.body);
    }

    // 8.58. Route to Reliability & Self-Healing Router (Phase 25)
    if (pathname.startsWith('/api/v1/reliability')) {
      const actorContext = req.user ? { userId: req.user.id } : (req.actorContext || null);
      const result = await reliabilityRouter.handleRequest({ method, path: pathname, query, body }, actorContext);
      return sendJsonResponse(res, result.statusCode, result.body);
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

    // 8.8. Route to Notifications Router
    if (pathname.startsWith('/api/v1/notifications')) {
      if (req.user) {
        query.userId = req.user.id;
      }
      const notifResult = await notificationRouter.handle(method, pathname, body, req.headers, query);
      if (notifResult) {
        return sendJsonResponse(res, notifResult.status, notifResult.body);
      }
    }

    // 8.9. Route to Sync & Data Export Router
    if (pathname.startsWith('/api/v1/sync')) {
      const responseWrapper = createResponseWrapper(res);
      req.body = body;
      req.query = query;
      if (pathname === '/api/v1/sync/bootstrap' && method === 'GET') {
        return syncRouter.handleBootstrap(req, responseWrapper);
      }
      if (pathname === '/api/v1/sync/reconcile' && method === 'POST') {
        return syncRouter.handleReconcile(req, responseWrapper);
      }
      if (pathname === '/api/v1/sync/export' && method === 'GET') {
        return syncRouter.handleExport(req, responseWrapper);
      }
    }

    // 9. Route to Home & Device Domain Router
    if (pathname.startsWith('/api/v1/homes') || pathname.startsWith('/api/v1/devices')) {
      if (req.user) {
        query.userId = req.user.id;
        query.actorContext = req.actorContext || { userId: req.user.id };
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
      deviceManagementService,
      notificationService,
      invitationService,
      syncService,
      dataExportService,
      dataRetentionService,
      energyService,
      contextService,
      intelligenceService,
      reliabilityService,
      pushProvider,
      schedulerWorker,
      notificationDeliveryWorker
    },
    repositories: {
      userRepo, homeRepo, roomRepo, productRepo, capRepo, deviceRepo,
      deviceStateRepo, commandRepo, eventRepo, auditRepo, outboxRepo,
      provisioningRepo, refreshTokenRepo, sceneRepo, automationRepo,
      scheduleRepo, logRepo, activityLogRepo, healthRepo, notificationRepo,
      invitationRepo, syncRepo, exportRepo,
      firmwareRepo, operationRepo, rolloutRepo, maintenanceRepo,
      telemetryRepo, aggregateRepo, thresholdRepo, energyEventRepo,
      executionRepo, optimizationRepo,
      tariffRepo, tariffPeriodRepo, budgetRepo, costOptimizationRepo,
      forecastRepo, anomalyRepo, baselineRepo, accuracyRepo, efficiencyRepo,
      signalRepo, presenceStateRepo, contextRepo, overrideRepo, transitionRepo,
      decisionRepo, recommendationRepo, outcomeRepo,
      reliabilityIncidentRepo, reliabilityDiagnosticRepo, reliabilityRecoveryRepo,
      reliabilitySnapshotRepo, maintenanceRecRepo
    },
    contextApiRouter: contextRouter,
    energyApiRouter: energyRouter,
    intelligenceApiRouter: intelligenceRouter
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
