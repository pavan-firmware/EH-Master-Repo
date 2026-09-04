/**
 * EH Home — Product Catalog & Consumer Device Add API Route Handlers (Phase 27)
 */

'use strict';

const { ProductCatalogService } = require('../services/product-catalog.service');

class ApiRouter {
  constructor(options = {}) {
    this.catalog = options.catalogService || new ProductCatalogService();
    this.deviceAddService = options.deviceAddService || null;
  }

  async handle(method, pathname, params = {}, body = {}, actorContext = null) {
    // 1. GET /api/v1/products/discovery
    if (method === 'GET' && pathname === '/api/v1/products/discovery') {
      return this._getDiscovery(params);
    }

    // 2. GET /api/v1/products/search
    if (method === 'GET' && pathname === '/api/v1/products/search') {
      return this._searchProducts(params);
    }

    // 3. GET /api/v1/products/categories
    if (method === 'GET' && pathname === '/api/v1/products/categories') {
      return this._getCategories();
    }

    // 4. GET /api/v1/products/families
    if (method === 'GET' && pathname === '/api/v1/products/families') {
      return this._getFamilies();
    }

    // 5. POST /api/v1/products/compatibility
    if (method === 'POST' && pathname === '/api/v1/products/compatibility') {
      return this._checkCompatibility(body);
    }

    // 6. Device Add Sessions
    if (pathname.startsWith('/api/v1/device-add/sessions')) {
      return this._handleDeviceAdd(method, pathname, params, body, actorContext);
    }

    // 7. GET /api/v1/products/variants/:variantId or /api/v1/product-variants/:variantId
    if (method === 'GET' && (pathname.startsWith('/api/v1/products/variants/') || pathname.startsWith('/api/v1/product-variants/'))) {
      const variantId = pathname.replace('/api/v1/products/variants/', '').replace('/api/v1/product-variants/', '');
      return this._getProductVariant(variantId);
    }

    // 8. GET /api/v1/products/:productId (not discovery or search)
    if (method === 'GET' && pathname.startsWith('/api/v1/products/') && !pathname.includes('/variants/') && pathname !== '/api/v1/products/discovery' && pathname !== '/api/v1/products/search') {
      const productId = pathname.replace('/api/v1/products/', '');
      return this._getProduct(productId);
    }

    // 9. GET /api/v1/products (legacy / list all)
    if (method === 'GET' && pathname === '/api/v1/products') {
      return this._getProducts();
    }

    // 10. GET /api/v1/capabilities
    if (method === 'GET' && pathname === '/api/v1/capabilities') {
      return this._getCapabilities();
    }

    // 11. GET /api/v1/capabilities/:capabilityId
    if (method === 'GET' && pathname.startsWith('/api/v1/capabilities/')) {
      const capabilityId = pathname.replace('/api/v1/capabilities/', '');
      return this._getCapability(capabilityId);
    }

    // 12. GET /api/v1/devices/:deviceId/capabilities
    if (method === 'GET' && pathname.includes('/capabilities') && pathname.startsWith('/api/v1/devices/')) {
      const deviceId = pathname.replace('/api/v1/devices/', '').replace('/capabilities', '');
      return this._getDeviceCapabilities(deviceId, params);
    }

    return { status: 404, body: { error: 'Not Found', path: pathname } };
  }

  _getDiscovery(query = {}) {
    const res = this.catalog.discoverProducts({
      category: query.category,
      family: query.family,
      capability: query.capability,
      connectivity: query.connectivity,
      status: query.status || 'ACTIVE',
      includeAllStatuses: query.includeAll === 'true' || query.all === 'true',
      page: query.page,
      limit: query.limit,
      sort: query.sort
    });

    return {
      status: 200,
      body: {
        data: res,
        schemaVersion: 1
      }
    };
  }

  _searchProducts(query = {}) {
    const res = this.catalog.searchProducts({
      query: query.q || query.query || '',
      category: query.category,
      family: query.family,
      limit: query.limit,
      status: query.status || 'ACTIVE'
    });

    return {
      status: 200,
      body: {
        data: res,
        schemaVersion: 1
      }
    };
  }

  _getCategories() {
    const categories = this.catalog.getCategories();
    return {
      status: 200,
      body: {
        data: categories,
        total: categories.length,
        schemaVersion: 1
      }
    };
  }

  _getFamilies() {
    const families = this.catalog.getFamilies();
    return {
      status: 200,
      body: {
        data: families,
        total: families.length,
        schemaVersion: 1
      }
    };
  }

  _getProduct(productId) {
    const product = this.catalog.getProductById(productId);
    if (!product) {
      return { status: 404, body: { error: `Product '${productId}' not found` } };
    }
    return { status: 200, body: { data: product, schemaVersion: 1 } };
  }

  _getProductVariant(variantId) {
    const variant = this.catalog.formatProductVariantResponse(variantId);
    if (!variant) {
      return { status: 404, body: { error: `Product variant '${variantId}' not found` } };
    }
    return { status: 200, body: { data: variant, schemaVersion: 1 } };
  }

  _checkCompatibility(body = {}) {
    if (!body.productVariantId) {
      return { status: 400, body: { error: 'productVariantId is required for compatibility check' } };
    }

    const result = this.catalog.resolveCompatibility({
      productVariantId: body.productVariantId,
      hardwareRevision: body.hardwareRevision,
      firmwareVersion: body.firmwareVersion,
      homeCapabilities: body.homeCapabilities,
      availableConnectivity: body.availableConnectivity,
      installedHubProtocols: body.installedHubProtocols
    });

    return {
      status: 200,
      body: {
        data: result,
        schemaVersion: 1
      }
    };
  }

  async _handleDeviceAdd(method, pathname, query = {}, body = {}, actorContext = null) {
    if (!this.deviceAddService) {
      return { status: 501, body: { error: 'DeviceAddService not initialized' } };
    }

    const userId = actorContext?.userId || query.userId || body.userId;

    // POST /api/v1/device-add/sessions (Start session)
    if (method === 'POST' && pathname === '/api/v1/device-add/sessions') {
      if (!body.homeId) {
        return { status: 400, body: { error: 'homeId is required to start a device add session' } };
      }
      if (!userId) {
        return { status: 401, body: { error: 'Unauthorized: user identity required' } };
      }

      const session = await this.deviceAddService.startSession({
        homeId: body.homeId,
        userId,
        entryMode: body.entryMode || 'MANUAL_CATALOG',
        productVariantId: body.productVariantId,
        selectedRoomId: body.selectedRoomId,
        customDeviceName: body.customDeviceName,
        channelLabels: body.channelLabels
      });

      return { status: 201, body: { data: session, schemaVersion: 1 } };
    }

    // POST /api/v1/device-add/sessions/:sessionId/progress
    if (method === 'POST' && pathname.endsWith('/progress')) {
      const sessionId = pathname.replace('/api/v1/device-add/sessions/', '').replace('/progress', '');
      const updated = await this.deviceAddService.progressSession(sessionId, body);
      if (!updated) {
        return { status: 404, body: { error: `Session '${sessionId}' not found` } };
      }
      return { status: 200, body: { data: updated, schemaVersion: 1 } };
    }

    // POST /api/v1/device-add/sessions/:sessionId/complete
    if (method === 'POST' && pathname.endsWith('/complete')) {
      const sessionId = pathname.replace('/api/v1/device-add/sessions/', '').replace('/complete', '');
      try {
        const res = await this.deviceAddService.completeSession(sessionId, body);
        return { status: 200, body: { data: res, schemaVersion: 1 } };
      } catch (err) {
        return { status: 400, body: { error: err.message } };
      }
    }

    // POST /api/v1/device-add/sessions/:sessionId/cancel
    if (method === 'POST' && pathname.endsWith('/cancel')) {
      const sessionId = pathname.replace('/api/v1/device-add/sessions/', '').replace('/cancel', '');
      const cancelled = await this.deviceAddService.cancelSession(sessionId, userId, body.reason);
      if (!cancelled) {
        return { status: 404, body: { error: `Session '${sessionId}' not found` } };
      }
      return { status: 200, body: { data: cancelled, schemaVersion: 1 } };
    }

    // GET /api/v1/device-add/sessions/:sessionId
    if (method === 'GET' && pathname.startsWith('/api/v1/device-add/sessions/')) {
      const sessionId = pathname.replace('/api/v1/device-add/sessions/', '');
      const session = await this.deviceAddService.getSession(sessionId, userId, query.homeId);
      if (!session) {
        return { status: 404, body: { error: `Session '${sessionId}' not found` } };
      }
      return { status: 200, body: { data: session, schemaVersion: 1 } };
    }

    return { status: 404, body: { error: 'Not Found', path: pathname } };
  }

  _getProducts() {
    const products = this.catalog.formatProductListResponse();
    return {
      status: 200,
      body: {
        data: products,
        total: products.length,
        schemaVersion: 1
      }
    };
  }

  _getCapabilities() {
    const capabilities = this.catalog.formatCapabilityListResponse();
    return {
      status: 200,
      body: {
        data: capabilities,
        total: capabilities.length,
        schemaVersion: 1
      }
    };
  }

  _getCapability(capabilityId) {
    const cap = this.catalog.formatCapabilityResponse(capabilityId);
    if (!cap) {
      return { status: 404, body: { error: `Capability '${capabilityId}' not found` } };
    }
    return { status: 200, body: { data: cap, schemaVersion: 1 } };
  }

  _getDeviceCapabilities(deviceId, params = {}) {
    const productVariantId = params.productVariantId || 'eh-smart-switch-3x';
    const channelLabels = params.channelLabels || {};

    const resolved = this.catalog.resolveDeviceCapabilities({
      productVariantId,
      deviceId,
      channelLabels
    });

    if (resolved.error) {
      return { status: 404, body: { error: resolved.error } };
    }

    return {
      status: 200,
      body: {
        data: resolved,
        schemaVersion: 1
      }
    };
  }
}

module.exports = { ApiRouter };
