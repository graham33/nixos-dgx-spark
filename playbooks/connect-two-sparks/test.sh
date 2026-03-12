#!/usr/bin/env bash
# Full integration tests require two DGX Spark machines
set -euo pipefail

FULL=false
[[ "${1:-}" == "--full" ]] && FULL=true

echo "=== Testing connect-two-sparks ==="

# --- Smoke tests (always run) ---

# iperf3: check -s (server) and -c (client) flags used in the README workflow
echo "Checking iperf3 -s (server mode)..."
HELP=$(iperf3 --help 2>&1 || true)
echo "$HELP" | grep -qF -- "-s, --server"
echo "OK: iperf3 supports -s (server mode)"

echo "Checking iperf3 -c (client mode)..."
echo "$HELP" | grep -qF -- "-c, --client"
echo "OK: iperf3 supports -c (client mode)"

# ssh-keygen: check -t flag for ed25519 key type used in README
echo "Checking ssh-keygen -t ed25519..."
HELP=$(ssh-keygen --help 2>&1 || true)
echo "$HELP" | grep -qF "ed25519"
echo "OK: ssh-keygen supports -t ed25519"

# ssh-copy-id: used to set up passwordless SSH between the two Sparks
echo "Checking ssh-copy-id..."
HELP=$(ssh-copy-id --help 2>&1 || true)
echo "$HELP" | grep -qiF "hostname"
echo "OK: ssh-copy-id available"

# ibv_devices: RDMA device listing from rdma-core
echo "Checking ibv_devices..."
command -v ibv_devices
echo "OK: ibv_devices available"

# ibstat: InfiniBand status tool with -l (list CAs) flag
echo "Checking ibstat -l..."
HELP=$(ibstat --help 2>&1 || true)
echo "$HELP" | grep -qF -- "--list_of_cas"
echo "OK: ibstat supports -l (list_of_cas)"

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
