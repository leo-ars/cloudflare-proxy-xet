# XET Proxy - Cloudflare Deployment Quick Start

## Prerequisites ✅

- [ ] Node.js 18+ installed (`node --version`)
- [ ] Docker running (`docker info`)
- [ ] Cloudflare account with Workers Paid plan ($5/month)
- [ ] HuggingFace token from https://huggingface.co/settings/tokens

## Deploy in 3 Commands 🚀

```bash
npm install              # Install dependencies
npm run cf:login         # Login to Cloudflare (opens browser)
npm run cf:deploy        # Deploy to production
```

⏱️ First deploy: 5-10 minutes | Subsequent: 1-2 minutes

## Your Deployment URL

After deploy, copy your URL:
```
https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev
```

## Test It ✨

```bash
# Health check (no auth needed)
curl https://your-worker.workers.dev/health

# Download a file
curl https://your-worker.workers.dev/download/jedisct1/MiMo-7B-RL-GGUF/model.gguf \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  -o model.gguf

# Automated tests
./test-cloudflare.sh https://your-worker.workers.dev hf_xxxxxxxxxxxxx
```

## Common Commands 📝

```bash
npm run cf:dev           # Local development (with hot reload)
npm run cf:deploy        # Deploy to production
npm run cf:tail          # Live tail logs
npm run cf:status        # Check container status
npm run cf:images        # List images in registry
```

## API Endpoints 🔌

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /health` | ❌ | Health check |
| `GET /download/:owner/:repo/*file` | ✅ | Download by path |
| `GET /download-hash/:hash` | ✅ | Download by XET hash |

**Auth format**: `Authorization: Bearer hf_xxxxxxxxxxxxx`

## Configuration ⚙️

Edit `worker/wrangler.jsonc`:

```jsonc
{
  "containers": [{
    "instance_type": "standard-1",  // CPU, RAM, disk
    "max_instances": 10,            // Max concurrent containers
  }]
}
```

**Instance types**:
- `lite`: 1/16 vCPU, 256MB RAM (testing)
- `basic`: 1/4 vCPU, 1GB RAM (light load)
- `standard-1`: 1/2 vCPU, 4GB RAM ⭐ **recommended**
- `standard-2`: 1 vCPU, 6GB RAM (high load)
- `standard-3`: 2 vCPU, 8GB RAM (very high load)
- `standard-4`: 4 vCPU, 12GB RAM (maximum)

Edit `worker/src/index.ts`:

```typescript
export class XetProxyContainer extends Container<Env> {
  defaultPort = 8080;      // Container port
  sleepAfter = "10m";      // Idle timeout
  enableInternet = true;   // For HuggingFace access
}
```

## Monitoring 📊

### Dashboard
https://dash.cloudflare.com → Workers & Pages → Containers

### Live Logs
```bash
npm run cf:tail
```

### Status Check
```bash
npm run cf:status
```

## Cost Estimate 💰

| Usage | Instance | Hours/mo | Egress | Cost |
|-------|----------|----------|--------|------|
| **Testing** | standard-1 | 10 | 10 GB | **~$5.50** |
| **Light** | standard-1 | 50 | 100 GB | **~$8** |
| **Moderate** | standard-2 | 100 | 500 GB | **~$15** |
| **Heavy** | standard-3 | 720 (24/7) | 2 TB | **~$250** |

💡 Only pay for active usage. Containers sleep when idle.

## Troubleshooting 🔧

### Container won't start
```bash
npm run cf:status  # Check deployment status
npm run cf:tail    # Check logs
```
⏳ First deploy takes 5-10 minutes to distribute globally.

### Build fails
```bash
docker info  # Verify Docker is running
docker system prune -a  # Clean up disk space
```

### Authentication errors
- Check token format: `Authorization: Bearer hf_...`
- Verify token at https://huggingface.co/settings/tokens
- Ensure token has read access to public repos

### Slow downloads
- Increase instance type: `standard-1` → `standard-2`
- Check logs for cold starts: `npm run cf:tail`

## Scaling 📈

### Increase max instances
Edit `worker/wrangler.jsonc`:
```jsonc
"max_instances": 20  // Increase from 10
```

### Upgrade instance type
```jsonc
"instance_type": "standard-2"  // More CPU/RAM
```

### Redeploy
```bash
npm run cf:deploy
```

## Advanced 🎓

### Add custom domain
Dashboard → Workers → Settings → Domains & Routes

### Set secrets
```bash
cd worker
npx wrangler secret put HF_TOKEN
```

### Immediate rollout
```bash
npm run cf:deploy:immediate  # Update all instances at once
```

### Local development with rebuild
```bash
npm run cf:dev
# Press [r] to rebuild container
```

## Documentation 📚

- 📘 **Comprehensive Guide**: [CLOUDFLARE.md](CLOUDFLARE.md)
- 📗 **Worker Quick Ref**: [worker/README.md](worker/README.md)
- 📙 **Setup Summary**: [CLOUDFLARE_SETUP_SUMMARY.md](CLOUDFLARE_SETUP_SUMMARY.md)
- 📕 **Docker Guide**: [DOCKER.md](DOCKER.md)

## Support 💬

- 🐛 GitHub Issues: https://github.com/leo-ars/cloudflare-proxy-xet/issues
- 💬 Discord: https://discord.cloudflare.com
- 📖 Cloudflare Docs: https://developers.cloudflare.com/containers/

## What's Next? ⏭️

1. ✅ Deploy: `npm run cf:deploy`
2. ✅ Test: `./test-cloudflare.sh <url> <token>`
3. ✅ Monitor: Check dashboard
4. ✅ Scale: Adjust config as needed
5. ✅ Integrate: Use in your applications

---

**Deploy now**: `npm run cf:deploy` 🚀
