{ mkShell
, nixglhost
, python3
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

  pythonEnv = python3.withPackages (ps: with ps; [
    torch
    transformers
    peft
    datasets
    trl
    bitsandbytes
    accelerate
    huggingface-hub
  ]);
in
mkShell {
  packages = [
    nixglhost
    pythonEnv
  ];

  shellHook = ''
    echo "=== PyTorch Fine-tuning (Nix) Playbook ==="
    echo "All dependencies installed via Nix (no containers)"
    echo "Instructions: https://build.nvidia.com/spark/pytorch-fine-tune/instructions"
    echo ""
    echo "Prerequisites:"
    echo "  1. Accept model terms on HuggingFace (e.g. meta-llama/Llama-3.1-8B)"
    echo "  2. Run 'huggingface-cli login' with your token"
    echo ""
    echo "Commands:"
    echo "  pytorch-finetune-setup   Copy training scripts to current directory"
    echo ""
    echo "Training scripts (after setup):"
    echo "  python Llama3_3B_full_finetuning.py"
    echo "  python Llama3_8B_LoRA_finetuning.py"
    echo "  python Llama3_70B_LoRA_finetuning.py"
    echo "  python Llama3_70B_qLoRA_finetuning.py"
    echo ""

    pytorch-finetune-setup() {
      echo "Copying NVIDIA fine-tuning scripts to current directory..."
      cp -rn ${finetuneAssets}/* ./ 2>/dev/null || true
      chmod -R u+w .
      echo "Done. Training scripts are ready in $PWD"
    }

    if [ ! -f /etc/NIXOS ]; then
      python() { nixglhost ${pythonEnv}/bin/python "$@"; }
      export -f python
    fi

    export -f pytorch-finetune-setup
  '';
}
