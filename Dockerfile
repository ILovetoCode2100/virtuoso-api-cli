# Build stage
FROM golang:1.24-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary with optimization flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -X main.version=$(date +%Y%m%d)-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')" \
    -o api-cli ./src/cmd

# Runtime stage
FROM alpine:latest

# Add metadata
LABEL maintainer="Your Team <team@example.com>"
LABEL description="Virtuoso CLI - API automation tool"
LABEL version="1.0"

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata && \
    update-ca-certificates

# Create non-root user with specific UID/GID
RUN addgroup -g 1000 apigroup && \
    adduser -D -G apigroup -u 1000 apiuser

# Create necessary directories
RUN mkdir -p /workspace /config /home/apiuser/.virtuoso && \
    chown -R apiuser:apigroup /workspace /config /home/apiuser/.virtuoso

# Copy binary from builder
COPY --from=builder /app/api-cli /usr/local/bin/api-cli

# Copy default config template
COPY --from=builder --chown=apiuser:apigroup /app/config /etc/api-cli/

# Set working directory to /workspace for user files
WORKDIR /workspace

# Switch to non-root user
USER apiuser

# Set environment variables
ENV VIRTUOSO_CONFIG_PATH=/config
ENV VIRTUOSO_OUTPUT_FORMAT=human

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD api-cli --version || exit 1

# Set entrypoint
ENTRYPOINT ["api-cli"]

# Default command (show help)
CMD ["--help"]
