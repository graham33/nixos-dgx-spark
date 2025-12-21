{ mkShell
, fetchFromGitHub
, git
, python3
}:

let
  # Fetch NVIDIA DGX Spark Playbooks repository
  dgxSparkPlaybooks = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "dgx-spark-playbooks";
    rev = "70bbbbfab8907551902114809bb143cf3c5b05fd";
    hash = "sha256-h8+qep67lcLRqhRXkyVhLS51P/3qgDWupV/Klzzo0Mc=";
  };

  scriptsPath = "${dgxSparkPlaybooks}/nvidia/pytorch-fine-tune/assets";

  # Python environment with all ML dependencies
  pythonEnv = python3.withPackages (ps: with ps; [
    # Core ML packages
    torch
    transformers
    datasets

    # Fine-tuning packages
    peft
    trl
    bitsandbytes

    # Utilities
    accelerate
    huggingface-hub
  ]);
in
mkShell {
  packages = [
    pythonEnv
    git
  ];

  shellHook = ''
    # Set HuggingFace cache directory
    export HF_HOME="$HOME/.cache/huggingface"

    # Export script paths
    export LLAMA3_8B_LORA_SCRIPT="${scriptsPath}/Llama3_8B_LoRA_finetuning.py"
    export LLAMA3_3B_FULL_SCRIPT="${scriptsPath}/Llama3_3B_full_finetuning.py"

    echo "=== PyTorch Fine-Tuning Nix Playbook ==="
    echo "Native Nix implementation of the NVIDIA PyTorch Fine-Tune Playbook"
    echo ""
    echo "Example usage:"
    echo "  # Authenticate with HuggingFace"
    echo "  hf auth login"
    echo ""
    echo "  # Run LoRA fine-tuning (Llama3.1-8B)"
    echo "  python \$LLAMA3_8B_LORA_SCRIPT"
    echo ""
    echo "  # Run full fine-tuning (Llama3.2-3B)"
    echo "  python \$LLAMA3_3B_FULL_SCRIPT"
    echo ""
    echo "See README.md or https://build.nvidia.com/spark/pytorch-fine-tune for full instructions"
    echo ""
  '';
}
