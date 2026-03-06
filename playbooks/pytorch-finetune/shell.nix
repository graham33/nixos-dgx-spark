{ mkShell
, podman
}:

mkShell {
  packages = [
    podman
  ];

  shellHook = ''
    echo "=== Fine-tune with PyTorch Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/pytorch-fine-tune/instructions"
    echo ""
    echo "Start the PyTorch environment:"
    echo "  nix run .#pytorch-finetune-container"
  '';
}
