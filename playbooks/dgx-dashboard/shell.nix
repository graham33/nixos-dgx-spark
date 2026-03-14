{ mkShell
, callPackage
, openssh
}:

let
  dgx-dashboard = callPackage ../../packages/dgx-dashboard { };
in
mkShell {
  packages = [
    openssh
    dgx-dashboard
  ];

  shellHook = ''
    echo "=== DGX Dashboard Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/dgx-dashboard/instructions"
    echo ""
    echo "The DGX Dashboard is a pre-installed web application on DGX OS."
    echo "Access it at: http://localhost:11000"
    echo ""
    echo "Run locally (aarch64-linux only):"
    echo "  dashboard-service -port 11000 serve"
    echo ""
    echo "For remote access, use SSH tunnelling:"
    echo "  dgx-dashboard-tunnel <user>@<host>"
    echo ""
    echo "This forwards port 11000 (dashboard) to your local machine."
    echo "Then open http://localhost:11000 in your browser."
    echo ""

    # SSH tunnel helper for remote DGX Dashboard access
    dgx-dashboard-tunnel() {
      local target="''${1:?Usage: dgx-dashboard-tunnel <user>@<host>}"
      echo "Opening SSH tunnel to $target..."
      echo "Dashboard will be available at: http://localhost:11000"
      echo "Press Ctrl-C to close the tunnel."
      exec ssh -N -L 11000:localhost:11000 "$target"
    }

    export -f dgx-dashboard-tunnel
  '';
}
