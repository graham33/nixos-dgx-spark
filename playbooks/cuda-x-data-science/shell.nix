{ mkShell
, podman
}:

mkShell {
  packages = [
    podman
  ];

  shellHook = ''
    echo "=== CUDA-X Data Science Playbook ==="
    echo "Container: rapidsai/notebooks:25.12-cuda13-py3.12"
    echo "Instructions: https://build.nvidia.com/spark/cuda-x-data-science/instructions"
    echo ""
    echo "Start the RAPIDS notebooks environment:"
    echo "  nix run .#cuda-x-data-science-container"
    echo ""
    echo "Or pull the image first:"
    echo "  podman pull docker.io/rapidsai/notebooks:25.12-cuda13-py3.12"
    echo ""
    echo "Access JupyterLab at: http://localhost:8888"
  '';
}
