# cURL Examples for XET Proxy

## Important: Correct Syntax

When using curl with headers, the `-H` flag and URL must be in the correct order:

### ✅ CORRECT
```bash
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" https://example.com/path
```

### ❌ WRONG
```bash
curl https://example.com/path -H "Authorization: Bearer hf_xxxxxxxxxxxxx"
# This can work but may cause issues with some curl versions
```

### ❌ WRONG (Missing URL)
```bash
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx"
# Error: no URL specified!
```

## Testing Cloudflare Deployment

Replace `YOUR_WORKER_URL` with your actual Worker URL from the deployment output.

### 1. Health Check (No Auth Required)

```bash
# Basic health check
curl https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev/health

# Expected response:
# {"status":"ok","version":"0.1.0"}
```

### 2. Download by Repository Path

```bash
# Replace hf_xxxxxxxxxxxxx with your actual HuggingFace token
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev/download/jedisct1/MiMo-7B-RL-GGUF/MiMo-7B-RL-Q8_0.gguf \
  -o model.gguf

# Or on one line:
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev/download/jedisct1/MiMo-7B-RL-GGUF/MiMo-7B-RL-Q8_0.gguf -o model.gguf
```

### 3. Download by Hash

```bash
# Replace with actual hash and token
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev/download-hash/89dbfa4888600b29be17ddee8bdbf9c48999c81cb811964eee6b057d8467f927 \
  -o model.safetensors
```

### 4. View HTML Landing Page

```bash
# Just visit the root URL in a browser or:
curl https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev/
```

## Testing Local Docker

If you're testing the Docker container locally (not Cloudflare):

### 1. Health Check
```bash
curl http://localhost:8080/health
```

### 2. Download (requires token)
```bash
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/model.gguf \
  -o model.gguf
```

## Common Errors and Fixes

### Error: "Bad hostname"
**Cause**: Missing or malformed URL

**Fix**: Make sure you include the full URL including `https://`

```bash
# Wrong:
curl -H "Authorization: Bearer token" xet-proxy-container.workers.dev

# Correct:
curl -H "Authorization: Bearer token" https://xet-proxy-container.workers.dev/health
```

### Error: "Authorization header required"
**Cause**: Trying to download without providing a token, or token in wrong format

**Fix for health check**: Health endpoint shouldn't need auth - check you're hitting the right endpoint:
```bash
curl https://your-worker.workers.dev/health
```

**Fix for downloads**: Ensure header format is correct:
```bash
curl -H "Authorization: Bearer hf_YOUR_TOKEN_HERE" https://...
```

### Error: "401 Unauthorized"
**Cause**: Invalid or expired HuggingFace token

**Fix**: 
1. Get a new token from https://huggingface.co/settings/tokens
2. Ensure token has "Read access to contents of all public gated repos"
3. Test the token directly with HuggingFace API:
   ```bash
   curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
     https://huggingface.co/api/whoami
   ```

### Error: Connection timeout or refused
**Cause**: Container is still starting (cold start) or wrong URL

**Fix**: 
- First request after deploy can take 30-60 seconds for container to start
- Verify your Worker URL is correct
- Check deployment status: `npm run cf:status`

## Debugging Tips

### 1. Check if Worker is deployed
```bash
cd worker
npx wrangler deployments list
```

### 2. View live logs
```bash
cd worker
npx wrangler tail
```

Then make your curl request in another terminal to see what's happening.

### 3. Test with verbose output
```bash
curl -v https://your-worker.workers.dev/health
```

This shows full HTTP headers and helps debug issues.

### 4. Use the test script
```bash
# Automated testing
./test-cloudflare.sh https://your-worker.workers.dev hf_your_token
```

## Quick Reference

| What | Command |
|------|---------|
| **Health check** | `curl https://your-worker.workers.dev/health` |
| **Download** | `curl -H "Authorization: Bearer token" https://your-worker.workers.dev/download/owner/repo/file -o file` |
| **View logs** | `cd worker && npx wrangler tail` |
| **Check status** | `cd worker && npx wrangler deployments list` |

## Examples with Real Data

### Download a small file (test)
```bash
# Test with a small README file first
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  https://your-worker.workers.dev/download/gpt2/gpt2/README.md \
  -o test-readme.md
```

### Download a larger model
```bash
# ~8GB model - this will take several minutes
curl -H "Authorization: Bearer hf_xxxxxxxxxxxxx" \
  https://your-worker.workers.dev/download/jedisct1/MiMo-7B-RL-GGUF/MiMo-7B-RL-Q8_0.gguf \
  -o model.gguf
```

## Need Help?

1. **Check logs**: `cd worker && npx wrangler tail`
2. **Verify deployment**: `cd worker && npx wrangler deployments list`
3. **Test locally first**: Run Docker container locally to isolate issues
4. **Check HF token**: Test token at https://huggingface.co/settings/tokens

## Your Deployment URL

After running `npm run cf:deploy`, look for this in the output:

```
Published xet-proxy-container
  https://xet-proxy-container.YOUR-SUBDOMAIN.workers.dev
```

Copy that URL and use it in the examples above.
