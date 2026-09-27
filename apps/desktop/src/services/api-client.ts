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
  status: 'UP' | 'DOWN';
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

  constructor(baseUrl?: string) {
    this.baseUrl = baseUrl || getDesktopConfig().apiBaseUrl;
  }

  private async request<T>(path: string, options: RequestInit = {}): Promise<ApiClientResponse<T>> {
    const url = `${this.baseUrl}${path.startsWith('/') ? path : `/${path}`}`;
    const requestId = `dt-${Date.now().toString(36)}-${Math.random().toString(36).substring(2, 8)}`;

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'x-request-id': requestId,
      ...(options.headers as Record<string, string>),
    };

    try {
      const res = await fetch(url, {
        ...options,
        headers,
      });

      const respRequestId = res.headers.get('x-request-id') || requestId;
      let body: any;
      try {
        body = await res.json();
      } catch {
        body = null;
      }

      if (!res.ok) {
        logger.warn(`API request to ${path} failed with HTTP ${res.status}`, body);
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
      logger.error(`Network error connecting to API at ${url}`, err.message);
      return {
        success: false,
        statusCode: 0,
        requestId,
        error: {
          code: 'NETWORK_ERROR',
          message: err.message || 'Unable to connect to EH Home API service',
        },
      };
    }
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
}

export const apiClient = new ApiClient();
