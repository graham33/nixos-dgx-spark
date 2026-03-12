{ mkShell
, podman
, nixglhost
}:

mkShell {
  packages = [
    nixglhost
    podman
  ];

  shellHook = ''
    echo "=== Portfolio Optimisation Playbook ==="
    echo "Container: nvcr.io/nvidia/rapidsai/notebooks:25.10-cuda13-py3.13"
    echo "Instructions: https://build.nvidia.com/spark/portfolio-optimization/instructions"
    echo ""
    echo "To start the RAPIDS JupyterLab environment:"
    echo "  portfolio-start"
    echo ""
    echo "Access JupyterLab at: http://localhost:8888"
    echo ""

    portfolio-start() {
      echo "Starting RAPIDS portfolio optimisation environment..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=1g \
        -p 8888:8888 \
        -p 8787:8787 \
        -p 8786:8786 \
        nvcr.io/nvidia/rapidsai/notebooks:25.10-cuda13-py3.13
    }

    export -f portfolio-start
  '';
}
