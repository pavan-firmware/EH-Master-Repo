export type HomeRole = 'OWNER' | 'ADMIN' | 'MEMBER' | 'GUEST' | 'VIEWER';

export type InvitationStatus = 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'REVOKED' | 'EXPIRED';

export interface HomeMembership {
  schemaVersion: number;
  homeId: string;
  userId: string;
  role: HomeRole;
  invitedAt: string;
  acceptedAt?: string | null;
}

export interface HomeInvitation {
  schemaVersion: number;
  id: string;
  homeId: string;
  inviterUserId: string;
  inviteeEmail: string;
  role: HomeRole;
  inviteCode: string;
  status: InvitationStatus;
  expiresAt: string;
  acceptedAt?: string | null;
  createdAt: string;
}

export interface UserProfile {
  id: string;
  email: string;
  fullName?: string | null;
  phoneNumber?: string | null;
  avatarUrl?: string | null;
  timezone: string;
  createdAt: string;
  updatedAt: string;
}

export interface AccountSession {
  id: string;
  userId: string;
  deviceName?: string | null;
  ipAddress?: string | null;
  userAgent?: string | null;
  createdAt: string;
  expiresAt: string;
  isCurrent?: boolean;
}

export interface HomePermissions {
  canManageHome: boolean;
  canDeleteHome: boolean;
  canManageMembers: boolean;
  canTransferOwnership: boolean;
  canManageDevices: boolean;
  canControlDevices: boolean;
  canManageAutomations: boolean;
  canExecuteAutomations: boolean;
  canViewHome: boolean;
}
