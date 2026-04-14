# Connect two Sparks playbook

Configure network connectivity between two NVIDIA DGX Spark units via a
200GbE QSFP direct connection for distributed workloads.

## Prerequisites

- Two DGX Spark systems with matching usernames
- One QSFP cable

## Usage

```bash
nix develop .#connect-two-sparks
```

### Verify physical connection

After connecting the QSFP cable, check that the interface is up:

```bash
ibdev2netdev
```

Look for interfaces showing `(Up)` status, typically `enp1s0f0np0` or
`enp1s0f1np1`.

### Network configuration

Assign static IPs on each Spark:

```bash
# On Spark 1
sudo ip addr add 192.168.100.10/24 dev enp1s0f1np1
sudo ip link set enp1s0f1np1 up

# On Spark 2
sudo ip addr add 192.168.100.11/24 dev enp1s0f1np1
sudo ip link set enp1s0f1np1 up
```

### SSH setup

```bash
ssh-keygen -t ed25519
ssh-copy-id user@192.168.100.11
```

### Network testing

```bash
# On Spark 1 (server)
iperf3 -s

# On Spark 2 (client)
iperf3 -c 192.168.100.10
```

Two DGX Spark units are required for this playbook.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/connect-two-sparks/instructions)
