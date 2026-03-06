{ mkShell
, openssh
, nmap
, avahi
}:

mkShell {
  packages = [
    openssh
    nmap
    avahi
  ];

  shellHook = ''
    echo "=== DGX Spark Local Network Access Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/connect-to-your-spark/instructions"
    echo ""
    echo "Discover your Spark on the local network:"
    echo "  avahi-browse -art              # Browse mDNS services"
    echo "  nmap -sn 192.168.1.0/24        # Scan your local subnet"
    echo ""
    echo "Connect via SSH:"
    echo "  ssh <user>@<hostname>.local"
    echo ""
    echo "SSH port forwarding (e.g. for web UIs):"
    echo "  ssh -L 11000:localhost:11000 <user>@<hostname>.local"
  '';
}
