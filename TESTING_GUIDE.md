# Testing Guide

This guide covers how to test the XET Proxy Server locally and in Docker.

## Prerequisites

- Zig 0.16 or newer
- Rust 1.83 or newer
- Docker with buildx support
- HuggingFace API token

## Quick Test

### 1. Build Everything

```bash
# Build Zig CLI
zig build -Doptimize=ReleaseFast

# Build Rust proxy
cd proxy-rust && cargo build --release && cd ..

# Verify binaries exist
ls -lh zig-out/bin/xet-download
ls -lh proxy-rust/target/release/xet-proxy
```

### 2. Run Tests

```bash
# Run Zig tests (106 tests)
zig build test

# Run Rust tests
cd proxy-rust && cargo test && cd ..
```

### 3. Test the Server Locally

```bash
# Terminal 1: Start the server
cd proxy-rust
export ZIG_BIN_PATH=../zig-out/bin/xet-download
cargo run --release

# Terminal 2: Test endpoints
# Health check (no auth needed)
curl http://localhost:8080/health

# Download with Bearer token
curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/README.md \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx"

# Test without auth (should return 401)
curl -i http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/README.md
```

## Docker Testing

### Build and Test Docker Image

```bash
# Build for your platform
docker buildx build \
  --platform linux/arm64 \
  --file Dockerfile.proxy \
  --tag xet-proxy:test \
  --load \
  .

# Run container
docker run -d -p 8080:8080 --name xet-proxy-test xet-proxy:test

# Wait for startup
sleep 3

# Test health endpoint
curl http://localhost:8080/health

# Test authentication
curl -i http://localhost:8080/download/test/repo/file
# Should return 401 Unauthorized

# Test with Bearer token
curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/README.md \
  -H "Authorization: Bearer hf_xxxxxxxxxxxxx"

# Check logs
docker logs xet-proxy-test

# Cleanup
docker stop xet-proxy-test
docker rm xet-proxy-test
```

### Multi-Platform Testing

```bash
# Build for AMD64
docker buildx build \
  --platform linux/amd64 \
  --file Dockerfile.proxy \
  --tag xet-proxy:amd64-test \
  --load \
  .

# Verify platform
docker image inspect xet-proxy:amd64-test --format '{{.Architecture}}'
# Should output: amd64

# Test it
docker run -d -p 8080:8080 --name test-amd64 xet-proxy:amd64-test
curl http://localhost:8080/health
docker stop test-amd64 && docker rm test-amd64
```

## Test Scenarios

### Scenario 1: Health Check (No Auth)

```bash
curl http://localhost:8080/health
# Expected: {"status":"ok","version":"0.1.0"}
```

### Scenario 2: Missing Authentication

```bash
curl -i http://localhost:8080/download/owner/repo/file
# Expected: HTTP 401 Unauthorized
# Body: {"error":"Authorization header required. Use: Authorization: Bearer hf_xxx"}
```

### Scenario 3: Invalid Bearer Token Format

```bash
curl -i http://localhost:8080/download/owner/repo/file \
  -H "Authorization: InvalidFormat"
# Expected: HTTP 401 Unauthorized
```

### Scenario 4: Valid Bearer Token

```bash
curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/README.md \
  -H "Authorization: Bearer YOUR_ACTUAL_TOKEN"
# Expected: HTTP 200 OK with file content
```

### Scenario 5: Download by Hash

```bash
curl http://localhost:8080/download-hash/89dbfa4888600b29be17ddee8bdbf9c48999c81cb811964eee6b057d8467f927 \
  -H "Authorization: Bearer YOUR_ACTUAL_TOKEN" \
  -o test.bin
# Expected: File downloads successfully
```

### Scenario 6: Large File Download

```bash
# Test streaming with a large file (7.5GB)
time curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/MiMo-7B-RL-Q8_0.gguf \
  -H "Authorization: Bearer YOUR_ACTUAL_TOKEN" \
  -o model.gguf \
  --progress-bar

# Expected performance (on good connection):
# Speed: 35-45 MB/s
# Time: ~3-4 minutes for 7.5GB
```

## Performance Testing

### Measure Download Speed

```bash
# Download to /dev/null to test pure network speed
time curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/MiMo-7B-RL-Q8_0.gguf \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -o /dev/null

# Monitor resource usage during download
docker stats xet-proxy-test
```

### Memory Usage

```bash
# Check container memory usage
docker stats --no-stream xet-proxy-test

# Expected: 200-500 MB during active download
```

### Concurrent Requests

```bash
# Test multiple simultaneous downloads
for i in {1..5}; do
  curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/README.md \
    -H "Authorization: Bearer YOUR_TOKEN" \
    -o "test-$i.md" &
done
wait

# Check all files downloaded correctly
ls -lh test-*.md
rm test-*.md
```

## Automated Test Script

Create a test script `test-proxy.sh`:

```bash
#!/bin/bash
set -e

echo "🧪 XET Proxy Server Test Suite"
echo "==============================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test counter
PASSED=0
FAILED=0

test_endpoint() {
    local name="$1"
    local cmd="$2"
    local expected="$3"
    
    echo -n "Testing $name... "
    
    if eval "$cmd" | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
    fi
}

# Start server in background
echo "Starting server..."
docker run -d -p 8080:8080 --name xet-test xet-proxy:test
sleep 3

# Run tests
test_endpoint "Health check" \
    "curl -s http://localhost:8080/health" \
    '"status":"ok"'

test_endpoint "No auth returns 401" \
    "curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/download/test/repo/file" \
    "401"

test_endpoint "Invalid auth returns 401" \
    "curl -s -o /dev/null -w '%{http_code}' -H 'Authorization: Invalid' http://localhost:8080/download/test/repo/file" \
    "401"

# Cleanup
echo ""
echo "Cleaning up..."
docker stop xet-test
docker rm xet-test

# Results
echo ""
echo "==============================="
echo "Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
```

Make it executable and run:

```bash
chmod +x test-proxy.sh
./test-proxy.sh
```

## Troubleshooting

### Build Failures

```bash
# Clean everything and rebuild
rm -rf zig-out .zig-cache
zig build -Doptimize=ReleaseFast

cd proxy-rust
cargo clean
cargo build --release
cd ..
```

### Server Won't Start

```bash
# Check if port is in use
lsof -i :8080

# Check server logs
docker logs xet-proxy-test

# Try different port
docker run -d -p 9000:8080 --name xet-test xet-proxy:test
curl http://localhost:9000/health
```

### Authentication Errors

```bash
# Verify Bearer token format
echo "Authorization: Bearer hf_xxxxxxxxxxxxx"
# Must have "Bearer " prefix (with space)

# Test with curl verbose mode
curl -v http://localhost:8080/download/owner/repo/file \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Download Failures

```bash
# Check if token is valid
# Visit: https://huggingface.co/settings/tokens

# Test with a small file first
curl http://localhost:8080/download/jedisct1/MiMo-7B-RL-GGUF/README.md \
  -H "Authorization: Bearer YOUR_TOKEN"

# Check server logs for errors
docker logs -f xet-proxy-test
```

## Test Checklist

- [ ] Zig tests pass (106 tests)
- [ ] Rust tests pass
- [ ] Zig CLI binary builds
- [ ] Rust proxy binary builds
- [ ] Docker image builds (ARM64)
- [ ] Docker image builds (AMD64)
- [ ] Health endpoint works
- [ ] 401 returned without auth
- [ ] 401 returned with invalid auth
- [ ] File downloads with valid Bearer token
- [ ] Large file downloads successfully
- [ ] Memory usage is reasonable
- [ ] Server handles concurrent requests
- [ ] Docker container starts and stops cleanly

## CI/CD Testing

For automated testing in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.16.0-dev.2145
      
      - name: Build and test Zig
        run: |
          zig build -Doptimize=ReleaseFast
          zig build test
      
      - name: Build and test Rust
        run: |
          cd proxy-rust
          cargo build --release
          cargo test
      
      - name: Build Docker image
        run: |
          docker buildx build \
            --platform linux/amd64 \
            --file Dockerfile.proxy \
            --tag xet-proxy:test \
            --load .
      
      - name: Test Docker image
        run: |
          docker run -d -p 8080:8080 --name test xet-proxy:test
          sleep 3
          curl http://localhost:8080/health
          docker stop test
```

## Performance Benchmarks

Reference benchmarks (MacBook Pro M1, Orange España network):

| Metric | Value |
|--------|-------|
| Health check latency | < 10ms |
| Small file (README) | < 1s |
| Large file (7.5GB) | ~3-4 minutes |
| Download speed | 35-45 MB/s |
| Memory usage | 200-500 MB |
| Container startup | < 2s |
| CPU usage | 1-2 cores |

*Your results may vary depending on network speed and hardware.*
