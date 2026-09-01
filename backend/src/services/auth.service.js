'use strict';

/**
 * EH Home — AuthService (Phase 7A)
 *
 * Implements user authentication, password hashing, RS256 access token issuance,
 * refresh token rotation with single-use replay protection, and session logout.
 */

const crypto = require('crypto');
// Generate default ephemeral RSA 2048 keypair for local development / testing
let devKeyPair = null;
function getDevKeyPair() {
  if (!devKeyPair) {
    devKeyPair = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
    });
  }
  return devKeyPair;
}

/**
 * Helper to generate a random UUID using Node.js native crypto
 */
function generateUuid() {
  return crypto.randomUUID();
}

/**
 * Convert string to Base64URL string (RFC 7515)
 */
function base64UrlEncode(strOrBuffer) {
  const buf = Buffer.isBuffer(strOrBuffer) ? strOrBuffer : Buffer.from(strOrBuffer, 'utf8');
  return buf.toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

/**
 * Convert Base64URL string to Buffer
 */
function base64UrlDecode(str) {
  let base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4) {
    base64 += '=';
  }
  return Buffer.from(base64, 'base64');
}

class AuthService {
  constructor({ userRepo, refreshTokenRepo, privateKey = null, publicKey = null, accessTtlSeconds = 900, refreshTtlDays = 30 }) {
    this.userRepo = userRepo;
    this.refreshTokenRepo = refreshTokenRepo;
    this.accessTtlSeconds = accessTtlSeconds;
    this.refreshTtlDays = refreshTtlDays;

    if (privateKey && publicKey) {
      this.privateKey = privateKey;
      this.publicKey = publicKey;
    } else {
      const keys = getDevKeyPair();
      this.privateKey = keys.privateKey;
      this.publicKey = keys.publicKey;
    }
  }

  // --- Password Hashing Utilities ---

  hashPassword(password) {
    const salt = crypto.randomBytes(16).toString('hex');
    const hash = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha256').toString('hex');
    return `pbkdf2:sha256:100000:${salt}:${hash}`;
  }

  verifyPassword(password, storedPasswordHash) {
    if (!storedPasswordHash || typeof storedPasswordHash !== 'string') return false;
    const parts = storedPasswordHash.split(':');
    if (parts.length !== 5 || parts[0] !== 'pbkdf2' || parts[1] !== 'sha256') {
      return false;
    }
    const iterations = parseInt(parts[2], 10);
    const salt = parts[3];
    const expectedHash = parts[4];

    const actualHash = crypto.pbkdf2Sync(password, salt, iterations, 64, 'sha256').toString('hex');
    return crypto.timingSafeEqual(Buffer.from(actualHash, 'utf8'), Buffer.from(expectedHash, 'utf8'));
  }

  // --- JWT Sign / Verify Utilities ---

  signAccessToken(user) {
    const nowSec = Math.floor(Date.now() / 1000);
    const header = { alg: 'RS256', typ: 'JWT' };
    const payload = {
      sub: user.id,
      email: user.email,
      type: 'access',
      iss: 'eh-home-auth',
      aud: 'eh-home-api',
      iat: nowSec,
      exp: nowSec + this.accessTtlSeconds
    };

    const headerEncoded = base64UrlEncode(JSON.stringify(header));
    const payloadEncoded = base64UrlEncode(JSON.stringify(payload));
    const dataToSign = `${headerEncoded}.${payloadEncoded}`;

    const signer = crypto.createSign('RSA-SHA256');
    signer.update(dataToSign);
    const signature = signer.sign(this.privateKey, 'base64');
    const signatureEncoded = signature.replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

    return `${dataToSign}.${signatureEncoded}`;
  }

  verifyAccessToken(token) {
    if (!token || typeof token !== 'string') {
      throw new Error('Token missing');
    }
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new Error('Malformed token');
    }

    const [headerB64, payloadB64, sigB64] = parts;

    let header, payload;
    try {
      header = JSON.parse(base64UrlDecode(headerB64).toString('utf8'));
      payload = JSON.parse(base64UrlDecode(payloadB64).toString('utf8'));
    } catch (_) {
      throw new Error('Malformed token json');
    }

    if (header.alg !== 'RS256') {
      throw new Error(`Unsupported algorithm '${header.alg}'`);
    }
    if (payload.type !== 'access') {
      throw new Error('Invalid token type');
    }
    if (payload.iss !== 'eh-home-auth' || payload.aud !== 'eh-home-api') {
      throw new Error('Invalid issuer or audience');
    }

    const nowSec = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < nowSec) {
      throw new Error('Token expired');
    }

    const dataToVerify = `${headerB64}.${payloadB64}`;
    const verifier = crypto.createVerify('RSA-SHA256');
    verifier.update(dataToVerify);

    const sigBuffer = base64UrlDecode(sigB64);
    const isValid = verifier.verify(this.publicKey, sigBuffer);

    if (!isValid) {
      throw new Error('Invalid signature');
    }

    return payload;
  }

  // --- Refresh Token Utilities ---

  hashRefreshToken(rawToken) {
    return crypto.createHash('sha256').update(rawToken).digest('hex');
  }

  generateRawRefreshToken() {
    return crypto.randomBytes(32).toString('hex');
  }

  // --- Auth Workflow Methods ---

  async register({ email, password }) {
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      throw new Error('Invalid email address');
    }
    if (!password || typeof password !== 'string' || password.length < 8) {
      throw new Error('Password must be at least 8 characters long');
    }

    const existing = await this.userRepo.findByEmail(email);
    if (existing) {
      const err = new Error(`User with email '${email}' already exists`);
      err.code = 'DUPLICATE_EMAIL';
      throw err;
    }

    const userId = generateUuid();
    const passwordHash = this.hashPassword(password);

    const user = await this.userRepo.createUser({
      id: userId,
      email: email.toLowerCase().trim(),
      passwordHash,
      emailVerified: false
    });

    return {
      schemaVersion: 1,
      id: user.id,
      email: user.email,
      emailVerified: user.email_verified || false,
      createdAt: user.created_at
    };
  }

  async login({ email, password }) {
    if (!email || !password) {
      throw new Error('Email and password are required');
    }

    const user = await this.userRepo.findByEmail(email.toLowerCase().trim());
    if (!user) {
      const err = new Error('Invalid email or password');
      err.code = 'INVALID_CREDENTIALS';
      throw err;
    }

    const isValid = this.verifyPassword(password, user.password_hash);
    if (!isValid) {
      const err = new Error('Invalid email or password');
      err.code = 'INVALID_CREDENTIALS';
      throw err;
    }

    const accessToken = this.signAccessToken(user);

    const rawRefreshToken = this.generateRawRefreshToken();
    const tokenHash = this.hashRefreshToken(rawRefreshToken);
    const expiresAt = new Date(Date.now() + this.refreshTtlDays * 24 * 60 * 60 * 1000).toISOString();

    await this.refreshTokenRepo.createToken({
      id: generateUuid(),
      userId: user.id,
      tokenHash,
      expiresAt
    });

    return {
      schemaVersion: 1,
      tokenType: 'Bearer',
      accessToken,
      refreshToken: rawRefreshToken,
      expiresIn: this.accessTtlSeconds,
      user: {
        schemaVersion: 1,
        id: user.id,
        email: user.email,
        emailVerified: user.email_verified || false,
        createdAt: user.created_at
      }
    };
  }

  async refresh({ refreshToken }) {
    if (!refreshToken || typeof refreshToken !== 'string') {
      const err = new Error('Refresh token is required');
      err.code = 'INVALID_REFRESH_TOKEN';
      throw err;
    }

    const tokenHash = this.hashRefreshToken(refreshToken);
    const tokenRecord = await this.refreshTokenRepo.findByTokenHash(tokenHash);

    if (!tokenRecord) {
      const err = new Error('Invalid or revoked refresh token');
      err.code = 'INVALID_REFRESH_TOKEN';
      throw err;
    }

    // Check expiration
    if (new Date(tokenRecord.expires_at) < new Date()) {
      await this.refreshTokenRepo.deleteToken(tokenRecord.id);
      const err = new Error('Refresh token expired');
      err.code = 'EXPIRED_REFRESH_TOKEN';
      throw err;
    }

    // Enforce single-use refresh token rotation: delete current token
    await this.refreshTokenRepo.deleteToken(tokenRecord.id);

    const user = await this.userRepo.findById(tokenRecord.user_id);
    if (!user) {
      const err = new Error('User not found for refresh token');
      err.code = 'INVALID_REFRESH_TOKEN';
      throw err;
    }

    // Issue new access token and new rotated refresh token
    const newAccessToken = this.signAccessToken(user);
    const newRawRefreshToken = this.generateRawRefreshToken();
    const newTokenHash = this.hashRefreshToken(newRawRefreshToken);
    const expiresAt = new Date(Date.now() + this.refreshTtlDays * 24 * 60 * 60 * 1000).toISOString();

    await this.refreshTokenRepo.createToken({
      id: generateUuid(),
      userId: user.id,
      tokenHash: newTokenHash,
      expiresAt
    });

    return {
      schemaVersion: 1,
      tokenType: 'Bearer',
      accessToken: newAccessToken,
      refreshToken: newRawRefreshToken,
      expiresIn: this.accessTtlSeconds,
      user: {
        schemaVersion: 1,
        id: user.id,
        email: user.email,
        emailVerified: user.email_verified || false,
        createdAt: user.created_at
      }
    };
  }

  async logout({ refreshToken }) {
    if (!refreshToken || typeof refreshToken !== 'string') {
      return true;
    }
    const tokenHash = this.hashRefreshToken(refreshToken);
    const tokenRecord = await this.refreshTokenRepo.findByTokenHash(tokenHash);
    if (tokenRecord) {
      await this.refreshTokenRepo.deleteToken(tokenRecord.id);
    }
    return true;
  }

  async getProfile(userId) {
    const profile = await this.userRepo.getProfile(userId);
    if (!profile) {
      const err = new Error(`User ${userId} not found`);
      err.code = 'USER_NOT_FOUND';
      throw err;
    }
    return profile;
  }

  async updateProfile(userId, { fullName, phoneNumber, avatarUrl, timezone }) {
    await this.userRepo.upsertProfile(userId, { fullName, phoneNumber, avatarUrl, timezone });
    return this.getProfile(userId);
  }

  async changePassword(userId, { oldPassword, newPassword }) {
    if (!oldPassword || !newPassword) {
      throw new Error('Old password and new password are required');
    }
    if (newPassword.length < 8) {
      throw new Error('New password must be at least 8 characters long');
    }

    const user = await this.userRepo.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    const isValid = this.verifyPassword(oldPassword, user.password_hash);
    if (!isValid) {
      const err = new Error('Invalid existing password');
      err.code = 'INVALID_PASSWORD';
      throw err;
    }

    const newPasswordHash = this.hashPassword(newPassword);
    await this.userRepo.updatePassword(userId, newPasswordHash);

    // Invalidate other refresh tokens for security
    await this.refreshTokenRepo.revokeAllExcept(userId, null);

    return { success: true, message: 'Password updated successfully' };
  }

  async listSessions(userId) {
    return this.refreshTokenRepo.listActiveSessions(userId);
  }

  async revokeSession(userId, sessionId) {
    return this.refreshTokenRepo.revokeSession(sessionId, userId);
  }

  async deleteAccount(userId, { password, homeRepo = null }) {
    if (!password) {
      throw new Error('Password confirmation is required to delete account');
    }

    const user = await this.userRepo.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    const isValid = this.verifyPassword(password, user.password_hash);
    if (!isValid) {
      const err = new Error('Invalid password confirmation');
      err.code = 'INVALID_PASSWORD';
      throw err;
    }

    if (homeRepo) {
      const memberships = await homeRepo.getMembershipsForUser(userId);
      for (const m of memberships) {
        if (m.role === 'OWNER') {
          const homeMembers = await homeRepo.getMembershipsForHome(m.home_id);
          const otherMembers = homeMembers.filter(hm => hm.user_id !== userId);
          if (otherMembers.length > 0) {
            throw new Error(`Cannot delete account: you are the sole owner of home with other members. Please transfer ownership or remove home first.`);
          }
          await homeRepo.deleteHome(m.home_id);
        } else {
          await homeRepo.removeMembership(m.home_id, userId);
        }
      }
    }

    await this.userRepo.deleteUser(userId);
    return { success: true, message: 'Account deleted successfully' };
  }
}

module.exports = { AuthService };
