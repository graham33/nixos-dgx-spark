# NCCL for two Sparks playbook

Multi-node GPU communication using NVIDIA Collective Communications Library
(NCCL) between two DGX Spark units with Blackwell architecture.

Measured: **23.2 GB/s** busbw on a 16 GB all_gather, ~186 Gb/s of a 200G link.

## Prerequisites

- Two DGX Spark units connected via QSFP cable (see "Connect two Sparks")
- Passwordless SSH between the nodes, and `sudo` on both
- Nix on both nodes, with your SSH user a **trusted user** on the remote
  (`nix.settings.trusted-users`) -- `nccl-run` copies its closure there
- Raised memlock, or RDMA registration fails. The `dgx-spark` module sets it;
  for one session, `sudo prlimit --memlock=unlimited --pid $$`

The nodes need not share an OS or driver version: each rank runs under
`nixglhost`, and CUDA minor-version compatibility covers the rest.

## Quick start

```bash
nix develop .#nccl-two-sparks
nccl-net-setup 192.168.1.220 192.168.1.207   # management addresses; once per boot
nccl-run-16g 192.168.100.11 192.168.100.12
```

## Commands

- `nccl-net-setup <SSH1> <SSH2> [interface] [subnet]` - configure the
  interconnect on both nodes: addresses, MTU 9000, ARP, firewalls, then verify
  and warm each path
- `nccl-run <IP1> <IP2> [interface]` - all_gather_perf, 32 MB
- `nccl-run-16g <IP1> <IP2> [interface]` - all_gather_perf, 16 GB
- `nccl-rdma-check <IP_Server> <IP_Client> [interface] [gid_index]` - raw RDMA
  bandwidth via `ib_write_bw`, no NCCL, CUDA or MPI in the path

`NCCL_RUN_DEBUG=1` shows the remote rank's stderr and sets `NCCL_DEBUG=WARN`;
without it most failures appear only as a generic communication error. Level 2
adds PRRTE tracing, which buries the NCCL messages. `NCCL_DEBUG`,
`NCCL_IB_HCA`, `NCCL_ALGO` and friends are forwarded when set.

## Hardware notes

One physical QSFP port is **two 100G MACs** on separate PCIe x4 links
(`enp1s0f0np0` and `enP2p1s0f0np0` are the same socket), and NCCL needs both for
200 Gbps. Hence every linked MAC gets an address, each on its own /24. One cable
is enough; a second adds nothing, and using both physical ports contends for
PCIe.

GPUDirect RDMA is unavailable -- `nvidia_peermem` needs the peer-memory API that
DOCA-OFED adds to `ib_core`, which neither kernel has. It costs little, as the
GB10 shares one pool of LPDDR5X between CPU and GPU.

Interconnect state is applied per boot, since the DGX OS peer cannot be
configured declaratively from NixOS.

## Expected bandwidth

| Measurement                    | Healthy  | Measured  |
| ------------------------------ | -------- | --------- |
| `ib_write_bw`, one MAC         | ~95 Gb/s | 105 Gb/s  |
| `all_gather_perf` busbw, 32 MB | --       | 18.5 GB/s |
| `all_gather_perf` busbw, 16 GB | ~23 GB/s | 23.2 GB/s |

Judge bandwidth by the 16 GB test; at 32 MB the collective is too short to
amortise startup and under-reports.

## Troubleshooting

Run `nccl-rdma-check` first: near the link rate means the fabric is sound and
the problem is in NCCL; well below means it is underneath.

| Symptom                                                     | Cause                                                                                                                  |
| ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `prted: No such file or directory`                          | Store path missing on the remote; `nix copy` needs trusted-user status                                                 |
| "A daemon failed to report back", `prted` alive, no GPU use | Interface down or unaddressed, or a firewall dropping the callback to an ephemeral port                                |
| "PRTE has lost communication with a remote daemon"          | A path forwarded to the daemon does not resolve there; it segfaults after complaining, and you never see the complaint |
| "CUDA driver version is insufficient"                       | `libcuda.so.1` not found at all -- nix binaries search only `/run/opengl-driver/lib`, absent on DGX OS                 |
| `ibv_reg_mr ... Cannot allocate memory`                     | memlock ceiling on the node named. The other rank blames the network, so check both                                    |
| `IBV_WC_RETRY_EXC_ERR` on one HCA                           | Cold ARP entry -- RoCE spends its retry budget rather than waiting for resolution                                      |
| Two results, `nGpus 1` / `Rank 0`, `busbw 0.00`             | `nccl-tests` built without MPI, so each rank is a world of one                                                         |
| `Failed to initialize NET plugin IB`, then `NET/Socket`     | NCCL dlopens `libibverbs`/`libmlx5`; nixpkgs' `nccl` lists neither and has no RPATH                                    |
| Clean run at ~1 GB/s                                        | `NCCL_SOCKET_IFNAME` never reached the ranks, so NCCL picked its own interface                                         |
| `NET/IB` but far below ~23 GB/s                             | Check `active_mtu: 4096`, GID index (RoCEv2/IPv4, usually 3), both MACs addressed, and matching NIC firmware           |

Firmware deserves suspicion when nothing else explains it: a wedged ConnectX
held raw RDMA to 13 Gbps while `ethtool` reported 200000Mb/s, PCIe was Gen5 x4
and every error counter read zero. A full power drain -- both units, power and
QSFP unplugged -- restored it. `irisc not responding` appears in the kernel log
only well after the degradation starts.

To separate a remote-side problem from an MPI one, run a single rank directly:

```bash
ssh <remote> "$(command -v nixglhost) $(dirname "$(command -v all_gather_perf)")/all_gather_perf -b 8 -e 8"
```

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/nccl/instructions)
- [NCCL Tests on GitHub](https://github.com/NVIDIA/nccl-tests)
