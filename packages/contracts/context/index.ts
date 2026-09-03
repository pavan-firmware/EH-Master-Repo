/**
 * EH Home — Phase 23 Presence and Context Intelligence TypeScript Contracts
 */

export type PresenceSource =
  | 'mobile_app'
  | 'manual'
  | 'lan_wifi'
  | 'ble'
  | 'device_activity'
  | 'sensor';

export type PresenceState = 'HOME' | 'AWAY' | 'UNKNOWN' | 'SLEEP';

export type ContextMode =
  | 'HOME'
  | 'AWAY'
  | 'SLEEP'
  | 'VACATION'
  | 'GUEST'
  | 'QUIET_HOURS';

export type PrecedenceTier =
  | 'MANUAL_OVERRIDE'
  | 'SCHEDULED_WINDOW'
  | 'RECONCILED_PRESENCE'
  | 'DEFAULT_FALLBACK';

export interface PresenceSignal {
  id?: string;
  userId: string;
  homeId: string;
  source: PresenceSource;
  state: PresenceState;
  confidence: number;
  observedAt: string;
  expiresAt?: string;
  evidence?: Record<string, unknown>;
}

export interface InferredRoomPresence {
  roomId: string;
  isOccupied: boolean;
  confidence: number;
  isInferred: boolean;
  inferenceReason?: string;
  lastActivityAt?: string;
}

export interface PresenceSnapshot {
  homeId: string;
  state: PresenceState;
  confidence: number;
  isOccupied: boolean;
  activeUserCount: number;
  userStates?: Record<
    string,
    {
      state: PresenceState;
      confidence: number;
      source: string;
      observedAt: string;
      isStale?: boolean;
    }
  >;
  inferredRooms?: InferredRoomPresence[];
  calculatedAt: string;
}

export interface PresenceOverride {
  id: string;
  homeId: string;
  userId: string;
  mode: ContextMode;
  state?: PresenceState;
  reason?: string;
  createdAt: string;
  expiresAt?: string | null;
  isActive: boolean;
}

export interface HomeContext {
  homeId: string;
  mode: ContextMode;
  previousMode?: string | null;
  precedenceTier: PrecedenceTier;
  activeOverride?: {
    id: string;
    userId: string;
    mode: string;
    reason?: string;
    expiresAt?: string | null;
  } | null;
  isVacation: boolean;
  isOccupied: boolean;
  confidence: number;
  updatedAt: string;
}

export interface ContextTransition {
  id: string;
  homeId: string;
  fromMode: string;
  toMode: ContextMode;
  triggerSource: string;
  reason?: string;
  evidence?: Record<string, unknown>;
  timestamp: string;
}
