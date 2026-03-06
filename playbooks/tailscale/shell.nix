{ mkShell
, tailscale
}:

mkShell {
  packages = [
    tailscale
  ];

  shellHook = ''
    echo "=== Tailscale Setup Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/tailscale/instructions"
    echo ""
    echo "Quick setup:"
    echo "  sudo tailscaled &    # Start the Tailscale daemon"
    echo "  sudo tailscale up    # Authenticate and connect"
    echo "  tailscale status     # Check connection status"
    echo ""
    echo "For NixOS, add to configuration.nix:"
    echo "  services.tailscale.enable = true;"
  '';
}
