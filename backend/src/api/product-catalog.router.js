/**
 * EH Home — Product Catalog API Route Handlers (Phase 3)
 *
 * Read-only internal/development API endpoints.
 * These are NOT authenticated in Phase 3 — authentication is a later phase.
 *
 * Endpoints:
 *  GET /api/v1/products
 *  GET /api/v1/product-variants/:variantId
 *  GET /api/v1/capabilities
 *  GET /api/v1/capabilities/:capabilityId
 *  GET /api/v1/devices/:deviceId/capabilities  (development stub)
 */

const { ProductCatalogService } = require('../services/product-catalog.service');

const catalog = new ProductCatalogService();

// Simulates a lightweight request/response handler compatible with
// Fastify-style route signatures for future real integration.
class ApiRouter {
  constructor() {
    this.routes = new Map();
    this._registerRoutes();
  }

  _registerRoutes() {
    this.routes.set('GET /api/v1/products', () => this._getProducts());
    this.routes.set('GET /api/v1/capabilities', () => this._getCapabilities());
  }

  async handle(method, path, params = {}) {
    // Exact match first
    const exactKey = `${method} ${path}`;
    if (this.routes.has(exactKey)) {
      return this.routes.get(exactKey)(params);
    }

    // Pattern match: /api/v1/product-variants/:variantId
    if (method === 'GET' && path.startsWith('/api/v1/product-variants/')) {
      const variantId = path.replace('/api/v1/product-variants/', '');
      return this._getProductVariant(variantId);
    }

    // Pattern match: /api/v1/capabilities/:capabilityId
    if (method === 'GET' && path.startsWith('/api/v1/capabilities/')) {
      const capabilityId = path.replace('/api/v1/capabilities/', '');
      return this._getCapability(capabilityId);
    }

    // Pattern match: /api/v1/devices/:deviceId/capabilities
    if (method === 'GET' && path.includes('/capabilities') && path.startsWith('/api/v1/devices/')) {
      const deviceId = path.replace('/api/v1/devices/', '').replace('/capabilities', '');
      return this._getDeviceCapabilities(deviceId, params);
    }

    return { status: 404, body: { error: 'Not Found', path } };
  }

  _getProducts() {
    const products = catalog.formatProductListResponse();
    return {
      status: 200,
      body: {
        data: products,
        total: products.length,
        schemaVersion: 1
      }
    };
  }

  _getProductVariant(variantId) {
    const variant = catalog.formatProductVariantResponse(variantId);
    if (!variant) {
      return { status: 404, body: { error: `Product variant '${variantId}' not found` } };
    }
    return { status: 200, body: { data: variant, schemaVersion: 1 } };
  }

  _getCapabilities() {
    const capabilities = catalog.formatCapabilityListResponse();
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
    const cap = catalog.formatCapabilityResponse(capabilityId);
    if (!cap) {
      return { status: 404, body: { error: `Capability '${capabilityId}' not found` } };
    }
    return { status: 200, body: { data: cap, schemaVersion: 1 } };
  }

  _getDeviceCapabilities(deviceId, params = {}) {
    // Development stub — in production this would look up the device's productVariantId
    // from DeviceRepository and then resolve against ProductCatalogService.
    // For Phase 3, we accept productVariantId as a query param.
    const productVariantId = params.productVariantId || 'eh-smart-switch-3x';
    const channelLabels = params.channelLabels || {};

    const resolved = catalog.resolveDeviceCapabilities({
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
