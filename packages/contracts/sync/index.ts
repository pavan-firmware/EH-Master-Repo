/**
 * EH Home — Canonical Synchronization & Data Lifecycle Contracts (Phase 17)
 */

export interface SyncBootstrapBundle {
  schemaVersion: number;
  syncedAt: string;
  user: {
    id: string;
    email: string;
    fullName?: string | null;
    phoneNumber?: string | null;
    avatarUrl?: string | null;
    timezone: string;
  };
  homes: Array<{
    id: string;
    name: string;
    timezone: string;
    address?: string | null;
    role: string;
    permissions: Record<string, boolean>;
    membersCount: number;
  }>;
  members: Array<{
    membershipId: string;
    homeId: string;
    userId: string;
    email?: string;
    role: string;
  }>;
  rooms: Array<{
    id: string;
    homeId: string;
    name: string;
    displayOrder: number;
  }>;
  devices: Array<{
    id: string;
    homeId: string;
    roomId?: string | null;
    customName: string;
    productVariantId: string;
    isOnline: boolean;
    capabilities: string[];
    channelCount: number;
    healthStatus: string;
    lastSeenAt?: string | null;
  }>;
  automations: Array<{
    id: string;
    homeId: string;
    name: string;
    enabled: boolean;
    trigger: Record<string, any>;
    actions: Record<string, any>[];
  }>;
  scenes: Array<{
    id: string;
    homeId: string;
    name: string;
    actions: Record<string, any>[];
  }>;
  schedules: Array<{
    id: string;
    homeId: string;
    name: string;
    enabled: boolean;
    cronExpression: string;
  }>;
  notificationPreferences?: Record<string, boolean>;
}

export interface PendingMutation {
  mutationId: string;
  entityType: 'home' | 'room' | 'device' | 'scene' | 'automation' | 'profile' | 'notification_preference';
  entityId?: string | null;
  mutationType: 'create' | 'update' | 'delete' | 'reorder';
  payload: Record<string, any>;
  clientTimestamp: string;
  expectedVersion?: number;
}

export interface MutationResult {
  mutationId: string;
  status: 'ACCEPTED' | 'REJECTED' | 'CONFLICT';
  reason?: string;
  serverEntityId?: string;
  authoritativeData?: Record<string, any>;
}

export interface ReconciliationResult {
  reconciledAt: string;
  totalMutations: number;
  acceptedCount: number;
  rejectedCount: number;
  conflictCount: number;
  results: MutationResult[];
}

export interface DataExportBundle {
  exportVersion: number;
  exportedAt: string;
  exportedBy: string;
  scope: 'USER' | 'HOME';
  homeId?: string | null;
  user: {
    id: string;
    email: string;
    fullName?: string | null;
    timezone: string;
    createdAt?: string;
  };
  homes?: Array<{
    id: string;
    name: string;
    timezone: string;
    role: string;
    rooms: Array<{ id: string; name: string }>;
    devices: Array<{
      id: string;
      customName: string;
      productVariantId: string;
      roomName?: string;
    }>;
    automations: Array<{ id: string; name: string; enabled: boolean }>;
    scenes: Array<{ id: string; name: string }>;
    schedules: Array<{ id: string; name: string; enabled: boolean; cronExpression: string }>;
  }>;
  notifications?: Array<{
    id: string;
    category: string;
    title: string;
    body: string;
    createdAt: string;
  }>;
}
