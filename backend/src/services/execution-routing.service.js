'use strict';

const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();

/**
 * ExecutionRoutingService (Phase 28)
 *
 * Single, deterministic Local vs Cloud execution router.
 * Evaluates network reachability, home presence, transport health, device state,
 * and command safety to decide the optimal execution mode without asking the consumer.
 */
class ExecutionRoutingService {
  /**
   * @param {Object} opts
   * @param {Object} opts.localRouteRepo     - LocalRouteCacheRepository
   * @param {Object} opts.connectivityService- ConnectivityService (Phase 26)
   * @param {Object} opts.deviceRepo         - DeviceRepository
   * @param {Object} opts.homeAuthService    - HomeAuthService
   * @param {Object} [opts.contextService]   - ContextService (Phase 23 presence/context)
   * @param {Object} [opts.reliabilityService]- ReliabilityService (Phase 25)
   */
  constructor({
    localRouteRepo,
    connectivityService,
    deviceRepo,
    homeAuthService,
    contextService = null,
    reliabilityService = null
  }) {
    this.localRouteRepo = localRouteRepo;
    this.connectivityService = connectivityService;
    this.deviceRepo = deviceRepo;
    this.homeAuthService = homeAuthService;
    this.contextService = contextService;
    this.reliabilityService = reliabilityService;

    // In-memory flags for simulated / dynamic cloud connectivity
    this._isCloudReachable = true;
    this._phoneLocalNetworkActive = true;
  }

  setCloudReachability(isReachable) {
    this._isCloudReachable = Boolean(isReachable);
  }

  setPhoneLocalNetwork(isActive) {
    this._phoneLocalNetworkActive = Boolean(isActive);
  }

  /**
   * Compute the optimal execution route for a target device and command intent.
   *
   * @param {Object} params
   * @param {String} params.deviceId
   * @param {String} params.homeId
   * @param {String} [params.action]
   * @param {String} [params.preferredRoute] - 'AUTO' | 'LOCAL_ONLY' | 'CLOUD_ONLY'
   * @param {Object} [params.actorContext]
   * @returns {Promise<Object>} ExecutionRouteDecision
   */
  async decideRoute({
    deviceId,
    homeId,
    action = 'setPower',
    preferredRoute = 'AUTO',
    actorContext = null
  }) {
    const decisionId = `dec_${uuidv4()}`;
    const now = new Date().toISOString();

    // 1. Verify device exists & belongs to home
    const device = await this.deviceRepo.findById(deviceId);
    let deviceInHome = false;
    if (device) {
      if (device.home_id === homeId || device.homeId === homeId) {
        deviceInHome = true;
      } else if (typeof this.deviceRepo.getDeviceAuthorization === 'function') {
        const auth = await this.deviceRepo.getDeviceAuthorization(deviceId);
        if (auth && (auth.home_id === homeId || auth.homeId === homeId)) {
          deviceInHome = true;
        }
      }
    }

    if (!device || !deviceInHome) {
      return {
        decisionId,
        deviceId,
        homeId,
        routeMode: 'UNAVAILABLE',
        selectedTransport: 'NONE',
        localEndpoint: null,
        confidenceScore: 0.0,
        fallbackOrder: [],
        isCloudAvailable: this._isCloudReachable,
        isLocalAvailable: false,
        decisionRationale: `Device ${deviceId} not found in home ${homeId}`,
        decidedAt: now
      };
    }

    // 2. Fetch local route cache & transport state
    const localRoute = await this.localRouteRepo.findByDevice(deviceId);
    const hasActiveLocalRoute = localRoute &&
      localRoute.reachability === 'REACHABLE' &&
      new Date(localRoute.expiresAt) > new Date();

    // 3. Check Phase 26 transport health if available
    let transportSelection = null;
    if (this.connectivityService && typeof this.connectivityService.selectOptimalTransport === 'function') {
      try {
        transportSelection = await this.connectivityService.selectOptimalTransport(deviceId);
      } catch (_) {
        transportSelection = null;
      }
    }

    // 4. Evaluate phone local presence / context
    const isUserInHomeLan = this._phoneLocalNetworkActive;

    // 5. Evaluate Route Mode based on policy
    // Policy:
    //  - If preferredRoute === 'LOCAL_ONLY', never use cloud
    //  - If preferredRoute === 'CLOUD_ONLY', use cloud if reachable
    //  - Prefer LOCAL when phone is on Home LAN AND device is reachable locally
    //  - Use CLOUD when phone is remote OR local route is unavailable, but cloud is up
    //  - Use DEFERRED only for non-critical offline mutations (e.g. metadata)
    //  - Return UNAVAILABLE if neither local nor cloud can execute

    let routeMode = 'UNAVAILABLE';
    let selectedTransport = 'NONE';
    let localEndpoint = null;
    let confidenceScore = 0.0;
    const fallbackOrder = [];
    let decisionRationale = '';

    const isLocalPossible = isUserInHomeLan && hasActiveLocalRoute;
    const isCloudPossible = this._isCloudReachable;

    if (preferredRoute === 'LOCAL_ONLY') {
      if (isLocalPossible) {
        routeMode = 'LOCAL';
        selectedTransport = localRoute.transportType || 'WIFI_MQTT';
        localEndpoint = localRoute.localEndpoint;
        confidenceScore = 0.95;
        decisionRationale = 'Strict local execution requested and local route verified';
      } else {
        routeMode = 'UNAVAILABLE';
        decisionRationale = 'Local route unavailable and LOCAL_ONLY preferred';
      }
    } else if (preferredRoute === 'CLOUD_ONLY') {
      if (isCloudPossible) {
        routeMode = 'CLOUD';
        selectedTransport = 'WIFI_MQTT';
        confidenceScore = 0.90;
        decisionRationale = 'Cloud execution explicitly requested';
      } else {
        routeMode = 'UNAVAILABLE';
        decisionRationale = 'Cloud unavailable and CLOUD_ONLY preferred';
      }
    } else {
      // AUTO Policy:
      if (isLocalPossible) {
        routeMode = 'LOCAL';
        selectedTransport = localRoute.transportType || 'WIFI_MQTT';
        localEndpoint = localRoute.localEndpoint;
        confidenceScore = 0.98;
        if (isCloudPossible) fallbackOrder.push('CLOUD');
        if (localRoute.transportType === 'WIFI_MQTT') fallbackOrder.unshift('BLE');
        decisionRationale = 'Phone on LAN with validated direct local device reachability';
      } else if (isCloudPossible) {
        routeMode = 'CLOUD';
        selectedTransport = (transportSelection && transportSelection.selectedTransport) ? transportSelection.selectedTransport : 'WIFI_MQTT';
        confidenceScore = 0.85;
        if (hasActiveLocalRoute) fallbackOrder.push('LOCAL');
        decisionRationale = isUserInHomeLan
          ? 'Local endpoint degraded or expired; routing through cloud'
          : 'Remote user outside Home LAN; routing through cloud';
      } else {
        // Both local and cloud down
        // Check if action can be safely deferred (e.g. metadata or scene toggle)
        if (action === 'updateLabel' || action === 'setSchedule') {
          routeMode = 'DEFERRED';
          selectedTransport = 'NONE';
          confidenceScore = 0.50;
          decisionRationale = 'Network offline; action queued for deferred reconciliation';
        } else {
          routeMode = 'UNAVAILABLE';
          selectedTransport = 'NONE';
          confidenceScore = 0.0;
          decisionRationale = 'All local and cloud execution paths are offline';
        }
      }
    }

    return {
      decisionId,
      deviceId,
      homeId,
      routeMode,
      selectedTransport,
      localEndpoint,
      confidenceScore,
      fallbackOrder,
      isCloudAvailable: this._isCloudReachable,
      isLocalAvailable: isLocalPossible,
      decisionRationale,
      decidedAt: now
    };
  }
}

module.exports = { ExecutionRoutingService };
