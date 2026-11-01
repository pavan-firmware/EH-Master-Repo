"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.homeMemberships = exports.homeInvitations = exports.userProfiles = exports.refreshTokens = exports.users = void 0;
/**
 * EH Home Schema — auth-identity
 * Source: PostgreSQL Migrations 001–029
 */
const pg_core_1 = require("drizzle-orm/pg-core");
// --- users (001_initial_schema.sql) ---
exports.users = (0, pg_core_1.pgTable)('users', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    email: (0, pg_core_1.varchar)('email', { length: 255 }).notNull().unique(),
    passwordHash: (0, pg_core_1.varchar)('password_hash', { length: 255 }).notNull(),
    role: (0, pg_core_1.varchar)('role', { length: 32 }).notNull().default('USER'),
    emailVerified: (0, pg_core_1.boolean)('email_verified').default(false),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- refresh_tokens (001_initial_schema.sql) ---
exports.refreshTokens = (0, pg_core_1.pgTable)('refresh_tokens', {
    id: (0, pg_core_1.varchar)('id', { length: 128 }).primaryKey(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 128 }).notNull(),
    tokenHash: (0, pg_core_1.varchar)('token_hash', { length: 255 }).notNull(),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }).notNull(),
    deviceName: (0, pg_core_1.varchar)('device_name', { length: 128 }),
    ipAddress: (0, pg_core_1.varchar)('ip_address', { length: 45 }),
    userAgent: (0, pg_core_1.text)('user_agent'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- user_profiles (009_account_home_access_control.sql) ---
exports.userProfiles = (0, pg_core_1.pgTable)('user_profiles', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    fullName: (0, pg_core_1.varchar)('full_name', { length: 128 }),
    phoneNumber: (0, pg_core_1.varchar)('phone_number', { length: 32 }),
    avatarUrl: (0, pg_core_1.text)('avatar_url'),
    timezone: (0, pg_core_1.varchar)('timezone', { length: 64 }).notNull().default('UTC'),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- home_invitations (009_account_home_access_control.sql) ---
exports.homeInvitations = (0, pg_core_1.pgTable)('home_invitations', {
    id: (0, pg_core_1.varchar)('id', { length: 64 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 64 }).notNull(),
    inviterUserId: (0, pg_core_1.varchar)('inviter_user_id', { length: 64 }).notNull(),
    inviteeEmail: (0, pg_core_1.varchar)('invitee_email', { length: 255 }).notNull(),
    role: (0, pg_core_1.varchar)('role', { length: 32 }).notNull(),
    inviteCode: (0, pg_core_1.varchar)('invite_code', { length: 128 }).notNull().unique(),
    status: (0, pg_core_1.varchar)('status', { length: 32 }).notNull().default('PENDING'),
    expiresAt: (0, pg_core_1.timestamp)('expires_at', { withTimezone: true }).notNull(),
    acceptedAt: (0, pg_core_1.timestamp)('accepted_at', { withTimezone: true }),
    createdAt: (0, pg_core_1.timestamp)('created_at', { withTimezone: true }).notNull().defaultNow(),
    updatedAt: (0, pg_core_1.timestamp)('updated_at', { withTimezone: true }).notNull().defaultNow(),
});
// --- home_memberships (001_initial_schema.sql) ---
exports.homeMemberships = (0, pg_core_1.pgTable)('home_memberships', {
    id: (0, pg_core_1.varchar)('id', { length: 255 }).primaryKey(),
    homeId: (0, pg_core_1.varchar)('home_id', { length: 128 }).notNull(),
    userId: (0, pg_core_1.varchar)('user_id', { length: 128 }).notNull(),
    role: (0, pg_core_1.varchar)('role', { length: 32 }).notNull(),
    invitedAt: (0, pg_core_1.timestamp)('invited_at', { withTimezone: true }).notNull().defaultNow(),
    acceptedAt: (0, pg_core_1.timestamp)('accepted_at', { withTimezone: true }),
}, (t) => [
    (0, pg_core_1.unique)().on(t.homeId, t.userId),
]);
//# sourceMappingURL=auth-identity.js.map