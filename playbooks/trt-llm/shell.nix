{ mkShell
, nixglhost
, podman
, curl
, jq
}:

let
  containerImage = "nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6";
  defaultModel = "nvidia/Llama-3.1-8B-Instruct-FP4";
  serverPort = "8355";
in
mkShell {
  packages = [
    nixglhost
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== TRT-LLM for Inference Playbook ==="
    echo "Container: ${containerImage}"
    echo "Instructions: https://build.nvidia.com/spark/trt-llm/instructions"
    echo ""
    echo "Available commands:"
    echo "  trt-llm-validate          - Verify TensorRT-LLM installation"
    echo "  trt-llm-quickstart        - Run a quick inference test"
    echo "  trt-llm-serve [MODEL]     - Start OpenAI-compatible server"
    echo "  trt-llm-test [PROMPT]     - Test the running server"
    echo ""
    echo "Default model: ${defaultModel}"
    echo "Set HF_TOKEN before running: export HF_TOKEN=<your-token>"
    echo ""

    trt-llm-validate() {
      echo "Validating TensorRT-LLM installation..."
      ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        ${containerImage} \
        python -c "import tensorrt_llm; print(f'TensorRT-LLM version: {tensorrt_llm.__version__}')"
    }

    trt-llm-quickstart() {
      local model="''${1:-${defaultModel}}"
      echo "Running quickstart with model: $model"
      ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --network host \
        -e HF_TOKEN="$HF_TOKEN" \
        -e MODEL_HANDLE="$model" \
        -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
        ${containerImage} \
        bash -c 'hf download $MODEL_HANDLE && \
          python examples/llm-api/quickstart_advanced.py \
            --model_dir $MODEL_HANDLE \
            --prompt "Paris is great because" \
            --max_tokens 64'
    }

    trt-llm-serve() {
      local model="''${1:-${defaultModel}}"
      echo "Starting TRT-LLM server with model: $model on port ${serverPort}..."
      exec ${podman}/bin/podman run --name trtllm_llm_server --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --network host \
        -e HF_TOKEN="$HF_TOKEN" \
        -e MODEL_HANDLE="$model" \
        -v "$HOME/.cache/huggingface/:/root/.cache/huggingface/" \
        -v "${./extra-llm-api-config.yml}:/extra-llm-api-config.yml:ro" \
        ${containerImage} \
        bash -c 'hf download $MODEL_HANDLE && \
          trtllm-serve "$MODEL_HANDLE" \
            --max_batch_size 64 \
            --trust_remote_code \
            --port ${serverPort} \
            --extra_llm_api_options /extra-llm-api-config.yml'
    }

    trt-llm-test() {
      local prompt="''${1:-Hello, how are you?}"
      echo "Testing TRT-LLM server with prompt: $prompt"
      curl -s http://localhost:${serverPort}/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"${defaultModel}\",
          \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
          \"max_tokens\": 256
        }" | jq -r '.choices[0].message.content'
    }

    export -f trt-llm-validate
    export -f trt-llm-quickstart
    export -f trt-llm-serve
    export -f trt-llm-test
  '';
}
