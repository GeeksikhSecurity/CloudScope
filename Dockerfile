# Multi-stage Dockerfile for CloudScope
# Requirements: 2.1, 2.3, 2.4

# Stage 1: Builder
FROM python:3.11-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy requirements first for better caching
COPY requirements.txt .
COPY requirements-dev.txt .

# Create virtual environment and install dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --upgrade pip setuptools wheel
RUN pip install -r requirements.txt

# Copy source code
COPY . .

# Build the package
RUN pip install -e .

# Stage 2: Runtime
FROM python:3.11-slim

# Security: Create non-root user
RUN useradd -r -s /bin/false -u 1000 cloudscope && \
    mkdir -p /app /data /logs /config /plugins && \
    chown -R cloudscope:cloudscope /app /data /logs /config /plugins

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application
WORKDIR /app
COPY --from=builder /build/src ./src
COPY --from=builder /build/scripts ./scripts
COPY --from=builder /build/config ./config
COPY --from=builder /build/README.md ./

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV CLOUDSCOPE_DATA_DIR=/data
ENV CLOUDSCOPE_LOG_DIR=/logs
ENV CLOUDSCOPE_CONFIG_DIR=/config
ENV CLOUDSCOPE_PLUGIN_DIR=/plugins

# Switch to non-root user
USER cloudscope

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD cloudscope health --format json || exit 1

# Expose metrics port
EXPOSE 8080

# Default command
CMD ["cloudscope", "--config", "/config/cloudscope-config.json", "serve"]
