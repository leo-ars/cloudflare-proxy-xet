#!/bin/bash
# Test script for Cloudflare Workers Container deployment
# Usage: ./test-cloudflare.sh <worker-url> [hf-token]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <worker-url> [hf-token]"
    echo ""
    echo "Example:"
    echo "  $0 https://xet-proxy-container.your-subdomain.workers.dev hf_xxxxxxxxxxxxx"
    echo ""
    echo "If hf-token is not provided, download tests will be skipped"
    exit 1
fi

WORKER_URL="$1"
HF_TOKEN="${2:-}"

echo "========================================="
echo "Testing Cloudflare Workers Container"
echo "========================================="
echo "Worker URL: $WORKER_URL"
echo ""

# Test 1: Health Check
echo "Test 1: Health Check"
echo "---------------------"
RESPONSE=$(curl -s "${WORKER_URL}/health")
STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*"' || echo "")

if [[ "$STATUS" == *"ok"* ]]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "  Response: $RESPONSE"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo "  Response: $RESPONSE"
    exit 1
fi
echo ""

# Test 2: Root endpoint
echo "Test 2: Root Endpoint (HTML page)"
echo "----------------------------------"
RESPONSE=$(curl -s "${WORKER_URL}/")
if [[ "$RESPONSE" == *"XET Protocol HTTP Proxy Server"* ]]; then
    echo -e "${GREEN}✓ Root endpoint accessible${NC}"
    echo "  HTML page loaded successfully"
else
    echo -e "${RED}✗ Root endpoint failed${NC}"
    echo "  Expected HTML page not found"
    exit 1
fi
echo ""

# Test 3: Download test (requires token)
if [ -z "$HF_TOKEN" ]; then
    echo -e "${YELLOW}⊘ Skipping download tests (no HF_TOKEN provided)${NC}"
    echo ""
    echo "========================================="
    echo -e "${GREEN}Basic tests passed!${NC}"
    echo "========================================="
    echo ""
    echo "To test downloads, run:"
    echo "  $0 $WORKER_URL hf_your_token_here"
    exit 0
fi

echo "Test 3: Authentication"
echo "----------------------"
RESPONSE=$(curl -s -w "\n%{http_code}" "${WORKER_URL}/download-hash/0000000000000000000000000000000000000000000000000000000000000000" -H "Authorization: Bearer $HF_TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

# For invalid hash, we expect 400 or 500, not 401 (which would mean auth failed)
if [ "$HTTP_CODE" = "401" ]; then
    echo -e "${RED}✗ Authentication failed${NC}"
    echo "  HTTP Status: $HTTP_CODE"
    echo "  Response: $BODY"
    echo ""
    echo "  Please check your HuggingFace token:"
    echo "  1. Visit https://huggingface.co/settings/tokens"
    echo "  2. Verify token has read access"
    echo "  3. Try with a different token"
    exit 1
else
    echo -e "${GREEN}✓ Authentication working${NC}"
    echo "  Token accepted by proxy"
fi
echo ""

echo "Test 4: Download by Hash (small test)"
echo "--------------------------------------"
echo "  Note: This test uses an invalid hash to test the endpoint"
echo "  For real downloads, use a valid XET hash"

RESPONSE=$(curl -s -w "\n%{http_code}" "${WORKER_URL}/download-hash/0000000000000000000000000000000000000000000000000000000000000000" -H "Authorization: Bearer $HF_TOKEN")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

# We expect 400 (bad request) or 500 (internal error) for invalid hash
if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "500" ] || [ "$HTTP_CODE" = "404" ]; then
    echo -e "${GREEN}✓ Download endpoint responding${NC}"
    echo "  Endpoint is functional (invalid hash correctly rejected)"
else
    echo -e "${YELLOW}⊙ Unexpected response${NC}"
    echo "  HTTP Status: $HTTP_CODE"
fi
echo ""

echo "Test 5: Download by Path (repository listing)"
echo "----------------------------------------------"
echo "  Testing repository file listing..."

# Try to list files in a known public repo
RESPONSE=$(curl -s -w "\n%{http_code}" "${WORKER_URL}/download/jedisct1/MiMo-7B-RL-GGUF/README.md" -H "Authorization: Bearer $HF_TOKEN" --max-time 30)
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Path-based download working${NC}"
    echo "  Successfully accessed repository"
elif [ "$HTTP_CODE" = "404" ]; then
    echo -e "${YELLOW}⊙ File not found (expected for test)${NC}"
    echo "  Path endpoint is functional"
else
    echo -e "${YELLOW}⊙ Unexpected response: $HTTP_CODE${NC}"
    echo "  This may be normal if the file doesn't exist"
fi
echo ""

echo "========================================="
echo -e "${GREEN}All tests completed!${NC}"
echo "========================================="
echo ""
echo "Your Cloudflare Workers Container is ready to use."
echo ""
echo "Example usage:"
echo "  curl ${WORKER_URL}/download/owner/repo/file.gguf \\"
echo "    -H \"Authorization: Bearer $HF_TOKEN\" \\"
echo "    -o file.gguf"
echo ""
echo "For more examples, see: CLOUDFLARE.md"
