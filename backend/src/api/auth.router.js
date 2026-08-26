'use strict';

/**
 * EH Home — Auth API Router (Phase 7A)
 *
 * Endpoints:
 *   POST   /api/v1/auth/register — Register new user account
 *   POST   /api/v1/auth/login    — Authenticate user and issue tokens
 *   POST   /api/v1/auth/refresh  — Rotate refresh token and issue new access token
 *   DELETE /api/v1/auth/logout   — Revoke refresh token and end session
 */

const { RateLimiter } = require('../shared/rate-limiter');

class AuthApiRouter {
  constructor({ authService, rateLimiter = null }) {
    this.authService = authService;
    this.rateLimiter = rateLimiter || new RateLimiter({ windowMs: 60000, maxRequests: 10 });
  }

  async handle(method, path, body = {}, headers = {}, remoteAddress = '127.0.0.1') {
    const clientKey = `${remoteAddress}:${path}`;

    try {
      // 1. POST /api/v1/auth/register
      if (method === 'POST' && path === '/api/v1/auth/register') {
        const limitCheck = this.rateLimiter.isRateLimited(clientKey);
        if (limitCheck.limited) {
          return {
            status: 429,
            body: {
              success: false,
              error: {
                code: 'TOO_MANY_REQUESTS',
                message: `Rate limit exceeded. Try again in ${limitCheck.retryAfterSeconds} seconds`
              },
              timestamp: new Date().toISOString()
            }
          };
        }

        const { email, password } = body;
        if (!email || !password) {
          return {
            status: 400,
            body: {
              success: false,
              error: { code: 'INVALID_INPUT', message: 'Email and password are required' },
              timestamp: new Date().toISOString()
            }
          };
        }

        try {
          const userProfile = await this.authService.register({ email, password });
          return {
            status: 201,
            body: {
              success: true,
              data: userProfile,
              timestamp: new Date().toISOString()
            }
          };
        } catch (err) {
          if (err.code === 'DUPLICATE_EMAIL') {
            return {
              status: 409,
              body: {
                success: false,
                error: { code: 'DUPLICATE_EMAIL', message: err.message },
                timestamp: new Date().toISOString()
              }
            };
          }
          return {
            status: 400,
            body: {
              success: false,
              error: { code: 'INVALID_INPUT', message: err.message },
              timestamp: new Date().toISOString()
            }
          };
        }
      }

      // 2. POST /api/v1/auth/login
      if (method === 'POST' && path === '/api/v1/auth/login') {
        const limitCheck = this.rateLimiter.isRateLimited(clientKey);
        if (limitCheck.limited) {
          return {
            status: 429,
            body: {
              success: false,
              error: {
                code: 'TOO_MANY_REQUESTS',
                message: `Rate limit exceeded. Try again in ${limitCheck.retryAfterSeconds} seconds`
              },
              timestamp: new Date().toISOString()
            }
          };
        }

        const { email, password } = body;
        if (!email || !password) {
          return {
            status: 400,
            body: {
              success: false,
              error: { code: 'INVALID_INPUT', message: 'Email and password are required' },
              timestamp: new Date().toISOString()
            }
          };
        }

        try {
          const tokenResponse = await this.authService.login({ email, password });
          return {
            status: 200,
            body: {
              success: true,
              data: tokenResponse,
              timestamp: new Date().toISOString()
            }
          };
        } catch (err) {
          if (err.code === 'INVALID_CREDENTIALS') {
            return {
              status: 401,
              body: {
                success: false,
                error: { code: 'INVALID_CREDENTIALS', message: 'Invalid email or password' },
                timestamp: new Date().toISOString()
              }
            };
          }
          return {
            status: 400,
            body: {
              success: false,
              error: { code: 'INVALID_INPUT', message: err.message },
              timestamp: new Date().toISOString()
            }
          };
        }
      }

      // 3. POST /api/v1/auth/refresh
      if (method === 'POST' && path === '/api/v1/auth/refresh') {
        const limitCheck = this.rateLimiter.isRateLimited(clientKey);
        if (limitCheck.limited) {
          return {
            status: 429,
            body: {
              success: false,
              error: {
                code: 'TOO_MANY_REQUESTS',
                message: `Rate limit exceeded. Try again in ${limitCheck.retryAfterSeconds} seconds`
              },
              timestamp: new Date().toISOString()
            }
          };
        }

        const { refreshToken } = body;
        if (!refreshToken) {
          return {
            status: 400,
            body: {
              success: false,
              error: { code: 'INVALID_INPUT', message: 'refreshToken is required' },
              timestamp: new Date().toISOString()
            }
          };
        }

        try {
          const tokenResponse = await this.authService.refresh({ refreshToken });
          return {
            status: 200,
            body: {
              success: true,
              data: tokenResponse,
              timestamp: new Date().toISOString()
            }
          };
        } catch (err) {
          return {
            status: 401,
            body: {
              success: false,
              error: { code: err.code || 'UNAUTHORIZED', message: err.message },
              timestamp: new Date().toISOString()
            }
          };
        }
      }

      // 4. DELETE /api/v1/auth/logout
      if ((method === 'DELETE' || method === 'POST') && path === '/api/v1/auth/logout') {
        const refreshToken = body.refreshToken || headers['x-refresh-token'];
        await this.authService.logout({ refreshToken });
        return {
          status: 200,
          body: {
            success: true,
            data: { message: 'Logged out successfully' },
            timestamp: new Date().toISOString()
          }
        };
      }

      return {
        status: 404,
        body: {
          success: false,
          error: { code: 'NOT_FOUND', message: `Route ${method} ${path} not found` },
          timestamp: new Date().toISOString()
        }
      };
    } catch (err) {
      return {
        status: 500,
        body: {
          success: false,
          error: { code: 'INTERNAL_ERROR', message: err.message },
          timestamp: new Date().toISOString()
        }
      };
    }
  }
}

module.exports = { AuthApiRouter };
