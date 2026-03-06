{ mkShell
, podman
}:

mkShell {
  packages = [
    podman
  ];

  shellHook = ''
    echo "=== Unsloth on DGX Spark Playbook ==="
    echo "Container: nvcr.io/nvidia/pytorch:25.11-py3"
    echo "Instructions: https://build.nvidia.com/spark/unsloth/instructions"
    echo ""
    echo "Unsloth provides 2x faster LoRA fine-tuning with 60% less memory."
    echo ""
    echo "HuggingFace cache: ''${HF_HOME:-$HOME/.cache/huggingface}"
    echo ""
    echo "Start the Unsloth environment:"
    echo "  nix run .#unsloth-container"
  '';
}
