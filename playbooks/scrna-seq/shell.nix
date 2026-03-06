{ mkShell
, podman
}:

mkShell {
  packages = [
    podman
  ];

  shellHook = ''
    echo "=== Single-cell RNA Sequencing Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/single-cell/instructions"
    echo ""
    echo "Start the RAPIDS notebook environment:"
    echo "  nix run .#scrna-seq-container"
    echo ""
    echo "Access JupyterLab at: http://localhost:8888"
  '';
}
