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

### Connecting via SSH

```bash
# Connect by mDNS hostname
ssh <user>@<hostname>.local

# Port forwarding for web UIs (e.g. model serving endpoints)
ssh -L 11000:localhost:11000 <user>@<hostname>.local
```

Port forwarding maps a port on your local machine to a service running on the
Spark, allowing you to access remote web applications at `localhost:<port>`.

> **Note:** DGX Spark hardware is required for this playbook.

## References

- [Connect to Your Spark](https://build.nvidia.com/spark/connect-to-your-spark/instructions)
