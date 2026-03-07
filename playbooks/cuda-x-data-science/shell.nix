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
    echo "  cuda-x-start"
    echo ""
    echo "Or pull the image first:"
    echo "  podman pull docker.io/rapidsai/notebooks:25.12-cuda13-py3.12"
    echo ""
    echo "Access JupyterLab at: http://localhost:8888"

    # Launch the RAPIDS notebooks container
    cuda-x-start() {
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        -p 8888:8888 \
        -v "$PWD":/workspace \
        -w /workspace \
        docker.io/rapidsai/notebooks:25.12-cuda13-py3.12
    }

    export -f cuda-x-start
  '';
}
