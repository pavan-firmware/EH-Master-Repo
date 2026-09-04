/**
 * EH Home Canonical Product Catalog & Discovery Contract Types (v4.0)
 */

export type ProductCategory =
  | 'switches'
  | 'sockets'
  | 'lighting'
  | 'climate'
  | 'sensors'
  | 'energy'
  | 'security'
  | 'fans'
  | 'appliances'
  | 'controllers';

export type ProductStatus =
  | 'DRAFT'
  | 'ACTIVE'
  | 'COMING_SOON'
  | 'DISCONTINUED'
  | 'DEPRECATED';

export type ProductVisibility = 'PUBLIC' | 'ADMIN_ONLY' | 'BETA';

export type CompatibilityStatus =
  | 'COMPATIBLE'
  | 'PARTIALLY_COMPATIBLE'
  | 'INCOMPATIBLE';

export type ReasonSeverity = 'INFO' | 'WARNING' | 'BLOCKING';

export type DeviceAddEntryMode =
  | 'QR_SCAN'
  | 'NEARBY_DISCOVERY'
  | 'MANUAL_CATALOG'
  | 'RE_ADD_RESET'
  | 'MATTER_COMMISSIONING';

export type DeviceAddStage =
  | 'PRODUCT_SELECTED'
  | 'COMPATIBILITY_CHECKED'
  | 'DISCOVERING_DEVICE'
  | 'COMMISSIONING'
  | 'REGISTERED'
  | 'CLAIMED'
  | 'CONFIGURED'
  | 'VERIFIED'
  | 'COMPLETED'
  | 'FAILED'
  | 'CANCELLED';

export interface ProductFamilyDef {
  familyId: string;
  slug: string;
  displayName: string;
  category: ProductCategory;
  description: string;
  icon?: string;
  sortOrder?: number;
}

export interface ProductModelDef {
  modelId: string;
  familyId: string;
  marketingName: string;
  technicalName: string;
  description: string;
  generation?: number;
  brand?: string;
}

export interface ProductAssetDef {
  hero?: string;
  front?: string;
  rear?: string;
  installed?: string;
  packaging?: string;
  technicalDiagram?: string;
  icon?: string;
  thumbnail?: string;
}

export interface ProductVariantDef {
  variantId: string;
  modelId: string;
  sku: string;
  marketingName: string;
  technicalName: string;
  channelCount: number;
  channels: Array<{
    channelIndex: number;
    defaultLabel: string;
    capabilities: string[];
    config?: Record<string, any>;
  }>;
  hardwareProfile: any;
  connectivityProfile: any;
  capabilities: string[];
  electricalSpecifications: {
    voltageRange: string;
    frequencyHz: string;
    maxCurrentPerChannelAmps?: number;
    maxTotalCurrentAmps?: number;
  };
  firmwareFamily: string;
  supportedHardwareRevisions: string[];
  supportedFirmwareVersions?: string[];
}

export interface ProductCatalogEntry {
  productId: string;
  productFamilyId: string;
  modelId: string;
  variantId: string;
  sku: string;
  marketingName: string;
  technicalName: string;
  description: string;
  productStatus: ProductStatus;
  visibility: ProductVisibility;
  category: string;
  subcategory?: string | null;
  brand?: string;
  images?: ProductAssetDef;
  icon?: string | null;
  channelCount: number;
  channels?: Array<any>;
  electricalSpecifications?: Record<string, any>;
  capabilities: string[];
  controls: string[];
  telemetry: string[];
  automationCapabilities: string[];
  connectivityCapabilities: string[];
  commissioningCapabilities: string[];
  otaCapabilities: {
    supported: boolean;
    dualPartition: boolean;
    firmwareFamily: string;
  };
  supportedHardwareRevisions: string[];
  supportedFirmwareVersions: string[];
  matterSupport: boolean;
  threadSupport: boolean;
  wifiSupport: boolean;
  bleProvisioningSupport: boolean;
  energyMonitoringSupport: boolean;
  localControlSupport: boolean;
}

export interface ProductDiscoveryResponse {
  products: ProductCatalogEntry[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  categories: Array<{ id: string; displayName: string; count: number }>;
  families: Array<{ id: string; displayName: string; category: string; count: number }>;
  availableCapabilities: string[];
}

export interface ProductSearchResultItem {
  product: ProductCatalogEntry;
  matchedFields: string[];
  relevanceScore: number;
}

export interface ProductSearchResult {
  query: string;
  results: ProductSearchResultItem[];
  total: number;
}

export interface ProductCompatibilityReason {
  code: string;
  message: string;
  severity: ReasonSeverity;
  remedy?: string | null;
}

export interface ProductCompatibility {
  status: CompatibilityStatus;
  isCompatible: boolean;
  reasons: ProductCompatibilityReason[];
  supportedTransports: string[];
  recommendedCommissioningTransport: string;
  unsupportedFeatures: string[];
  evaluatedAt: string;
}

export interface DeviceAddSession {
  sessionId: string;
  homeId: string;
  userId: string;
  entryMode: DeviceAddEntryMode;
  stage: DeviceAddStage;
  productVariantId?: string | null;
  deviceId?: string | null;
  commissioningSessionId?: string | null;
  selectedRoomId?: string | null;
  customDeviceName?: string | null;
  channelLabels?: Record<string, string> | null;
  compatibilityStatus?: string | null;
  errorMessage?: string | null;
  createdAt: string;
  updatedAt: string;
  completedAt?: string | null;
}
