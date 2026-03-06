{ mkShell
, podman
, curl
, jq
}:

mkShell {
  packages = [
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== NVFP4 Quantisation Playbook ==="
    echo "Container: nvcr.io/nvidia/tensorrt-llm/release:spark-single-gpu-dev"
    echo "Instructions: https://build.nvidia.com/spark/nvfp4-quantization/instructions"
    echo ""
    echo "NVFP4 quantisation reduces model size with minimal quality loss."
    echo ""
    echo "Start the quantisation environment:"
    echo "  nvfp4-start"
    echo ""

    # Start the NVFP4 TensorRT-LLM container
    nvfp4-start() {
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "./output_models:/workspace/output_models" \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        ''${HF_TOKEN:+-e HF_TOKEN="$HF_TOKEN"} \
        nvcr.io/nvidia/tensorrt-llm/release:spark-single-gpu-dev \
        /bin/bash
    }

    export -f nvfp4-start
  '';
}
