{ mkShell
, nixglhost
, podman
}:

mkShell {
  packages = [
    nixglhost
    podman
  ];

  shellHook = ''
    echo "=== Fine-tune with NeMo Playbook ==="
    echo "Container: nvcr.io/nvidia/pytorch:25.11-py3"
    echo "Instructions: https://build.nvidia.com/spark/nemo-fine-tune/instructions"
    echo ""
    echo "Start the NeMo environment:"
    echo "  nemo-start"
    echo ""
    echo "To pull the latest image:"
    echo "  podman pull nvcr.io/nvidia/pytorch:25.11-py3"
    echo ""

    # Create nemo-start command
    nemo-start() {
      echo "Starting NeMo fine-tuning container..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=8g \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        --entrypoint /usr/bin/bash \
        -v "$PWD":/workspace \
        -w /workspace \
        nvcr.io/nvidia/pytorch:25.11-py3
    }

    export -f nemo-start
  '';
}
