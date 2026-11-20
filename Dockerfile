# syntax=docker/dockerfile:1

# Override with --build-arg NODE_IMAGE=node:22-alpine@sha256:<digest> to pin the base image.
ARG NODE_IMAGE=node:26.13.0-alpine3.24@sha256:8996bb5821d62a8fd9bb27c1cb07462f3fdce6e47d640c6a881ead0b064ce216
FROM ${NODE_IMAGE}

LABEL org.opencontainers.image.title="HeaderGrade Docker"
LABEL org.opencontainers.image.description="Container image for the upstream HeaderGrade security-header scanner"
LABEL org.opencontainers.image.source="https://github.com/wydler/headergrade-docker"

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

# Keep dependency installation separate for better build-cache reuse.
COPY --chown=node:node upstream/headergrade/package.json \
     upstream/headergrade/package-lock.json ./

RUN npm ci --omit=dev --no-audit --no-fund \
    && npm cache clean --force

# Copy only files required at runtime. Keep this list in sync with upstream.
COPY --chown=node:node upstream/headergrade/server.js \
     upstream/headergrade/seed.json ./
COPY --chown=node:node upstream/headergrade/lib/ ./lib/
COPY --chown=node:node upstream/headergrade/public/ ./public/

# HeaderGrade writes its JSON scan history under /app/data.
RUN mkdir -p /app/data \
    && chown node:node /app/data \
    && test -f /app/server.js \
    && test -f /app/lib/guard.js \
    && test -d /app/public

USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["node", "-e", "fetch('http://127.0.0.1:3000/api/stats').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"]

CMD ["node", "server.js"]
