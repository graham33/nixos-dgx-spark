# Tailscale Setup Playbook

Set up Tailscale VPN on your NVIDIA DGX Spark for secure remote access from anywhere.

## Usage

```bash
nix develop .#tailscale
```

This shell provides the `tailscale` and `tailscaled` binaries.

### Quick Setup

```bash
sudo tailscaled &    # Start the Tailscale daemon
sudo tailscale up    # Authenticate and connect to your tailnet
tailscale status     # Check connection status
tailscale ip         # Show your Tailscale IP address
```

### NixOS Configuration

For persistent Tailscale on NixOS, add to your `configuration.nix`:

```nix
services.tailscale.enable = true;
networking.firewall.checkReversePath = "loose";
```

> **Note:** DGX Spark hardware is required. A Tailscale account is needed for
> authentication.

## References

- [NVIDIA DGX Spark Instructions](https://build.nvidia.com/spark/tailscale/instructions)
- [Tailscale Documentation](https://tailscale.com/kb/)
