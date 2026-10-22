# ==============================================================================
# Stage 1: Dependency Builder
# ==============================================================================
FROM node:20-alpine AS builder

WORKDIR /app

# Install security updates
RUN apk update && apk upgrade --no-cache

# Copy package descriptors
COPY package*.json ./

# Install production dependencies only
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

# ==============================================================================
# Stage 2: Production Minimal Runtime
# ==============================================================================
FROM node:20-alpine AS runner

WORKDIR /app

# Ensure security updates in runtime container
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache wget

# Set environment
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0

# Copy node_modules from builder
COPY --from=builder --chown=node:node /app/node_modules ./node_modules

# Copy application source code
COPY --chown=node:node package.json ./
COPY --chown=node:node src/ ./src/

# Run as non-privileged user (Principle of Least Privilege)
USER node

# Expose internal container port
EXPOSE 3000

# Container Healthcheck (polled every 30s by Docker)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/health || exit 1

# Start the application
CMD ["node", "src/index.js"]
