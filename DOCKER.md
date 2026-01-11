# Docker Deployment Guide

This guide explains how to run the XET Proxy Server in Docker.

## Overview

The XET Proxy Server provides an HTTP API to download files from HuggingFace using the XET protocol. It streams files as they are reconstructed, avoiding buffering entire files in memory.

**Key Features:**
- Streaming downloads (no disk buffering)
- Multi-platform support (AMD64, ARM64)
- Bearer token authentication
- Small footprint (~10-40 MB)

## Quick Start

### Build Docker Image

```bash
# Build for AMD64 (servers)
docker buildx build \
  --platform linux/amd64 \
  --file Dockerfile.proxy \
  --tag xet-proxy:latest \
  --load \
  .

# Or build for ARM64 (Apple Silicon)
docker buildx build \
  --platform linux/arm64 \
  --file Dockerfile.proxy \
  --tag xet-proxy:latest \
  --load \
  .
```

### Run the Server

```bash
# Run the proxy
docker run -d -p 8080:8080 --name xet-proxy xet-proxy:latest

# Test
curl http://localhost:8080/health
```

### Using Docker Compose

```bash
# Build and run
docker-compose -f docker-compose.proxy.yml up -d

# Test
curl http://localhost:8080/health

# Stop
docker-compose -f docker-compose.proxy.yml down
```

## API Endpoints

### `GET /health`

Health check endpoint (no authentication required).

```bash
curl http://localhost:8080/health
# Response: {"status":"ok","version":"0.1.0"}
```

### `GET /download/:owner/:repo/*file`

Download a file by repository path (requires Bearer token).

```bash
curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/model.gguf \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.gguf
```

### `GET /download-hash/:hash`

Download a file directly by XET hash (requires Bearer token).

```bash
curl http://localhost:8080/download-hash/89dbfa4888600b29be17ddee8bdbf9c48999c81cb811964eee6b057d8467f927 \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.safetensors
```

### `GET /`

Returns HTML usage instructions. Visit http://localhost:8080/ in a browser.

## Authentication

All download requests require Bearer token authentication:

```bash
curl http://localhost:8080/download/owner/repo/file \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o file.bin
```

**Benefits:**
- Multi-tenant support (different users, different tokens)
- No server-wide token that could leak
- Per-request authentication and authorization

## Multi-Platform Builds

### AMD64 (x86_64) - For Most Servers

```bash
docker buildx build \
  --platform linux/amd64 \
  --file Dockerfile.proxy \
  --tag xet-proxy:amd64 \
  --load \
  .
```

**Image size:** ~10 MB

### ARM64 (Apple Silicon, ARM servers)

```bash
docker buildx build \
  --platform linux/arm64 \
  --file Dockerfile.proxy \
  --tag xet-proxy:arm64 \
  --load \
  .
```

**Image size:** ~36 MB

### Multi-Architecture Image

```bash
# Build for both platforms (requires pushing to registry)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --file Dockerfile.proxy \
  --tag registry.example.com/xet-proxy:latest \
  --push \
  .
```

## Deployment

### Push to Private Registry

```bash
# Tag for your registry
docker tag xet-proxy:latest registry.example.com/xet-proxy:latest

# Push
docker push registry.example.com/xet-proxy:latest
```

### Export for Airgapped Systems

```bash
# Save image to tar file
docker save xet-proxy:latest -o xet-proxy.tar

# Transfer to target system, then:
docker load -i xet-proxy.tar
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | 8080 | HTTP server port |
| `ZIG_BIN_PATH` | No | /usr/local/bin/xet-download | Path to Zig CLI binary |

**Note:** `HF_TOKEN` is no longer required as environment variable. Use Bearer tokens in request headers instead.

### Example with Custom Port

```bash
docker run -d -p 9000:9000 -e PORT=9000 xet-proxy:latest
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs xet-proxy

# Check if port is already in use
lsof -i :8080
```

### Downloads Fail

```bash
# Verify Bearer token is provided
curl -i http://localhost:8080/download/owner/repo/file \
  -H "Authorization: Bearer hf_token"

# Should see HTTP 200, not 401 Unauthorized

# Check container logs for errors
docker logs -f xet-proxy
```

### Permission Denied Errors

The container runs as non-root user (UID 1000). Ensure any mounted volumes have appropriate permissions.

### Check Container Health

```bash
# View health status
docker inspect xet-proxy | grep -A 10 Health

# Manual health check
docker exec xet-proxy wget -qO- http://localhost:8080/health
```

## Performance

Tested with 7.73GB model download:
- **Speed:** 35-45 MB/s average
- **Memory:** 200-500 MB
- **CPU:** 1-2 cores
- **Time:** ~3-4 minutes for 7.5GB file

## Security

- ✅ Runs as non-root user (UID 1000)
- ✅ No tokens stored server-side
- ✅ Bearer token authentication per-request
- ✅ Input validation on all endpoints
- ✅ Health checks with minimal permissions
- ✅ Alpine Linux base (minimal attack surface)

## Docker Compose

Example `docker-compose.proxy.yml`:

```yaml
services:
  xet-proxy:
    build:
      context: .
      dockerfile: Dockerfile.proxy
    container_name: xet-proxy
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - ZIG_BIN_PATH=/usr/local/bin/xet-download
      - RUST_LOG=info
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s
```

## Advanced Usage

### Resource Limits

```bash
docker run -d \
  -p 8080:8080 \
  --memory="1g" \
  --cpus="2" \
  --name xet-proxy \
  xet-proxy:latest
```

### Custom Logging

```bash
docker run -d \
  -p 8080:8080 \
  -e RUST_LOG=debug \
  --name xet-proxy \
  xet-proxy:latest
```

### Multiple Instances (Load Balancing)

```bash
# Start multiple instances on different ports
docker run -d -p 8081:8080 --name xet-proxy-1 xet-proxy:latest
docker run -d -p 8082:8080 --name xet-proxy-2 xet-proxy:latest
docker run -d -p 8083:8080 --name xet-proxy-3 xet-proxy:latest

# Use nginx or another load balancer to distribute traffic
```

## Monitoring

### Prometheus Metrics

The proxy doesn't currently expose Prometheus metrics, but you can monitor via:

```bash
# Container stats
docker stats xet-proxy

# Logs
docker logs -f xet-proxy

# Health check endpoint
watch -n 5 'curl -s http://localhost:8080/health'
```

## Support

For issues and questions:
- GitHub Issues: https://github.com/leo-ars/proxy-xet/issues
- XET Protocol Spec: https://jedisct1.github.io/draft-denis-xet/draft-denis-xet.html
