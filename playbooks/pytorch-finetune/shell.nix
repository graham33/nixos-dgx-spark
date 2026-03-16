{ mkShell
, nixglhost
, podman
, fetchFromGitHub
}:

let
  dgxSparkPlaybooks = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "dgx-spark-playbooks";
    rev = "f2709b8694580c1b23ceb6498b3d321f06d1f826";
    hash = "sha256-N40dW5gnQPOqZsXMjbhPuShsNiinoPPgViPDRg6g1EY=";
  };
  finetuneAssets = "${dgxSparkPlaybooks}/nvidia/pytorch-fine-tune/assets";
in
mkShell {
  packages = [
    nixglhost
    podman
  ];

  shellHook = ''
    echo "=== Fine-tune with PyTorch Playbook ==="
    echo "Container: nvcr.io/nvidia/pytorch:25.11-py3"
    echo "Instructions: https://build.nvidia.com/spark/pytorch-fine-tune/instructions"
    echo ""
    echo "Prerequisites:"
    echo "  1. Accept model terms on HuggingFace (e.g. meta-llama/Llama-3.1-8B)"
    echo "  2. Run 'huggingface-cli login' inside the container with your token"
    echo ""
    echo "Commands:"
    echo "  pytorch-finetune     Start the fine-tuning container with scripts mounted"
    echo ""
    echo "Inside the container, run one of the fine-tuning scripts:"
    echo "  python Llama3_3B_full_finetuning.py"
    echo "  python Llama3_8B_LoRA_finetuning.py"
    echo "  python Llama3_70B_LoRA_finetuning.py"
    echo "  python Llama3_70B_qLoRA_finetuning.py"
    echo ""

    # Start PyTorch container with fine-tuning scripts and HuggingFace dependencies
    pytorch-finetune() {
      echo "Starting PyTorch fine-tuning container..."
      echo "Remember to run 'huggingface-cli login' inside the container."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        -v "${finetuneAssets}:/workspace" \
        -w /workspace \
        nvcr.io/nvidia/pytorch:25.11-py3 \
        /bin/bash -c "pip install transformers peft datasets trl bitsandbytes && exec /bin/bash"
    }

    export -f pytorch-finetune
  '';
}
