{ mkShell
, podman
, curl
, jq
}:

let
  trtllmPort = "8000";
  trtllmImage = "nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6";
in
mkShell {
  packages = [
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== Speculative Decoding Playbook ==="
    echo "Container: ${trtllmImage}"
    echo "Instructions: https://build.nvidia.com/spark/speculative-decoding/instructions"
    echo ""
    echo "Speculative decoding uses a small draft model to accelerate"
    echo "a larger target model for faster inference on GPU."
    echo ""
    echo "Methods:"
    echo "  EAGLE-3       - Built-in drafting head (openai/gpt-oss-120b)"
    echo "  Draft-Target  - Separate draft model (Llama-3.1-8B -> Llama-3.3-70B)"
    echo ""
    echo "Commands:"
    echo "  spec-eagle3              Start EAGLE-3 server"
    echo "  spec-draft-target        Start Draft-Target server"
    echo "  spec-shell               Interactive TRT-LLM container shell"
    echo "  spec-test-completions    Test the running server"
    echo ""
    echo "Requires: export HF_TOKEN=<your_huggingface_token>"
    echo ""

    # Start EAGLE-3 speculative decoding server
    spec-eagle3() {
      if [ -z "$HF_TOKEN" ]; then
        echo "Error: HF_TOKEN environment variable must be set."
        echo "Get a token from https://huggingface.co/settings/tokens"
        return 1
      fi
      exec ${podman}/bin/podman run \
        -e HF_TOKEN="$HF_TOKEN" \
        -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
        --rm -it --ulimit memlock=-1 --ulimit stack=67108864 \
        --device nvidia.com/gpu=all --ipc=host --network host \
        ${trtllmImage} \
        bash -c '
          hf download openai/gpt-oss-120b && \
          hf download nvidia/gpt-oss-120b-Eagle3-long-context \
              --local-dir /opt/gpt-oss-120b-Eagle3/ && \
          cp ${./eagle3-extra-llm-api-config.yml} /tmp/extra-llm-api-config.yml && \
          export TIKTOKEN_ENCODINGS_BASE="/tmp/harmony-reqs" && \
          mkdir -p $TIKTOKEN_ENCODINGS_BASE && \
          wget -P $TIKTOKEN_ENCODINGS_BASE https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken && \
          wget -P $TIKTOKEN_ENCODINGS_BASE https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken
          trtllm-serve openai/gpt-oss-120b \
            --backend pytorch --tp_size 1 \
            --max_batch_size 1 \
            --extra_llm_api_options /tmp/extra-llm-api-config.yml'
    }

    # Start Draft-Target speculative decoding server
    spec-draft-target() {
      if [ -z "$HF_TOKEN" ]; then
        echo "Error: HF_TOKEN environment variable must be set."
        echo "Get a token from https://huggingface.co/settings/tokens"
        return 1
      fi
      exec ${podman}/bin/podman run \
        -e HF_TOKEN="$HF_TOKEN" \
        -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
        --rm -it --ulimit memlock=-1 --ulimit stack=67108864 \
        --device nvidia.com/gpu=all --ipc=host --network host \
        ${trtllmImage} \
        bash -c "
          hf download nvidia/Llama-3.3-70B-Instruct-FP4 && \
          hf download nvidia/Llama-3.1-8B-Instruct-FP4 \
              --local-dir /opt/Llama-3.1-8B-Instruct-FP4/ && \
          cp ${./draft-target-extra-llm-api-config.yml} ./extra-llm-api-config.yml && \
          trtllm-serve nvidia/Llama-3.3-70B-Instruct-FP4 \
            --backend pytorch --tp_size 1 \
            --max_batch_size 1 \
            --kv_cache_free_gpu_memory_fraction 0.9 \
            --extra_llm_api_options ./extra-llm-api-config.yml
        "
    }

    # Start an interactive TensorRT-LLM container shell
    spec-shell() {
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all --ipc=host --network host \
        -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
        ${trtllmImage} /bin/bash
    }

    # Test the running speculative decoding server
    spec-test-completions() {
      local model="''${1:-openai/gpt-oss-120b}"
      local prompt="''${2:-San Francisco is a}"
      echo "Testing speculative decoding server with model: $model"
      curl -s -X POST http://localhost:${trtllmPort}/v1/completions \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"$model\",
          \"prompt\": \"$prompt\",
          \"max_tokens\": 300
        }" | jq .
    }

    export -f spec-eagle3
    export -f spec-draft-target
    export -f spec-shell
    export -f spec-test-completions
  '';
}
