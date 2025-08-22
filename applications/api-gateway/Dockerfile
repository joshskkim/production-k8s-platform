# Multi-stage build for Go API Gateway
# Optimized for production with minimal attack surface

# Build stage
FROM golang:1.21-alpine AS builder

# Install security updates and build dependencies
RUN apk update && apk add --no-cache \
    git \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Create non-root user for build
RUN adduser -D -g '' appuser

# Set working directory
WORKDIR /build

# Copy go.mod first for better caching
COPY go.mod ./

# Copy go.sum if it exists, otherwise create empty file
COPY go.su[m] ./

# Download dependencies (this will generate go.sum if it doesn't exist)
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o api-gateway .

# Production stage
FROM scratch

# Import CA certificates from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Import user/group files
COPY --from=builder /etc/passwd /etc/passwd

# Copy the binary
COPY --from=builder /build/api-gateway /api-gateway

# Use non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/api-gateway", "-health-check"]

# Run the binary
ENTRYPOINT ["/api-gateway"]