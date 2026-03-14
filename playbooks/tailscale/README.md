# Tailscale Setup Playbook

Set up Tailscale VPN on your NVIDIA DGX Spark for secure remote access
from anywhere.

## Quick Setup

1. Install Tailscale following the
   [official instructions for Ubuntu](https://tailscale.com/kb/1039/install-ubuntu):

   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   ```

2. Start the daemon and authenticate:

   ```bash
   sudo tailscale up
   ```

3. Verify the connection:

   ```bash
   tailscale status
   tailscale ip
   ```

## NixOS Configuration

For persistent Tailscale on NixOS, add to your `configuration.nix`:

```nix
services.tailscale.enable = true;
networking.firewall.checkReversePath = "loose";
```

> **Note:** A [Tailscale account](https://login.tailscale.com/start) is
> needed for authentication.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/tailscale/instructions)
- [Tailscale Documentation](https://tailscale.com/kb/)
