/**
 * EH Home Schema — auth-identity
 * Source: PostgreSQL Migrations 001–029
 */
import { boolean, pgTable, text, timestamp, unique, varchar } from 'drizzle-orm/pg-core';

// --- users (001_initial_schema.sql) ---
export const users = pgTable('users', {
  id: varchar('id', { length: 128 }).primaryKey(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  passwordHash: varchar('password_hash', { length: 255 }).notNull(),
  role: varchar('role', { length: 32 }).notNull().default('USER'),
  emailVerified: boolean('email_verified').default(false),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type Users = typeof users.$inferSelect;
export type NewUsers = typeof users.$inferInsert;

// --- refresh_tokens (001_initial_schema.sql) ---
export const refreshTokens = pgTable('refresh_tokens', {
  id: varchar('id', { length: 128 }).primaryKey(),
  userId: varchar('user_id', { length: 128 }).notNull(),
  tokenHash: varchar('token_hash', { length: 255 }).notNull(),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  deviceName: varchar('device_name', { length: 128 }),
  ipAddress: varchar('ip_address', { length: 45 }),
  userAgent: text('user_agent'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
});

export type RefreshTokens = typeof refreshTokens.$inferSelect;
export type NewRefreshTokens = typeof refreshTokens.$inferInsert;

// --- user_profiles (009_account_home_access_control.sql) ---
export const userProfiles = pgTable('user_profiles', {
  id: varchar('id', { length: 64 }).primaryKey(),
  fullName: varchar('full_name', { length: 128 }),
  phoneNumber: varchar('phone_number', { length: 32 }),
  avatarUrl: text('avatar_url'),
  timezone: varchar('timezone', { length: 64 }).notNull().default('UTC'),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type UserProfiles = typeof userProfiles.$inferSelect;
export type NewUserProfiles = typeof userProfiles.$inferInsert;

// --- home_invitations (009_account_home_access_control.sql) ---
export const homeInvitations = pgTable('home_invitations', {
  id: varchar('id', { length: 64 }).primaryKey(),
  homeId: varchar('home_id', { length: 64 }).notNull(),
  inviterUserId: varchar('inviter_user_id', { length: 64 }).notNull(),
  inviteeEmail: varchar('invitee_email', { length: 255 }).notNull(),
  role: varchar('role', { length: 32 }).notNull(),
  inviteCode: varchar('invite_code', { length: 128 }).notNull().unique(),
  status: varchar('status', { length: 32 }).notNull().default('PENDING'),
  expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
  acceptedAt: timestamp('accepted_at', { withTimezone: true }),
  createdAt: timestamp('created_at', { withTimezone: true }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true }).notNull().defaultNow(),
});

export type HomeInvitations = typeof homeInvitations.$inferSelect;
export type NewHomeInvitations = typeof homeInvitations.$inferInsert;

// --- home_memberships (001_initial_schema.sql) ---
export const homeMemberships = pgTable('home_memberships', {
  id: varchar('id', { length: 255 }).primaryKey(),
  homeId: varchar('home_id', { length: 128 }).notNull(),
  userId: varchar('user_id', { length: 128 }).notNull(),
  role: varchar('role', { length: 32 }).notNull(),
  invitedAt: timestamp('invited_at', { withTimezone: true }).notNull().defaultNow(),
  acceptedAt: timestamp('accepted_at', { withTimezone: true }),
}, (t) => [
  unique().on(t.homeId, t.userId),
]);

export type HomeMemberships = typeof homeMemberships.$inferSelect;
export type NewHomeMemberships = typeof homeMemberships.$inferInsert;
