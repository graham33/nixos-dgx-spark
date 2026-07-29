# Run all_gather_perf across the two nodes.
#
# Substitutions: helpers name description testArgs sshOpts
#                remoteClosure openmpi ncclSsh nixglhost rdmaCore
#                ncclTests
set -euo pipefail
@helpers@

node1="${1:?Usage: @name@ <IP_Node1> <IP_Node2> [interface]}"
node2="${2:?Usage: @name@ <IP_Node1> <IP_Node2> [interface]}"
iface="${3:-}"

# Default to whichever QSFP MAC is linked *and* addressed. Which one is cabled
# varies per machine, and naming a down interface makes prted exit 1 behind a
# misleading "daemon failed to report back".
if [ -z "$iface" ]; then
  iface="$(qsfp_ready | sed -n 1p)"
  if [ -z "$iface" ]; then
    echo "error: no QSFP interface is both linked and addressed." >&2
    if [ -n "$(qsfp_linked)" ]; then
      echo "Linked but unaddressed: $(qsfp_linked | tr '\n' ' ')" >&2
      echo "Run 'nccl-net-setup $node1 $node2' to assign addresses." >&2
    else
      echo "No QSFP port has carrier -- check the cable." >&2
    fi
    exit 1
  fi
fi

# An interface named on the command line skips that detection, so check it is
# usable rather than handing NCCL a dead one.
if ! qsfp_ready | grep -xF "$iface" >/dev/null; then
  echo "warning: $iface has no global IPv4 address on this node." >&2
  echo "  RoCEv2 GIDs come from the interface address, so NCCL will fall" >&2
  echo "  back or fail. Run nccl-net-setup first." >&2
fi

# OMPI_MCA_* reaches the ranks by itself; NCCL_* does not -- mpirun forwards its
# own prefixes plus whatever -x names, so exporting alone is not enough. See
# mpi_env below.
export NCCL_SOCKET_IFNAME="$iface"
export OMPI_MCA_btl_tcp_if_include="$iface"

# RoCEv2 GID index. Each port publishes several GIDs -- RoCEv1 and RoCEv2, for
# the link-local IPv6 address and for each IPv4 address -- and NCCL picks index 0
# by default, which is RoCEv1 over link-local. Index 3 is the RoCEv2/IPv4 entry
# on these cards; confirm against
# /sys/class/infiniband/<dev>/ports/1/gid_attrs/types/<n>. Overridable, as the
# index depends on how many addresses the port has.
export NCCL_IB_GID_INDEX="${NCCL_IB_GID_INDEX:-3}"

# NCCL_RUN_DEBUG surfaces what the launcher hides, in two levels because the
# second buries the first under hundreds of state-machine lines:
#
#   1 -- the remote daemon's stderr (--leave-session-attached) plus NCCL's own
#        warnings. This is what explains a rank that dies.
#   2 -- additionally PRRTE's launch and state tracing, for when the launch
#        itself is the problem rather than anything NCCL did.
#
# Exported here rather than beside the mpirun flags: NCCL_DEBUG has to be set
# before mpi_env is assembled, or the -x forwarding misses it.
if [ -n "${NCCL_RUN_DEBUG:-}" ]; then
  export NCCL_DEBUG="${NCCL_DEBUG:-WARN}"
fi

# Forward the NCCL knobs explicitly. Without NCCL_SOCKET_IFNAME the ranks pick an
# interface themselves and settle on the management LAN, which benchmarks at
# about 1 GB/s -- a result that looks like a working run rather than a
# misconfigured one. The rest pass through only when set.
#
# LD_LIBRARY_PATH carries rdma-core: NCCL dlopens libibverbs.so.1 and
# libmlx5.so.1, but nixpkgs' nccl lists neither and libnccl.so has no RPATH, so
# the dlopen fails, NCCL reports "Failed to initialize NET plugin IB" and quietly
# uses TCP instead. Safe to set wholesale -- nixglhost appends any inherited
# value after its own driver directories, and a store path is identical on both
# nodes (it is in the copied closure) so no host glibc comes with it.
mpi_env=(
  -x NCCL_SOCKET_IFNAME
  -x NCCL_IB_GID_INDEX
  -x "LD_LIBRARY_PATH=@rdmaCore@/lib"
)
for v in NCCL_DEBUG NCCL_DEBUG_SUBSYS NCCL_IB_HCA NCCL_IB_DISABLE \
         NCCL_IB_TC NCCL_IB_PCI_RELAXED_ORDERING NCCL_NET_GDR_LEVEL \
         NCCL_P2P_DISABLE NCCL_ALGO NCCL_PROTO; do
  if [ -n "${!v:-}" ]; then
    mpi_env+=(-x "$v")
  fi
done

mpi_debug=()
case "${NCCL_RUN_DEBUG:-}" in
  "") ;;
  2 | all)
    mpi_debug=(
      --leave-session-attached
      --prtemca plm_base_verbose 5
      --prtemca state_base_verbose 5
    )
    ;;
  *) mpi_debug=(--leave-session-attached) ;;
esac

echo "Checking $node1 and $node2..."
require_reachable "$node1"
require_reachable "$node2"
require_memlock "$node1"
require_memlock "$node2"

# The nix store is not shared between the two Sparks, so copy the closure of
# everything mpirun will exec remotely. Any address of this host is skipped.
export NIX_SSHOPTS="@sshOpts@"
for host in "$node1" "$node2"; do
  if is_local_addr "$host"; then
    echo "Skipping closure copy to $host (local host)"
    continue
  fi
  echo "Copying nix closure to $host..."
  nix copy --to "ssh://$host" --no-check-sigs @remoteClosure@
done

echo "Running @description@ between $node1 and $node2 on interface $iface..."

# Each rank runs under nixglhost, which finds that node's own driver libraries.
# Without it the binary searches only /run/opengl-driver/lib, absent on DGX OS,
# so libcuda.so.1 is never found and cudart reports the misleading "CUDA driver
# version is insufficient". LD_LIBRARY_PATH is not a substitute: pointing at the
# host lib directory drags in DGX OS's older glibc, which cannot satisfy libnccl.
#
# --mca pml ob1 --mca btl tcp,self keeps MPI off UCX. nccl-tests uses MPI only to
# bootstrap while NCCL moves the data, so MPI's transport need not be fast, and
# UCX negotiates per node: the two Sparks' RoCE stacks disagree, the ranks pick
# different transports, and the one falling back to TCP gets "Connection
# refused" from a peer that never opened a TCP listener.
#
# --bind-to none because OpenMPI binds each rank to a single core when np <= 2,
# starving the proxy threads that do NCCL's RDMA progress work.
@openmpi@/bin/mpirun -np 2 -H "$node1":1,"$node2":1 \
  --mca plm_rsh_agent @ncclSsh@/bin/nccl-ssh \
  --mca pml ob1 --mca btl tcp,self \
  --bind-to none --map-by slot \
  "${mpi_env[@]}" \
  "${mpi_debug[@]}" \
  @nixglhost@/bin/nixglhost \
  @ncclTests@/bin/all_gather_perf @testArgs@
