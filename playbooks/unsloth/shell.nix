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
    echo "  unsloth-start"
    echo ""

    # Launch the Unsloth container with GPU access and HuggingFace cache mounted
    unsloth-start() {
      echo "Starting Unsloth environment..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=8g \
        -v "''${HF_HOME:-$HOME/.cache/huggingface}":/root/.cache/huggingface \
        nvcr.io/nvidia/pytorch:25.11-py3 \
        /usr/bin/bash -c '
          pip install transformers peft hf_transfer "datasets==4.3.0" "trl==0.26.1" && \
          pip install --no-deps unsloth unsloth_zoo bitsandbytes && \
          exec /usr/bin/bash
        '
    }

    export -f unsloth-start
  '';
}
