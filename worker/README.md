# XET Proxy - Cloudflare Workers Container

This directory contains the Cloudflare Workers Container configuration for deploying the XET Proxy Server globally.

## Quick Start

### Prerequisites

- Node.js 18+ and npm
- Docker (for building container images)
- Cloudflare account with Workers Paid plan

### Deploy

```bash
# From this directory (worker/)
npm install
npx wrangler login
npx wrangler deploy
```

First deployment takes 5-10 minutes. Subsequent deploys are faster.

### Local Development

```bash
npx wrangler dev
```

This runs the Worker and Container locally using Docker.

**Rebuild container during dev**: Press `[r]` in the terminal.

## Configuration

Edit `wrangler.jsonc` to configure:

- **Instance type**: CPU, memory, disk allocation
- **Max instances**: Maximum concurrent containers
- **Rollout strategy**: Gradual or immediate updates

Edit `src/index.ts` to configure:

- **Port**: Container listening port (default: 8080)
- **Sleep timeout**: Idle timeout before sleep (default: 10m)
- **Environment variables**: Passed to container

## Endpoints

Once deployed, your Worker will be available at:
```
https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev
```

### Available Routes

- `GET /health` - Health check (no auth)
- `GET /download/:owner/:repo/*file` - Download by path
- `GET /download-hash/:hash` - Download by XET hash

All download endpoints require `Authorization: Bearer hf_xxx...` header.

## Testing

```bash
# Health check
curl https://your-worker.workers.dev/health

# Download a file
curl https://your-worker.workers.dev/download/jedisct1/MiMo-7B-RL-GGUF/MiMo-7B-RL-Q8_0.gguf \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.gguf
```

## Monitoring

View logs and metrics:

```bash
# Live tail logs
npx wrangler tail

# Check container status
npx wrangler containers list

# View images
npx wrangler containers images list
```

Or visit the [Cloudflare Dashboard](https://dash.cloudflare.com/) → Workers & Pages → Containers.

## Documentation

See [../CLOUDFLARE.md](../CLOUDFLARE.md) for comprehensive deployment guide including:

- Detailed configuration options
- Scaling strategies
- Cost estimation
- Troubleshooting
- Advanced topics

## Project Structure

```
worker/
├── src/
│   └── index.ts          # Worker entry point
├── wrangler.jsonc        # Cloudflare configuration
└── README.md             # This file

../Dockerfile.proxy       # Container image definition
```

## Support

- [Cloudflare Containers Docs](https://developers.cloudflare.com/containers/)
- [GitHub Issues](https://github.com/leo-ars/cloudflare-proxy-xet/issues)
- [Discord Community](https://discord.cloudflare.com)
