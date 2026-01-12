# Deploying XET Proxy to Cloudflare Workers Containers

This guide explains how to deploy the XET Proxy Server as a Cloudflare Workers Container, enabling global distribution and automatic scaling.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Testing](#testing)
- [Monitoring](#monitoring)
- [Scaling](#scaling)
- [Cost Estimation](#cost-estimation)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software

1. **Node.js and npm** (v18 or later)
   ```bash
   node --version  # Should be v18+
   npm --version
   ```

2. **Docker** (for building container images)
   - [Docker Desktop](https://docs.docker.com/desktop/) (recommended)
   - Or [Colima](https://github.com/abiosoft/colima) on macOS
   ```bash
   docker info  # Should succeed without errors
   ```

3. **Wrangler CLI** (installed via npm in this project)
   ```bash
   npm install  # Installs wrangler locally
   ```

### Cloudflare Account Requirements

1. **Cloudflare Account** with Workers Paid plan ($5/month)
   - Sign up at https://dash.cloudflare.com/sign-up
   - Upgrade to Workers Paid plan (required for Containers beta)

2. **Containers Beta Access**
   - Containers are currently in open beta
   - Available to all Workers Paid plan users
   - See https://developers.cloudflare.com/containers/beta-info/

3. **API Token** for Wrangler
   - Create an API token at https://dash.cloudflare.com/profile/api-tokens
   - Use the "Edit Cloudflare Workers" template
   - Or create a custom token with these permissions:
     - Account > Workers Scripts > Edit
     - Account > Workers R2 Storage > Edit (for container registry)
     - Account > Durable Objects > Edit

## Quick Start

### 1. Install Dependencies

From the project root directory:

```bash
npm install
```

### 2. Authenticate Wrangler

```bash
npx wrangler login
```

This will open a browser window to authenticate with Cloudflare.

Alternatively, set your API token as an environment variable:

```bash
export CLOUDFLARE_API_TOKEN=your_token_here
```

### 3. Deploy to Cloudflare

Navigate to the worker directory and deploy:

```bash
cd worker
npx wrangler deploy
```

**First deployment takes 5-10 minutes** because:
- Docker builds the container image (multi-stage build with Zig + Rust)
- Wrangler pushes the image to Cloudflare's registry
- Cloudflare distributes the image globally across its network

**Subsequent deploys are much faster** (~1-2 minutes) thanks to Docker layer caching.

### 4. Get Your Worker URL

After deployment, Wrangler will output your Worker URL:

```
Published xet-proxy-container (0.01 sec)
  https://xet-proxy-container.your-subdomain.workers.dev
```

### 5. Test the Deployment

```bash
# Health check (no auth required)
curl https://xet-proxy-container.your-subdomain.workers.dev/health

# Download a file (requires HuggingFace token)
curl https://xet-proxy-container.your-subdomain.workers.dev/download/jedisct1/MiMo-7B-RL-GGUF/MiMo-7B-RL-Q8_0.gguf \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.gguf
```

## Configuration

### Worker Configuration (`worker/wrangler.jsonc`)

Key configuration options:

```jsonc
{
  "containers": [
    {
      // Instance type - determines CPU, memory, and disk
      "instance_type": "standard-1",  // 0.5 vCPU, 4GB RAM, 8GB disk
      
      // Maximum concurrent instances
      "max_instances": 10,
      
      // Gradual rollout: 10% first, then 100%
      "rollout_step_percentage": [10, 100],
      
      // Wait 5 minutes before updating active containers
      "rollout_active_grace_period": 300
    }
  ]
}
```

#### Instance Types

Choose based on your workload:

| Instance Type | vCPU | Memory | Disk | Use Case |
|--------------|------|--------|------|----------|
| `lite` | 1/16 | 256 MB | 2 GB | Testing, light workloads |
| `basic` | 1/4 | 1 GB | 4 GB | Small files, low concurrency |
| `standard-1` | 1/2 | 4 GB | 8 GB | **Recommended** for XET Proxy |
| `standard-2` | 1 | 6 GB | 12 GB | High concurrency, large files |
| `standard-3` | 2 | 8 GB | 16 GB | Very high load |
| `standard-4` | 4 | 12 GB | 20 GB | Maximum performance |

### Container Configuration (`worker/src/index.ts`)

```typescript
export class XetProxyContainer extends Container<Env> {
  defaultPort = 8080;           // Rust proxy port
  sleepAfter = "10m";           // Sleep after 10min idle
  enableInternet = true;        // Required for HuggingFace
}
```

### Environment Variables

#### Option 1: Worker-level (via wrangler.jsonc)

Uncomment in `worker/wrangler.jsonc`:

```jsonc
{
  "vars": {
    "HF_TOKEN": "hf_your_token_here"
  }
}
```

**⚠️ Warning**: This embeds the token in your Worker code. Better for development.

#### Option 2: Cloudflare Secrets (Recommended for Production)

```bash
cd worker
npx wrangler secret put HF_TOKEN
# Enter your HuggingFace token when prompted
```

Access in Worker:
```typescript
envVars = {
  HF_TOKEN: this.env.HF_TOKEN
}
```

#### Option 3: Per-Request Authorization Header (Most Flexible)

Clients pass the token in each request:

```bash
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  https://your-worker.workers.dev/download/...
```

This is already implemented in the Rust proxy server and works without any additional configuration.

## Deployment

### Development Deployment

For testing with live reloading:

```bash
cd worker
npx wrangler dev
```

This runs the Worker and Container locally using Docker. Changes to Worker code auto-reload.

**Note**: To rebuild the container image during `wrangler dev`, press `[r]` in the terminal.

### Production Deployment

```bash
cd worker
npx wrangler deploy
```

#### Deployment Options

**Standard deployment** (gradual rollout):
```bash
npx wrangler deploy
```

**Immediate rollout** (update all instances at once):
```bash
npx wrangler deploy --containers-rollout=immediate
```

**Check deployment status**:
```bash
npx wrangler containers list
```

### Rollouts and Updates

Cloudflare uses **rolling deployments** for containers:

1. **Worker code updates immediately**
2. **Container instances update gradually**:
   - First: 10% of instances (default)
   - Wait for health checks
   - Then: Remaining 90%

This ensures zero-downtime deployments.

**Grace period**: Containers receive `SIGTERM` and have 15 minutes to shut down gracefully before `SIGKILL`.

## Testing

### Health Check

```bash
curl https://your-worker.workers.dev/health
```

Expected response:
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

### Download by Repository Path

```bash
curl https://your-worker.workers.dev/download/jedisct1/MiMo-7B-RL-GGUF/MiMo-7B-RL-Q8_0.gguf \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.gguf
```

### Download by XET Hash

```bash
curl https://your-worker.workers.dev/download-hash/89dbfa4888600b29be17ddee8bdbf9c48999c81cb811964eee6b057d8467f927 \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.safetensors
```

### Load Testing

Test with [k6](https://k6.io/):

```javascript
// load-test.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp up to 10 users
    { duration: '1m', target: 10 },   // Stay at 10 users
    { duration: '30s', target: 0 },   // Ramp down
  ],
};

export default function () {
  const res = http.get('https://your-worker.workers.dev/health');
  check(res, { 'status is 200': (r) => r.status === 200 });
}
```

Run:
```bash
k6 run load-test.js
```

## Monitoring

### Cloudflare Dashboard

View logs, metrics, and container status:

1. Go to https://dash.cloudflare.com/
2. Navigate to **Workers & Pages** → **Containers**
3. Select your container

Available metrics:
- **Requests per second**
- **Container instances** (active, sleeping, starting)
- **CPU, Memory, Disk usage**
- **Network egress**
- **Error rates**

### Live Log Tailing

```bash
cd worker
npx wrangler tail
```

Shows real-time logs from both Worker and Container.

### Enable Observability

Already enabled in `wrangler.jsonc`:

```jsonc
{
  "observability": {
    "enabled": true
  }
}
```

**Logs retention**:
- Free plan: 3 days
- Paid plan: 7 days

**Enterprise users** can export logs via [Logpush](https://developers.cloudflare.com/logs/logpush/).

## Scaling

### Automatic Scaling

Cloudflare **does not yet** provide automatic scaling for Containers.

You must manually scale by setting `max_instances`:

```jsonc
{
  "containers": [
    {
      "max_instances": 10  // Increase as needed
    }
  ]
}
```

Each request is routed to a single container instance. If you need load balancing across multiple instances, implement it in the Worker using `getRandom()` or custom logic.

### Manual Scaling Example

If you want to run 5 stateless instances with load balancing:

```typescript
import { getRandom } from "@cloudflare/containers";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Route to one of 5 instances randomly
    const container = await getRandom(env.XET_PROXY, 5);
    return container.fetch(request);
  }
}
```

⚠️ **Note**: `getRandom()` is a temporary helper. Cloudflare is working on native autoscaling and latency-aware routing.

### Future: Autoscaling (Coming Soon)

Cloudflare is planning:
- **Automatic instance scaling** based on load
- **Latency-aware routing** to nearest container
- **Resource-based scaling** (CPU, memory triggers)

See [Scaling Documentation](https://developers.cloudflare.com/containers/platform-details/scaling-and-routing/).

## Cost Estimation

### Pricing Components

Containers billing is based on **active usage only**:

| Resource | Included (Paid Plan) | Overage Cost |
|----------|---------------------|--------------|
| **CPU** | 375 vCPU-minutes/month | $0.000020 per vCPU-second |
| **Memory** | 25 GiB-hours/month | $0.0000025 per GiB-second |
| **Disk** | 200 GB-hours/month | $0.00000007 per GB-second |
| **Egress** | 1 TB/month (NA/EU) | $0.025 per GB |

**Workers Paid plan**: $5/month (required for Containers)

### Example Costs

#### Low Usage (Testing)
- Instance type: `standard-1` (0.5 vCPU, 4GB RAM, 8GB disk)
- Usage: 10 hours/month active
- Egress: 10 GB

**Cost**:
- CPU: (0.5 vCPU × 10 hours × 3600s) × $0.000020 = $0.36
- Memory: (4 GiB × 10 hours) - 25 free = 15 GiB-hours × $0.0000025 × 3600 = $0.14
- Disk: (8 GB × 10 hours) - 200 free = **FREE**
- Egress: 10 GB - 1000 free = **FREE**

**Total**: $5 (plan) + $0.50 ≈ **$5.50/month**

#### Medium Usage (Production)
- Instance type: `standard-2` (1 vCPU, 6GB RAM, 12GB disk)
- Usage: 100 hours/month active
- Egress: 500 GB

**Cost**:
- CPU: (1 vCPU × 100 hours × 3600s - 375 free minutes × 60) / 60 × $0.000020 × 60 = $4.05
- Memory: (6 GiB × 100 hours - 25 free) × $0.0000025 × 3600 = $5.21
- Disk: (12 GB × 100 hours - 200 free) × $0.00000007 × 3600 = $0.29
- Egress: 500 GB - 1000 free = **FREE**

**Total**: $5 (plan) + $9.55 ≈ **$15/month**

#### High Usage (Heavy Production)
- Instance type: `standard-3` (2 vCPU, 8GB RAM, 16GB disk)
- 3 instances running 24/7
- Egress: 5 TB/month

**Cost**:
- CPU: (2 vCPU × 3 instances × 720 hours × 3600s) × $0.000020 = $311.04
- Memory: (8 GiB × 3 instances × 720 hours) × $0.0000025 × 3600 = $155.52
- Disk: (16 GB × 3 instances × 720 hours) × $0.00000007 × 3600 = $8.71
- Egress: (5000 GB - 1000 free) × $0.025 = $100

**Total**: $5 (plan) + $575 ≈ **$580/month**

### Cost Optimization Tips

1. **Use `sleepAfter`**: Containers sleep when idle, saving costs
   ```typescript
   sleepAfter = "10m"  // Sleep after 10 minutes of inactivity
   ```

2. **Right-size instances**: Start with `standard-1`, scale up if needed

3. **Monitor usage**: Check dashboard regularly to avoid surprises

4. **Egress optimization**: Cache responses in Workers KV or R2 if possible

5. **Regional placement**: Use Smart Placement to reduce cross-region traffic (coming soon)

## Troubleshooting

### Container won't start

**Symptom**: Requests timeout or return 500 errors

**Check**:
```bash
npx wrangler containers list
```

Look for status. If "deploying", wait a few minutes.

**Solution**:
- First deploy takes 5-10 minutes
- Check logs: `npx wrangler tail`
- Verify Docker is running: `docker info`

### Out of Memory (OOM) errors

**Symptom**: Container restarts, logs show OOM

**Solution**:
- Increase instance type: `standard-1` → `standard-2`
- Or reduce `max_instances` to use larger instances

### Build fails

**Symptom**: `wrangler deploy` fails during image build

**Check**:
```bash
docker build -f Dockerfile.proxy -t test .
```

**Common issues**:
- Docker not running: `docker info`
- Insufficient disk space: `docker system prune -a`
- Wrong Dockerfile path in `wrangler.jsonc`

### Slow downloads

**Symptom**: Downloads are slower than expected

**Possible causes**:
1. **Cold start**: First request to a sleeping container
   - Solution: Increase `sleepAfter` or use health checks to keep warm

2. **Wrong instance type**: Underpowered instance
   - Solution: Use `standard-2` or higher

3. **Network limits**: Cloudflare global routing
   - Check egress bandwidth in dashboard

### Authentication errors

**Symptom**: 401 Unauthorized errors

**Check**:
- Token is valid: Test locally with same token
- Header format: `Authorization: Bearer hf_xxxxxxxxxxxxx`
- Token has repo access on HuggingFace

**Debug**:
```bash
curl -v -H "Authorization: Bearer hf_xxx..." \
  https://your-worker.workers.dev/health
```

### Deployment rollout stuck

**Symptom**: `npx wrangler containers list` shows instances in "updating" state

**Wait**: Rollouts can take 10-15 minutes for grace period

**Force immediate rollout**:
```bash
npx wrangler deploy --containers-rollout=immediate
```

## Advanced Topics

### Custom Domain

Add a custom domain in the Cloudflare dashboard:

1. Go to **Workers & Pages** → **xet-proxy-container**
2. Click **Settings** → **Domains & Routes**
3. Add custom domain (e.g., `xet-proxy.yourdomain.com`)
4. DNS records are configured automatically

### Using with Cloudflare R2

Store frequently accessed models in R2 for faster access:

```typescript
// Cache downloads in R2
const cached = await env.MY_R2_BUCKET.get(hash);
if (cached) {
  return new Response(cached.body);
}

// Otherwise, download and cache
const response = await container.fetch(request);
await env.MY_R2_BUCKET.put(hash, response.body);
```

### Integration with Cloudflare Queues

Process downloads asynchronously:

```typescript
// Producer: Queue download job
await env.DOWNLOAD_QUEUE.send({
  repo: "jedisct1/MiMo-7B-RL-GGUF",
  file: "model.gguf"
});

// Consumer: Process in container
export default {
  async queue(batch, env) {
    for (const msg of batch.messages) {
      await container.fetch(`/download/${msg.body.repo}/${msg.body.file}`);
    }
  }
}
```

### Multi-Region Placement (Coming Soon)

Cloudflare is working on regional affinity to keep containers closer to data sources.

## Resources

- [Cloudflare Containers Documentation](https://developers.cloudflare.com/containers/)
- [Wrangler CLI Reference](https://developers.cloudflare.com/workers/wrangler/commands/#containers)
- [Containers Pricing](https://developers.cloudflare.com/containers/pricing/)
- [Containers Discord Community](https://discord.cloudflare.com)
- [XET Protocol Specification](https://jedisct1.github.io/draft-denis-xet/draft-denis-xet.html)

## Getting Help

1. **Check logs**: `npx wrangler tail`
2. **Check status**: `npx wrangler containers list`
3. **Discord**: https://discord.cloudflare.com
4. **GitHub Issues**: https://github.com/leo-ars/cloudflare-proxy-xet/issues
5. **Cloudflare Support**: For billing or account issues

## Next Steps

After deploying:

1. ✅ Test all endpoints (health, download, download-hash)
2. ✅ Monitor costs in the first week
3. ✅ Set up custom domain (optional)
4. ✅ Configure secrets for production tokens
5. ✅ Load test to validate performance
6. ✅ Set up monitoring/alerting

Enjoy your globally distributed XET Proxy! 🚀
