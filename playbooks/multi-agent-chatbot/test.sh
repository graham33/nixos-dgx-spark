#!/usr/bin/env bash
set -euo pipefail

echo "=== Testing multi-agent-chatbot ==="

echo "Checking podman is available..."
podman --version >/dev/null
echo "OK: podman is available"

echo "Checking podman-compose is available..."
podman-compose --version >/dev/null
echo "OK: podman-compose is available"

echo "Checking curl is available..."
curl --version >/dev/null
echo "OK: curl is available"

echo "Checking jq is available..."
jq --version >/dev/null
echo "OK: jq is available"

echo "All tests passed!"
