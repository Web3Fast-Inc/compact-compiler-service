FROM node:18-slim AS base

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Create non-root user
RUN groupadd -r compact && useradd -r -g compact compact

# Copy package files
COPY package*.json ./

# Install dependencies
FROM base AS dependencies
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM base AS production

# Copy production dependencies
COPY --from=dependencies /app/node_modules ./node_modules

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p temp logs && \
    chown -R compact:compact /app

# Install compactc binary (placeholder - will be mounted or downloaded)
# Note: In production, compactc should be available via volume mount
# or downloaded during container startup
RUN mkdir -p /usr/local/bin

# Switch to non-root user
USER compact

# Expose port
EXPOSE 3002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3002/ || exit 1

# Start the application
CMD ["npm", "start"] 