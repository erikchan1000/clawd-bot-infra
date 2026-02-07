# =============================================================================
# OpenClaw Docker Image with Chrome/Playwright
# =============================================================================
# Production Dockerfile for OpenClaw Gateway with browser automation support.
# Bakes in required binaries for skills + Chrome + Playwright dependencies.
#
# Build: docker build -t openclaw:latest .
# =============================================================================

FROM node:22-bookworm

# Set environment
ENV NODE_ENV=production
ENV TERM=xterm-256color
ENV PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright

# Install system dependencies + Chrome dependencies
RUN apt-get update && apt-get install -y \
    socat \
    curl \
    git \
    ca-certificates \
    gnupg \
    python3 \
    python3-pip \
    # Chrome dependencies
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xvfb \
    fonts-noto-color-emoji \
    fonts-unifont \
    libfontconfig1 \
    libfreetype6 \
    xfonts-scalable \
    fonts-liberation \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-tlwg-loma-otf \
    fonts-freefont-ttf \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Install Playwright and Chromium
# ---------------------------------------------------------------------------

RUN pip3 install playwright --break-system-packages \
    && playwright install chromium

# ---------------------------------------------------------------------------
# Install External Binaries for Skills
# ---------------------------------------------------------------------------
# These binaries are required by various OpenClaw skills.
# Add more as needed for your use case.

# Gmail CLI (gog) - for Gmail integration
RUN curl -L https://github.com/steipete/gog/releases/latest/download/gog_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/gog

# Google Places CLI (goplaces) - for location skills
RUN curl -L https://github.com/steipete/goplaces/releases/latest/download/goplaces_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/goplaces

# WhatsApp CLI (wacli) - for WhatsApp integration
RUN curl -L https://github.com/steipete/wacli/releases/latest/download/wacli_Linux_x86_64.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/wacli

# ---------------------------------------------------------------------------
# Create non-root user
# ---------------------------------------------------------------------------

RUN groupadd -g 1000 node || true \
    && useradd -u 1000 -g node -m -s /bin/bash node || true

# ---------------------------------------------------------------------------
# Install OpenClaw
# ---------------------------------------------------------------------------

WORKDIR /app

# Copy package files first for better caching
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY scripts ./scripts

# Enable corepack and install dependencies
RUN corepack enable
RUN pnpm install --frozen-lockfile

# Copy application source
COPY . .

# Build the application
RUN pnpm build

# Build the UI
RUN pnpm ui:install
RUN pnpm ui:build

# ---------------------------------------------------------------------------
# Configure runtime
# ---------------------------------------------------------------------------

# Create directories for state
RUN mkdir -p /home/node/.openclaw \
    && mkdir -p /home/node/.openclaw/workspace \
    && mkdir -p /tmp/openclaw \
    && chown -R node:node /home/node \
    && chown -R node:node /tmp/openclaw \
    && chown -R node:node /app

# Switch to non-root user
USER node

# Set working directory
WORKDIR /app

# Expose the gateway port
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# Default command
CMD ["node", "dist/index.js", "gateway"]
