'use strict';

/**
 * EH Home — JWT Authentication Middleware (Phase 7A)
 *
 * Validates RS256 JWT access tokens supplied in the Authorization: Bearer header.
 * Attaches the authenticated user context to `req.user`.
 * Strictly rejects X-Actor-Context production authentication bypass.
 */

function requireAuthentication(authService) {
  return function authMiddleware(req, res, next) {
    if (req.user && req.user.id) {
      if (!req.actorContext) {
        req.actorContext = { userId: req.user.id, email: req.user.email, role: req.user.role };
      }
      return { success: true, user: req.user };
    }

    const authHeader = req.headers['authorization'] || req.headers['Authorization'];

    if (!authHeader || typeof authHeader !== 'string') {
      const errRes = {
        status: 401,
        body: {
          success: false,
          error: {
            code: 'UNAUTHORIZED',
            message: 'Authentication required: missing Authorization header'
          },
          timestamp: new Date().toISOString()
        }
      };
      if (res && typeof res.status === 'function') {
        return res.status(401).json(errRes.body);
      }
      return errRes;
    }

    const parts = authHeader.trim().split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer') {
      const errRes = {
        status: 401,
        body: {
          success: false,
          error: {
            code: 'UNAUTHORIZED',
            message: 'Invalid Authorization header format. Expected Bearer <token>'
          },
          timestamp: new Date().toISOString()
        }
      };
      if (res && typeof res.status === 'function') {
        return res.status(401).json(errRes.body);
      }
      return errRes;
    }

    const token = parts[1];

    try {
      const payload = authService.verifyAccessToken(token);
      req.user = {
        id: payload.sub,
        email: payload.email,
        role: payload.role || 'MEMBER',
        type: payload.type,
        iss: payload.iss,
        aud: payload.aud
      };
      // Keep actorContext backward compatibility for downstream code expecting actorContext.userId
      req.actorContext = {
        userId: payload.sub,
        email: payload.email,
        role: payload.role || 'MEMBER'
      };

      if (typeof next === 'function') {
        return next();
      }
      return { success: true, user: req.user };
    } catch (err) {
      const errRes = {
        status: 401,
        body: {
          success: false,
          error: {
            code: 'UNAUTHORIZED',
            message: `Authentication failed: ${err.message}`
          },
          timestamp: new Date().toISOString()
        }
      };
      if (res && typeof res.status === 'function') {
        return res.status(401).json(errRes.body);
      }
      return errRes;
    }
  };
}

module.exports = { requireAuthentication };
