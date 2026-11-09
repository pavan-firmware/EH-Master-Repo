"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authRoutes = void 0;
const drizzle_orm_1 = require("drizzle-orm");
const node_crypto_1 = require("node:crypto");
const db_schema_1 = require("@eh-home/db-schema");
const secret = () => process.env.AUTH_TOKEN_SECRET || 'eh-home-local-auth-secret-change-me';
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const decode = (value) => JSON.parse(Buffer.from(value, 'base64url').toString('utf8'));
const passwordHash = (password) => {
    const salt = (0, node_crypto_1.randomBytes)(16).toString('hex');
    const hash = (0, node_crypto_1.pbkdf2Sync)(password, salt, 100_000, 64, 'sha256').toString('hex');
    return `pbkdf2:sha256:100000:${salt}:${hash}`;
};
const verifyPassword = (password, stored) => {
    const parts = stored.split(':');
    if (parts.length !== 5 || parts[0] !== 'pbkdf2' || parts[1] !== 'sha256')
        return false;
    const actual = (0, node_crypto_1.pbkdf2Sync)(password, parts[3], Number(parts[2]), 64, 'sha256').toString('hex');
    const a = Buffer.from(actual, 'utf8');
    const b = Buffer.from(parts[4], 'utf8');
    return a.length === b.length && (0, node_crypto_1.timingSafeEqual)(a, b);
};
const sign = (value) => (0, node_crypto_1.createHmac)('sha256', secret()).update(value).digest('base64url');
const accessToken = (user) => {
    const header = encode({ alg: 'HS256', typ: 'JWT' });
    const payload = encode({ sub: user.id, email: user.email, role: user.role || 'USER', type: 'access', exp: Math.floor(Date.now() / 1000) + 900 });
    return `${header}.${payload}.${sign(`${header}.${payload}`)}`;
};
const refreshToken = (userId) => {
    const body = encode({ sub: userId, type: 'refresh', exp: Date.now() + 30 * 86400_000 });
    return `eh1.${body}.${sign(`eh1.${body}`)}`;
};
const validRefresh = (token) => {
    const parts = token.split('.');
    if (parts.length !== 3 || parts[0] !== 'eh1' || sign(`${parts[0]}.${parts[1]}`) !== parts[2])
        return null;
    const payload = decode(parts[1]);
    return payload.type === 'refresh' && payload.exp > Date.now() && payload.sub ? String(payload.sub) : null;
};
const userPayload = (user, profile) => ({
    id: user.id,
    email: user.email,
    role: user.role || 'USER',
    emailVerified: user.emailVerified ?? false,
    fullName: profile?.fullName || null,
});
const authRoutes = async (app) => {
    const requireDb = (reply) => {
        if (!app.db) {
            reply.status(503).send({ success: false, error: { code: 'AUTH_DATABASE_UNAVAILABLE', message: 'Authentication database is unavailable.' } });
            return false;
        }
        return true;
    };
    app.post('/register', async (req, reply) => {
        if (!requireDb(reply))
            return;
        const body = (req.body || {});
        const email = String(body.email || '').trim().toLowerCase();
        const password = String(body.password || '');
        if (!email.includes('@') || password.length < 8)
            return reply.status(400).send({ success: false, error: { code: 'INVALID_INPUT', message: 'Use a valid email and a password of at least 8 characters.' } });
        const db = app.db;
        const existing = await db.select().from(db_schema_1.users).where((0, drizzle_orm_1.eq)(db_schema_1.users.email, email)).limit(1);
        if (existing.length)
            return reply.status(409).send({ success: false, error: { code: 'DUPLICATE_EMAIL', message: 'An account with this email already exists.' } });
        const id = (0, node_crypto_1.randomUUID)();
        const user = { id, email, passwordHash: passwordHash(password), role: 'USER', emailVerified: false };
        await db.insert(db_schema_1.users).values(user);
        await db.insert(db_schema_1.userProfiles).values({ id, fullName: body.fullName || body.name || null });
        return reply.status(201).send({ success: true, data: userPayload(user) });
    });
    app.post('/login', async (req, reply) => {
        if (!requireDb(reply))
            return;
        const body = (req.body || {});
        const email = String(body.email || '').trim().toLowerCase();
        const password = String(body.password || '');
        const db = app.db;
        const rows = await db.select().from(db_schema_1.users).where((0, drizzle_orm_1.eq)(db_schema_1.users.email, email)).limit(1);
        const user = rows[0];
        if (!user || !verifyPassword(password, user.passwordHash))
            return reply.status(401).send({ success: false, error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password.' } });
        const profiles = await db.select().from(db_schema_1.userProfiles).where((0, drizzle_orm_1.eq)(db_schema_1.userProfiles.id, user.id)).limit(1);
        return reply.send({ success: true, data: { accessToken: accessToken(user), refreshToken: refreshToken(user.id), user: userPayload(user, profiles[0]) } });
    });
    app.post('/refresh', async (req, reply) => {
        if (!requireDb(reply))
            return;
        const userId = validRefresh(String(req.body?.refreshToken || ''));
        if (!userId)
            return reply.status(401).send({ success: false, error: { code: 'INVALID_REFRESH_TOKEN', message: 'Refresh token is invalid or expired.' } });
        const db = app.db;
        const rows = await db.select().from(db_schema_1.users).where((0, drizzle_orm_1.eq)(db_schema_1.users.id, userId)).limit(1);
        const user = rows[0];
        if (!user)
            return reply.status(401).send({ success: false, error: { code: 'INVALID_REFRESH_TOKEN', message: 'Refresh token is invalid.' } });
        const profiles = await db.select().from(db_schema_1.userProfiles).where((0, drizzle_orm_1.eq)(db_schema_1.userProfiles.id, user.id)).limit(1);
        return reply.send({ success: true, data: { accessToken: accessToken(user), refreshToken: refreshToken(user.id), user: userPayload(user, profiles[0]) } });
    });
    app.delete('/logout', async (_req, reply) => reply.send({ success: true, data: { message: 'Logged out successfully' } }));
};
exports.authRoutes = authRoutes;
//# sourceMappingURL=auth.routes.js.map