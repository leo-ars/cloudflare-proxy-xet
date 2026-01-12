# proxy-xet

**Built by [@leo-ars](https://github.com/leo-ars)** based on [@jedisct1](https://github.com/jedisct1)'s [zig-xet](https://github.com/jedisct1/zig-xet)

[![Deploy to Cloudflare](https://img.shields.io/badge/Deploy-Cloudflare%20Workers-orange)](CLOUDFLARE.md)
[![Docker](https://img.shields.io/badge/Docker-Multi--platform-blue)](DOCKER.md)
[![XET Protocol](https://img.shields.io/badge/XET-Protocol%20Compliant-green)](https://jedisct1.github.io/draft-denis-xet/draft-denis-xet.html)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

<p align="center">
  <img src=".media/logo.jpg" />
</p>

A production-ready HTTP proxy server for the XET protocol, enabling efficient streaming downloads of large ML models from HuggingFace. Deploy globally to Cloudflare's edge network or self-host with Docker.

## Overview

This project combines Zig's XET protocol implementation with a high-performance Rust HTTP server to provide a scalable proxy for downloading models and datasets. Files are streamed directly to clients without buffering, making it ideal for serving large models in production environments.

**Key Features:**
- 🌍 **Global edge deployment** via Cloudflare Workers Containers
- 🚀 **Streaming downloads** (no disk buffering)
- 📈 **Automatic scaling** with pay-per-use pricing
- ⚡ **Fast performance** (~35-45 MB/s)
- 🔄 **Multi-platform** Docker support (AMD64, ARM64)
- 🔒 **Secure** authentication via Bearer tokens
- 📦 **Small footprint** (10-40 MB Docker images)

## Deployment Options

| Feature | Cloudflare Workers | Docker Self-Hosted |
|---------|-------------------|-------------------|
| **Setup Time** | 5 minutes | 15-30 minutes |
| **Global CDN** | ✅ 300+ cities | ❌ Single location |
| **Auto-scaling** | ✅ Automatic | ❌ Manual |
| **Monitoring** | ✅ Built-in dashboard | ⚙️ Setup required |
| **Maintenance** | ✅ Zero | ❌ Manual updates |
| **Cost** | 💰 Pay-per-use (~$5-15/mo) | 💰 Fixed server cost |
| **Cold starts** | ⚡ 2-3 seconds | ✅ None (if 24/7) |
| **Best for** | Variable traffic, global users | Steady traffic, specific region |

## Quick Start

### Cloudflare Workers Containers (Recommended for Production)

Deploy to Cloudflare's global edge network in 3 commands:

```bash
npm install           # Install dependencies
npm run cf:login      # Authenticate with Cloudflare
npm run cf:deploy     # Deploy globally (takes 5-10 min first time)
```

Your proxy will be live at: `https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev`

**Test your deployment:**
```bash
# Health check (no auth needed)
curl https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev/health

# Download a file
curl https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev/download/jedisct1/MiMo-7B-RL-GGUF/model.gguf \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.gguf

# Or use the test script
./test-cloudflare.sh https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev hf_your_token
```

📚 **See [CLOUDFLARE.md](CLOUDFLARE.md) for complete guide** including cost estimates, scaling, and troubleshooting.

### Docker (Self-Hosted)

```bash
# Build for AMD64 (servers)
docker buildx build \
  --platform linux/amd64 \
  --file Dockerfile.proxy \
  --tag xet-proxy:latest \
  --load \
  .

# Run the proxy
docker run -p 8080:8080 xet-proxy:latest

# Test it (health check doesn't need auth)
curl http://localhost:8080/health

# Download with Bearer token
curl http://localhost:8080/download/owner/repo/file \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o file.bin
```

### Local Development

```bash
# Build Zig CLI
zig build -Doptimize=ReleaseFast

# Build Rust proxy
cd proxy-rust && cargo build --release

# Run
export ZIG_BIN_PATH=./zig-out/bin/xet-download
./proxy-rust/target/release/xet-proxy

# All requests require Bearer token in Authorization header
```

## Authentication

All download requests require authentication via Bearer token in the `Authorization` header:

```bash
curl http://localhost:8080/download/owner/repo/file \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o file.bin
```

This clean approach allows:
- **Multi-tenant support**: Different users provide their own tokens per request
- **Security**: No server-wide token that could be compromised
- **Flexibility**: Each request can use a different token if needed

## Features

### 🌍 Global Edge Deployment
Deploy to Cloudflare's network of 300+ cities worldwide. Your proxy automatically runs near your users for minimal latency.

### 🔐 Secure Multi-Tenant Authentication
Bearer token authentication allows multiple users to share the same proxy while using their own HuggingFace credentials. No server-side token storage.

### ⚡ High-Performance Streaming
Files stream directly from HuggingFace through the proxy to clients without disk buffering. Tested at 35-45 MB/s with low memory usage (200-500 MB).

### 📈 Automatic Scaling (Cloudflare)
Pay only for what you use. Containers automatically sleep when idle and wake up on-demand. Manual scaling for Docker deployments.

### 🔄 XET Protocol Compliance
Full implementation of the XET protocol with content-defined chunking, BLAKE3 hashing, LZ4 compression, and deduplication. Cross-verified with the Rust reference implementation.

### 📦 Minimal Footprint
- Cloudflare: ~10 MB container image
- Docker AMD64: ~10 MB
- Docker ARM64: ~36 MB

## API Endpoints

### GET /health
Health check (no authentication required)
```bash
curl http://localhost:8080/health
# Response: {"status":"ok","version":"0.1.0"}
```

### GET /download/:owner/:repo/*file
Download file by repository path
```bash
curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/model.gguf \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.gguf
```

### GET /download-hash/:hash
Download file directly by XET hash (faster)
```bash
curl http://localhost:8080/download-hash/ef62b7509a2c...5bd \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.safetensors
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Docker Container                                    │
│                                                     │
│  ┌──────────────────────┐     ┌──────────────────┐ │
│  │ Rust HTTP Server     │────▶│ Zig XET CLI      │ │
│  │ (Axum framework)     │     │ (Protocol impl)  │ │
│  └──────────────────────┘     └──────────────────┘ │
│          │                              │           │
└──────────┼──────────────────────────────┼───────────┘
           │                              │
           ▼                              ▼
      HTTP Client                  HuggingFace API
```

The Rust server handles HTTP routing and client connections, spawning the Zig CLI to process XET protocol operations. Files stream directly from HuggingFace through the pipeline to the client.

## Multi-Platform Docker Builds

Build for different architectures:

```bash
# AMD64 (x86_64) - for most servers
docker buildx build --platform linux/amd64 -f Dockerfile.proxy -t xet-proxy:amd64 --load .

# ARM64 (Apple Silicon, ARM servers)
docker buildx build --platform linux/arm64 -f Dockerfile.proxy -t xet-proxy:arm64 --load .
```

**Image sizes:**
- AMD64: ~10 MB
- ARM64: ~36 MB

## Deployment

### Cloudflare Workers Containers (Recommended for Production)

Deploy globally with automatic scaling using Cloudflare's edge network:

```bash
# Install dependencies
npm install

# Login to Cloudflare
npm run cf:login

# Deploy to Cloudflare
npm run cf:deploy
```

Your proxy will be available at: `https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev`

**Benefits:**
- 🌍 Global distribution across 300+ cities
- 📈 Automatic scaling and load balancing (coming soon)
- 💰 Pay only for active usage (includes free tier)
- 📊 Built-in monitoring and logs
- 🔒 DDoS protection and security

See [CLOUDFLARE.md](CLOUDFLARE.md) for comprehensive deployment guide.

**Quick commands:**
```bash
npm run cf:dev         # Local development
npm run cf:deploy      # Deploy to production
npm run cf:tail        # Live tail logs
npm run cf:status      # Check container status
```

### Docker Self-Hosted

#### Push to Private Registry
```bash
docker tag xet-proxy:latest registry.example.com/xet-proxy:latest
docker push registry.example.com/xet-proxy:latest
```

#### Export for Airgapped Systems
```bash
docker save xet-proxy:latest -o xet-proxy.tar
# Transfer xet-proxy.tar to target system
docker load -i xet-proxy.tar
```

## Performance

Tested with 7.73GB model download on MacBook Pro M2 (Orange España domestic network):
- **Speed:** 35-45 MB/s average
- **Memory:** 200-500 MB
- **Time:** ~3-4 minutes for 7.5GB file

*Performance may vary depending on network connection and HuggingFace CDN location.*

## Development

### Requirements
- Zig 0.16 or newer
- Rust 1.83 or newer
- Docker with buildx (for multi-platform builds)

### Build from Source
```bash
# Build everything
zig build -Doptimize=ReleaseFast
cd proxy-rust && cargo build --release

# Run tests
zig build test  # 106 Zig tests
cd proxy-rust && cargo test  # Rust tests
```

### Project Structure
```
.
├── src/              # Zig XET protocol implementation
├── proxy-rust/       # Rust HTTP server (Axum)
├── examples/         # Usage examples
├── Dockerfile.proxy  # Multi-stage Docker build
└── scripts/          # Utility scripts
```

## XET Protocol

This implementation follows the official [XET Protocol Specification](https://jedisct1.github.io/draft-denis-xet/draft-denis-xet.html), featuring:

- **Content-defined chunking** using Gearhash (8KB-128KB chunks)
- **BLAKE3 hashing** with Merkle tree construction
- **LZ4 compression** with byte grouping optimization
- **Deduplication** via content-addressable storage
- **Parallel fetching** with thread pools

The Zig implementation is cross-verified against the reference implementation to ensure byte-for-byte compatibility.

## Documentation

### Deployment Guides
- 🌟 [CLOUDFLARE.md](CLOUDFLARE.md) - **Cloudflare Workers Containers** (recommended for production)
  - Complete deployment guide with examples
  - Cost estimation ($5-15/mo typical)
  - Scaling and monitoring
  - Troubleshooting
- 🐳 [DOCKER.md](DOCKER.md) - **Docker self-hosted** deployment
  - Multi-platform builds (AMD64, ARM64)
  - Private registry deployment
  - Production configurations

### Quick References
- ⚡ [QUICKSTART.md](QUICKSTART.md) - One-page cheat sheet
- 💻 [CURL_EXAMPLES.md](CURL_EXAMPLES.md) - Command-line examples
- 📦 [worker/README.md](worker/README.md) - Cloudflare Worker code reference
- 🤖 [AGENTS.md](AGENTS.md) - Developer guide for AI coding agents

## Credits

This project is based on the original [zig-xet](https://github.com/jedisct1/zig-xet) implementation by [@jedisct1](https://github.com/jedisct1), which provides the core XET protocol implementation in Zig. This fork adds a production-ready HTTP proxy server and enhanced Docker deployment capabilities.

**Original XET Protocol:**
- Specification: [@jedisct1](https://github.com/jedisct1)
- Rust reference implementation: XET Labs

## License

Same as the original zig-xet project.

## Contributing

Contributions welcome! Please ensure:
- All Zig tests pass (`zig build test`)
- Code follows the existing style
- Docker builds succeed for both AMD64 and ARM64

## Getting a HuggingFace Token

1. Visit https://huggingface.co/settings/tokens
2. Create a token with "Read access to contents of all public gated repos"
3. Set as environment variable: `export HF_TOKEN=your_token`
