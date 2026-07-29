# Raw RDMA bandwidth, with no NCCL, CUDA or MPI involved. This is what decides
# where a disappointing nccl-run result comes from: close to the link rate means
# the fabric, cabling, MTU and RoCE configuration are sound and the shortfall is
# in NCCL's GPU-to-NIC path; slow here means the problem is below NCCL.
#
# A single MAC caps at ~100 Gb/s, since one physical QSFP port is two 100G MACs
# on separate PCIe x4 links -- so ~95 Gb/s on one device is full speed, not half
# of it. Pass the other address to test the second MAC.
#
# Substitutions: helpers ibdevForFn perftest sshOpts
set -euo pipefail
@helpers@

server="${1:?Usage: nccl-rdma-check <IP_Server> <IP_Client> [interface] [gid_index]}"
client="${2:?Usage: nccl-rdma-check <IP_Server> <IP_Client> [interface] [gid_index]}"
iface="${3:-}"
gid="${4:-3}"

if [ -z "$iface" ]; then
  iface="$(qsfp_ready | sed -n 1p)"
  if [ -z "$iface" ]; then
    echo "error: no QSFP MAC is linked and addressed; run nccl-net-setup." >&2
    exit 1
  fi
fi

require_reachable "$server"
require_reachable "$client"

# Resolve the RDMA device name on each node separately -- they differ. Single
# quotes so the function body reaches the far shell unexpanded.
resolve='@ibdevForFn@'
sdev="$(capture_on "$server" "$resolve; ibdev_for $iface")"
cdev="$(capture_on "$client" "$resolve; ibdev_for $iface")"
if [ -z "$sdev" ] || [ -z "$cdev" ]; then
  echo "error: could not map $iface to an RDMA device (server=$sdev client=$cdev)." >&2
  exit 1
fi

echo "Server $server: $iface -> $sdev"
echo "Client $client: $iface -> $cdev"
echo ""

export NIX_SSHOPTS="@sshOpts@"
for host in "$server" "$client"; do
  if ! is_local_addr "$host"; then
    echo "Copying perftest closure to $host..."
    nix copy --to "ssh://$host" --no-check-sigs @perftest@ >/dev/null
  fi
done

# -F skips the cpufreq governor complaint, -D 10 runs for ten seconds, -x picks
# the RoCEv2 GID as NCCL does.
ib_args="-F -D 10 -x $gid -s 1048576"

echo "Starting ib_write_bw server on $server..."
if is_local_addr "$server"; then
  @perftest@/bin/ib_write_bw -d "$sdev" $ib_args >/tmp/ib_write_bw.server.log 2>&1 &
else
  ssh -n -f @sshOpts@ "$server" \
    "@perftest@/bin/ib_write_bw -d $sdev $ib_args >/tmp/ib_write_bw.server.log 2>&1" &
fi
server_job=$!

# The server must be listening before the client connects, and there is no
# readiness signal to wait on.
sleep 3

echo "Running client on $client..."
set +e
run_on "$client" "@perftest@/bin/ib_write_bw -d $cdev $ib_args $server"
rc=$?
set -e

wait "$server_job" 2>/dev/null || true

if [ "$rc" -ne 0 ]; then
  echo "" >&2
  echo "client failed (exit $rc); server log on $server:" >&2
  capture_on "$server" 'tail -20 /tmp/ib_write_bw.server.log' >&2 || true
  exit "$rc"
fi

echo ""
echo "Interpretation: ~95 Gb/s is one MAC at full speed. Well below that"
echo "points at the fabric (cable, MTU, RoCE config); close to it means the"
echo "link is fine and any nccl-run shortfall is in NCCL's GPU path."
