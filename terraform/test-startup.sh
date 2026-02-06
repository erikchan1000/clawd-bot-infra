#!/bin/bash
# Test startup script locally
# 
# Usage:
#   ./test-startup.sh          # Syntax check only (fast)
#   ./test-startup.sh --full   # Full test in Docker container (slow)

set -e
cd "$(dirname "$0")"

echo "=== OpenClaw Startup Script Test ==="
echo ""

# 1. Syntax check
echo "1. Checking bash syntax..."
if bash -n startup.sh; then
    echo "   ✓ Syntax OK"
else
    echo "   ✗ Syntax ERROR"
    exit 1
fi

# 2. ShellCheck (if available)
echo ""
echo "2. Running ShellCheck (if available)..."
if command -v shellcheck &> /dev/null; then
    if shellcheck -e SC2034,SC2086,SC2154 startup.sh; then
        echo "   ✓ ShellCheck passed"
    else
        echo "   ⚠ ShellCheck found issues (see above)"
    fi
else
    echo "   ⚠ ShellCheck not installed (brew install shellcheck)"
fi

# 3. Check required variables are used
echo ""
echo "3. Checking required variables..."
REQUIRED_VARS=(
    "OPENCLAW_GATEWAY_TOKEN"
    "OPENCLAW_GATEWAY_PORT"
    "TAILSCALE_AUTH_KEY"
    "ANTHROPIC_API_KEY"
)
for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "$var" startup.sh; then
        echo "   ✓ $var is used"
    else
        echo "   ⚠ $var not found in script"
    fi
done

# 4. Check critical commands exist in script
echo ""
echo "4. Checking critical commands..."
CRITICAL_CMDS=(
    "docker build"
    "docker compose"
    "tailscale"
    "git clone"
)
for cmd in "${CRITICAL_CMDS[@]}"; do
    if grep -q "$cmd" startup.sh; then
        echo "   ✓ '$cmd' found"
    else
        echo "   ✗ '$cmd' NOT found"
    fi
done

# 5. Full Docker test (optional)
if [ "$1" = "--full" ]; then
    echo ""
    echo "5. Running full Docker test..."
    echo "   This will take several minutes..."
    
    docker run --rm -it \
        --privileged \
        --name openclaw-startup-test \
        -e OPENCLAW_GATEWAY_TOKEN="test-token-12345" \
        -e OPENCLAW_GATEWAY_PORT="18789" \
        -e TAILSCALE_AUTH_KEY="" \
        -e TAILSCALE_HOSTNAME="openclaw-test" \
        -e TAILSCALE_SERVE_MODE="serve" \
        -e ANTHROPIC_API_KEY="test-key" \
        -v "$(pwd)/startup.sh:/startup.sh:ro" \
        debian:bookworm \
        bash -c 'bash /startup.sh 2>&1 | head -200'
else
    echo ""
    echo "Tip: Run './test-startup.sh --full' for a full Docker test"
fi

echo ""
echo "=== Test Complete ==="
