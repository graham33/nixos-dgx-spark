{ mkShell
, git
, git-lfs
, podman
}:

mkShell {
  packages = [
    git
    git-lfs
    podman
  ];

  shellHook = ''
    echo "=== Isaac Sim and Isaac Lab Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/isaac/instructions"
    echo ""
    echo "Run Isaac Sim container (headless):"
    echo "  nix run .#isaac-sim-container"
    echo ""
    echo "Run Isaac Sim container with display:"
    echo "  export DISPLAY=:0 && xhost +local: && nix run .#isaac-sim-container"
    echo ""
    echo "Build Isaac Sim from source (recommended for DGX Spark):"
    echo "  git clone --depth=1 --recursive https://github.com/isaac-sim/IsaacSim"
    echo "  cd IsaacSim && git lfs install && git lfs pull && ./build.sh"
    echo ""
    echo "Note: Isaac Sim requires significant GPU memory."
  '';
}
