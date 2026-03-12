#!/usr/bin/env bash
# Full integration tests require two DGX Spark machines
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing connect-two-sparks ==="

# --- Smoke tests (always run) ---

echo "Checking binaries..."
command -v ssh
command -v ssh-keygen
command -v ssh-copy-id
command -v iperf3
command -v ethtool

echo "Checking ssh..."
HELP=$(ssh --help 2>&1 || true)
echo "$HELP" | grep -qF "usage:"
echo "OK: ssh --help works"

echo "Checking iperf3..."
HELP=$(iperf3 --help 2>&1 || true)
echo "$HELP" | grep -qF -- "--port"
echo "OK: iperf3 --help works"

echo "Checking ethtool..."
ethtool --version
echo "OK: ethtool --version works"

echo "Checking rdma tools (ibv_devices)..."
command -v ibv_devices
echo "OK: ibv_devices available"

echo "Checking rdma tools (ibstat)..."
command -v ibstat
echo "OK: ibstat available"

# --- Full integration tests (only with --full) ---
if $FULL; then
  echo "Full integration tests require two DGX Spark machines connected via QSFP cable."
  echo "Skipping cross-machine tests in automated mode."
  echo ""
  echo "To run manually:"
  echo "  1. Connect both Sparks with a QSFP cable"
  echo "  2. Assign IPs: sudo ip addr add 192.168.100.10/24 dev enp1s0f1np1"
  echo "  3. Start server: iperf3 -s"
  echo "  4. Run client on Spark 2: iperf3 -c 192.168.100.10"
fi

echo "All smoke tests passed!"
