# Multi-stage build for CloudScope API
FROM python:3.11-slim as builder

# Set build arguments
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0

# Add metadata labels
LABEL maintainer="CloudScope Community <community@cloudscope.io>" \
      org.opencontainers.image.title="CloudScope API" \
      org.opencontainers.image.description="Open Source Unified Asset Inventory API" \
      org.opencontainers.image.version=$VERSION \
      org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.source="https://github.com/GeeksikhSecurity/CloudScope" \
      org.opencontainers.image.url="https://cloudscope.io" \
      org.opencontainers.image.vendor="CloudScope Community" \
      org.opencontainers.image.licenses="Apache-2.0"

# Install system dependencies for building
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:3.11-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r cloudscope && useradd -r -g cloudscope cloudscope

# Create app directory and set ownership
WORKDIR /app
RUN chown cloudscope:cloudscope /app

# Copy Python packages from builder stage
COPY --from=builder /root/.local /home/cloudscope/.local

# Copy application code
COPY --chown=cloudscope:cloudscope . /app

# Create necessary directories
RUN mkdir -p /app/logs /app/exports /app/config && \
    chown -R cloudscope:cloudscope /app/logs /app/exports /app/config

# Set environment variables
ENV PATH=/home/cloudscope/.local/bin:$PATH \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    USER=cloudscope \
    HOME=/home/cloudscope

# Switch to non-root user
USER cloudscope

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# Start application
CMD ["uvicorn", "core.api.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
