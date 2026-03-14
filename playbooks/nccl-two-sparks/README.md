# NCCL for Two Sparks Playbook

Multi-node GPU communication using NVIDIA Collective Communications Library
(NCCL) between two DGX Spark units with Blackwell architecture.

## Prerequisites

- Two DGX Spark units connected via QSFP cable (see "Connect two Sparks"
  playbook)
- Passwordless SSH configured between the two nodes
- NVIDIA driver installed on both nodes

## Quick Start

1. Enter the devshell:

   ```bash
   nix develop .#nccl-two-sparks
   ```

2. Find the active network interface and IP addresses (`ibdev2netdev` is from
   `rdma-core`/`infiniband-diags`, preinstalled on DGX OS):

   ```bash
   ibdev2netdev
   ip addr show enp1s0f1np1
   ```

3. Run the all_gather performance test:

   ```bash
   nccl-run <IP_Node1> <IP_Node2>
   ```

4. Optionally, run a larger buffer test (16 GB) to verify 200 Gbps bandwidth:

   ```bash
   nccl-run-16g <IP_Node1> <IP_Node2>
   ```

## Available Commands

- `nccl-run <IP1> <IP2> [interface]` - Run all_gather_perf across two nodes
  (default interface: `enp1s0f1np1`)
- `nccl-run-16g <IP1> <IP2> [interface]` - Run all_gather_perf with 16 GB
  buffer size

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/nccl/instructions)
- [NCCL Tests on GitHub](https://github.com/NVIDIA/nccl-tests)
