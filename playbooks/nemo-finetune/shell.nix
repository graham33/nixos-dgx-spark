{ mkShell
, podman
}:

mkShell {
  packages = [
    podman
  ];

  shellHook = ''
    echo "=== Fine-tune with NeMo Playbook ==="
    echo "Container: nvcr.io/nvidia/pytorch:25.11-py3"
    echo "Instructions: https://build.nvidia.com/spark/nemo-fine-tune/instructions"
    echo ""
    echo "Start the NeMo environment:"
    echo "  nix run .#nemo-finetune-container"
    echo ""
    echo "To pull the latest image:"
    echo "  podman pull nvcr.io/nvidia/pytorch:25.11-py3"
  '';
}
