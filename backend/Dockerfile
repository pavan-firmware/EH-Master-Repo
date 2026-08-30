# ==============================================================================
# EH Home — Backend Production Dockerfile (Phase 13)
# ==============================================================================

# 1. Base Stage
FROM node:22-alpine AS base
WORKDIR /app
RUN apk add --no-cache dumb-init

# 2. Dependencies Stage
FROM base AS dependencies
COPY package*.json ./
RUN npm ci --only=production

# 3. Production Runtime Stage
FROM base AS release
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

# Run as non-privileged node user
USER node

COPY --chown=node:node --from=dependencies /app/node_modules ./node_modules
COPY --chown=node:node package*.json ./
COPY --chown=node:node src/ ./src/
COPY --chown=node:node migrations/ ./migrations/

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:3000/api/v1/health/liveness', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/server.js"]
