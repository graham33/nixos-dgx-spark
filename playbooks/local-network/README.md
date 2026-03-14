# Set Up Local Network Access Playbook

Configure local network access to your NVIDIA DGX Spark for development and
remote management.

## Usage

```bash
nix develop .#local-network
```

This shell provides tools for discovering and connecting to your DGX Spark on a
local network, including SSH with port forwarding for accessing web UIs.

### Discovering Your Spark

DGX Spark uses mDNS (`.local` hostnames) for discovery on local networks.

```bash
# Browse mDNS services on your network
avahi-browse -art

# Scan your local subnet for devices
nmap -sn 192.168.1.0/24
```

The `nmap` scan will list discovered hosts. Your Spark should appear with its
hostname and IP address, for example:

```
Nmap scan report for spark-abcd.local (192.168.1.42)
Host is up (0.0042s latency).
```

You can also verify mDNS resolution directly:

```bash
ping spark-abcd.local
```

Expected output:

```
PING spark-abcd.local (192.168.1.42): 56 data bytes
64 bytes from 192.168.1.42: icmp_seq=0 ttl=64 time=6.902 ms
```

### Connecting via SSH

```bash
# Connect by mDNS hostname
ssh <user>@<hostname>.local

# Port forwarding for web UIs (e.g. model serving endpoints)
ssh -L 11000:localhost:11000 <user>@<hostname>.local
```

On first connection, accept the host fingerprint prompt by typing `yes`. You
can then verify the connection:

```bash
hostname
uname -a
```

Expected output:

```
spark-abcd
Linux spark-abcd 6.x.y-nvidia-... #1 SMP ... aarch64 GNU/Linux
```

Port forwarding maps a port on your local machine to a service running on the
Spark, allowing you to access remote web applications at `localhost:<port>`.

> **Note:** DGX Spark hardware is required for this playbook.

## References

- [Connect to Your Spark](https://build.nvidia.com/spark/connect-to-your-spark/instructions)
