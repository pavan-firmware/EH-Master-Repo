/**
 * Typed API Client for apps/api Communication
 * Preserves correlation IDs and standardizes error responses.
 */

import { getDesktopConfig } from '../lib/config';
import { logger } from '../lib/logger';

export interface ApiClientResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
  statusCode: number;
  requestId?: string;
}

export interface HealthStatus {
  // Older/released API builds report READY from /health, while current builds
  // report UP. Both are successful liveness responses; DOWN is never returned
  // with a successful HTTP response.
  status: 'UP' | 'READY' | 'DOWN';
  uptimeSeconds: number;
  timestamp: string;
}

export interface ReadinessStatus {
  status: 'READY' | 'DOWN';
  dependencies: {
    database: string;
  };
  timestamp: string;
}

export interface SystemInfo {
  service: string;
  version: string;
  nodeVersion: string;
  environment: string;
  uptimeSeconds: number;
  timestamp: string;
}

export class ApiClient {
  private readonly baseUrl: string;
  private inFlightGetRequests = new Map<string, Promise<ApiClientResponse<any>>>();

  constructor(baseUrl?: string) {
    this.baseUrl = baseUrl || getDesktopConfig().apiBaseUrl;
  }

  public resolveAssetUrl(url?: string | null): string | undefined {
    if (!url) return undefined;
    return /^https?:\/\//i.test(url) ? url : `${this.baseUrl}${url.startsWith('/') ? url : `/${url}`}`;
  }

  private async request<T>(path: string, options: RequestInit = {}): Promise<ApiClientResponse<T>> {
    const isGet = !options.method || options.method.toUpperCase() === 'GET';
    const cacheKey = isGet ? `${path}` : null;

    if (cacheKey && this.inFlightGetRequests.has(cacheKey)) {
      return this.inFlightGetRequests.get(cacheKey)! as Promise<ApiClientResponse<T>>;
    }

    const exec = (async () => {
      const url = `${this.baseUrl}${path.startsWith('/') ? path : `/${path}`}`;
      const requestId = typeof crypto !== 'undefined' && crypto.randomUUID ? `dt-${crypto.randomUUID().slice(0, 12)}` : `dt-${Date.now().toString(36)}`;
      const startTime = performance.now();

      const headers: Record<string, string> = {
        ...(options.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        'x-request-id': requestId,
        ...(options.headers as Record<string, string>),
      };

      try {
        const res = await fetch(url, {
          ...options,
          headers,
        });

        const durationMs = Math.round(performance.now() - startTime);
        const respRequestId = res.headers.get('x-request-id') || requestId;
        let body: any;
        try {
          body = await res.json();
        } catch {
          body = null;
        }

        if (!res.ok) {
          logger.warn(`API [${requestId}] ${options.method || 'GET'} ${path} failed (${res.status}) in ${durationMs}ms`, body);
          return {
            success: false,
            statusCode: res.status,
            requestId: respRequestId,
            error: body?.error || {
              code: `HTTP_${res.status}`,
              message: res.statusText || 'Request failed',
            },
          };
        }

        // If envelope contains data field, unwrap it
        const data = body?.data !== undefined ? body.data : body;

        return {
          success: true,
          statusCode: res.status,
          requestId: respRequestId,
          data,
        };
      } catch (err: any) {
        const durationMs = Math.round(performance.now() - startTime);
        logger.error(`API [${requestId}] ${options.method || 'GET'} ${url} network failure in ${durationMs}ms:`, err.message);
        return {
          success: false,
          statusCode: 0,
          requestId,
          error: {
            code: 'NETWORK_ERROR',
            message: err.message || 'Unable to connect to EH Home API service',
          },
        };
      } finally {
        if (cacheKey) {
          this.inFlightGetRequests.delete(cacheKey);
        }
      }
    })();

    if (cacheKey) {
      this.inFlightGetRequests.set(cacheKey, exec);
    }

    return exec;
  }

  public async checkHealth(): Promise<ApiClientResponse<HealthStatus>> {
    return this.request<HealthStatus>('/health');
  }

  public async checkReadiness(): Promise<ApiClientResponse<ReadinessStatus>> {
    return this.request<ReadinessStatus>('/ready');
  }

  public async getSystemInfo(): Promise<ApiClientResponse<SystemInfo>> {
    return this.request<SystemInfo>('/api/v1/system/info');
  }

  public async echo(message: string): Promise<ApiClientResponse<{ echo: string; receivedAt: string }>> {
    return this.request('/api/v1/system/echo', {
      method: 'POST',
      body: JSON.stringify({ message }),
    });
  }

  public async registerInventory(data: { traceabilityRecord: any; stationId: string; qrToken?: string }): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/inventory/register', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  public async getInventoryDevice(identifier: string): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/inventory/device/${encodeURIComponent(identifier)}`);
  }

  public async dualScanVerify(payload: any): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/inventory/dual-scan', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async createCarton(payload: {
    cartonCode: string;
    productVariantId: string;
    hardwareRevision: string;
    targetCapacity?: number;
    operatorUserId?: string;
  }): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/inventory/cartons', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async getCarton(cartonId: string): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/inventory/cartons/${encodeURIComponent(cartonId)}`);
  }

  public async completePacking(payload: any): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/inventory/pack', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async getPackingHistory(params?: { limit?: number; offset?: number }): Promise<ApiClientResponse<any>> {
    const q = params ? `?limit=${params.limit ?? 20}&offset=${params.offset ?? 0}` : '';
    return this.request(`/api/v1/inventory/history${q}`);
  }

  // ── Part 05: Product Catalog Endpoints ──────────────────────────────

  public async listProducts(params?: { familyId?: string; status?: string; limit?: number; offset?: number }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    if (params?.familyId) query.set('familyId', params.familyId);
    if (params?.status) query.set('status', params.status);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/products${qs}`);
  }

  public async listVariants(params?: { familyId?: string; productId?: string; limit?: number; offset?: number; databaseOnly?: boolean }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    if (params?.familyId) query.set('familyId', params.familyId);
    if (params?.productId) query.set('productId', params.productId);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    if (params?.databaseOnly) query.set('databaseOnly', 'true');
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/products/variants${qs}`);
  }

  public async listProductFamilies(): Promise<ApiClientResponse<any[]>> {
    return this.request<any[]>('/api/v1/products/families');
  }

  public async getProductVariant(variantId: string): Promise<ApiClientResponse<any>> {
    return this.request<any>(`/api/v1/products/variants/${encodeURIComponent(variantId)}`);
  }

  public async getProduct(productId: string): Promise<ApiClientResponse<any>> {
    return this.request<any>(`/api/v1/products/${encodeURIComponent(productId)}`);
  }

  // ── Part 06: Hardware & BOM Endpoints ──────────────────────────────

  public async listHardwareRevisions(params?: { productVariantId?: string; status?: string; limit?: number; offset?: number }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    if (params?.productVariantId) query.set('productVariantId', params.productVariantId);
    if (params?.status) query.set('status', params.status);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/hardware/revisions${qs}`);
  }

  public async getHardwareRevision(revisionId: string): Promise<ApiClientResponse<any>> {
    return this.request<any>(`/api/v1/hardware/revisions/${encodeURIComponent(revisionId)}`);
  }

  public async getBOM(revisionId: string): Promise<ApiClientResponse<any>> {
    return this.request<any>(`/api/v1/hardware/revisions/${encodeURIComponent(revisionId)}/bom`);
  }

  // ── Part 07: Firmware & Releases Endpoints ──────────────────────────

  public async listFirmwareFamilies(params?: { status?: string; limit?: number; offset?: number }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    if (params?.status) query.set('status', params.status);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/firmware/families${qs}`);
  }

  public async getFirmwareFamily(familyId: string): Promise<ApiClientResponse<any>> {
    return this.request<any>(`/api/v1/firmware/families/${encodeURIComponent(familyId)}`);
  }

  public async listFirmwareReleases(params?: { familyId?: string; lifecycleStatus?: string; limit?: number; offset?: number }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    if (params?.familyId) query.set('familyId', params.familyId);
    if (params?.lifecycleStatus) query.set('lifecycleStatus', params.lifecycleStatus);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/firmware/releases${qs}`);
  }

  public async getFirmwareRelease(releaseId: string): Promise<ApiClientResponse<any>> {
    return this.request<any>(`/api/v1/firmware/releases/${encodeURIComponent(releaseId)}`);
  }

  public async createProduct(payload: any): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/products', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async updateProduct(productId: string, payload: any): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/products/${encodeURIComponent(productId)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  public async createVariant(payload: any): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/products/variants', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async updateVariant(variantId: string, payload: any): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/products/variants/${encodeURIComponent(variantId)}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  }

  public async uploadVariantAsset(variantId: string, payload: { kind: string; filename: string; contentBase64: string }): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/products/variants/${encodeURIComponent(variantId)}/assets`, {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async deleteVariantAsset(variantId: string, assetId: string): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/products/variants/${encodeURIComponent(variantId)}/assets/${encodeURIComponent(assetId)}`, { method: 'DELETE' });
  }

  public async createHardwareRevision(payload: any): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/hardware/revisions', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async updateHardwareRevisionStatus(revisionId: string, status: string, reason?: string): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/hardware/revisions/${encodeURIComponent(revisionId)}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status, reason }),
    });
  }

  public async createBOM(revisionIdOrPayload: string | any, optionalPayload?: any): Promise<ApiClientResponse<any>> {
    const revisionId = typeof revisionIdOrPayload === 'string' ? revisionIdOrPayload : revisionIdOrPayload.revisionCode || revisionIdOrPayload.revisionId;
    const payload = typeof revisionIdOrPayload === 'string' ? optionalPayload : revisionIdOrPayload;
    return this.request(`/api/v1/hardware/revisions/${encodeURIComponent(revisionId)}/bom`, {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async createFirmwareRelease(payload: any): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/firmware/releases', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async updateFirmwareReleaseStatus(releaseId: string, status: string, reason?: string): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/firmware/releases/${encodeURIComponent(releaseId)}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status, reason }),
    });
  }

  public async listDevices(params?: { search?: string; query?: string; limit?: number; offset?: number }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    const searchVal = params?.search || params?.query;
    if (searchVal) query.set('search', searchVal);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/devices${qs}`);
  }

  public async getDevice(deviceId: string): Promise<ApiClientResponse<any>> {
    return this.request<any>(`/api/v1/devices/${encodeURIComponent(deviceId)}`);
  }

  public async updateDeviceLifecycle(deviceId: string, action: string, reason?: string): Promise<ApiClientResponse<any>> {
    return this.request(`/api/v1/devices/${encodeURIComponent(deviceId)}/lifecycle`, {
      method: 'PATCH',
      body: JSON.stringify({ action, reason }),
    });
  }

  public async listInventoryItems(params?: { status?: string; productVariantId?: string; limit?: number; offset?: number }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    if (params?.status) query.set('status', params.status);
    if (params?.productVariantId) query.set('productVariantId', params.productVariantId);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/inventory/items${qs}`);
  }

  public async listCartons(params?: { status?: string; limit?: number; offset?: number }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    if (params?.status) query.set('status', params.status);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/inventory/cartons${qs}`);
  }

  public async listQcRecords(params?: { stationId?: string; deviceId?: string; limit?: number; offset?: number }): Promise<ApiClientResponse<any[]>> {
    const query = new URLSearchParams();
    if (params?.stationId) query.set('stationId', params.stationId);
    if (params?.deviceId) query.set('deviceId', params.deviceId);
    if (params?.limit) query.set('limit', String(params.limit));
    if (params?.offset) query.set('offset', String(params.offset));
    const qs = query.toString() ? `?${query.toString()}` : '';
    return this.request<any[]>(`/api/v1/inventory/qc${qs}`);
  }

  public async recordQcOperation(payload: any): Promise<ApiClientResponse<any>> {
    return this.request('/api/v1/inventory/qc', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
  }

  public async adjustInventory(deviceIdOrPayload: string | any, status?: string, notes?: string): Promise<ApiClientResponse<any>> {
    const body = typeof deviceIdOrPayload === 'string'
      ? { deviceId: deviceIdOrPayload, status, notes }
      : deviceIdOrPayload;
    return this.request('/api/v1/inventory/adjust', {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }
}

export const apiClient = new ApiClient();

