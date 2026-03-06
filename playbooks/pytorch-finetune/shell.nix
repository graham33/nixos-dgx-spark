{ mkShell
, podman
}:

mkShell {
  packages = [
    podman
  ];

  shellHook = ''
    echo "=== Fine-tune with PyTorch Playbook ==="
    echo "Container: nvcr.io/nvidia/pytorch:25.11-py3"
    echo "Instructions: https://build.nvidia.com/spark/pytorch-fine-tune/instructions"
    echo ""
    echo "To start the PyTorch fine-tuning environment:"
    echo "  pytorch-finetune"
    echo ""

    # Start PyTorch container with HuggingFace dependencies for fine-tuning
    pytorch-finetune() {
      echo "Starting PyTorch fine-tuning container..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        -v "$PWD:/workspace" \
        -w /workspace \
        nvcr.io/nvidia/pytorch:25.11-py3 \
        /bin/bash -c "pip install transformers peft datasets trl bitsandbytes && exec /bin/bash"
    }

    export -f pytorch-finetune
  '';
}
