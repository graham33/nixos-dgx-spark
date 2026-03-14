{ mkShell
, podman
, curl
, jq
, nixglhost
}:

let
  containerImage = "nvcr.io/nvidia/tensorrt-llm/release:spark-single-gpu-dev";
  defaultModel = "deepseek-ai/DeepSeek-R1-Distill-Llama-8B";
  serverPort = "8000";
in
mkShell {
  packages = [
    nixglhost
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== NVFP4 Quantisation Playbook ==="
    echo "Container: ${containerImage}"
    echo "Instructions: https://build.nvidia.com/spark/nvfp4-quantization/instructions"
    echo ""
    echo "NVFP4 quantisation reduces model size with minimal quality loss."
    echo "Cut memory use ~3.5x vs FP16 and ~1.8x vs FP8."
    echo ""
    echo "Available commands:"
    echo "  nvfp4-start                - Start an interactive container shell"
    echo "  nvfp4-quantize [MODEL]     - Quantize a model to NVFP4 format"
    echo "  nvfp4-validate             - Check quantized model output files"
    echo "  nvfp4-test [MODEL]         - Test-load the quantized model"
    echo "  nvfp4-serve [MODEL]        - Serve the model with OpenAI-compatible API"
    echo "  nvfp4-chat [PROMPT]        - Send a chat request to the running server"
    echo "  nvfp4-cleanup              - Remove output models and cached data"
    echo ""
    echo "Default model: ${defaultModel}"
    echo "Set HF_TOKEN before running: export HF_TOKEN=<your-token>"
    echo ""

    # Start an interactive container shell
    nvfp4-start() {
      mkdir -p ./output_models
      mkdir -p "$HOME/.cache/huggingface"
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "./output_models:/workspace/output_models" \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        ''${HF_TOKEN:+-e HF_TOKEN="$HF_TOKEN"} \
        ${containerImage} \
        /bin/bash
    }

    # Quantize a model to NVFP4 using TensorRT Model Optimizer
    nvfp4-quantize() {
      local model="''${1:-${defaultModel}}"
      echo "Quantizing model: $model to NVFP4 format..."
      echo "This may take 45-90 minutes depending on network speed and model size."
      mkdir -p ./output_models
      mkdir -p "$HOME/.cache/huggingface"
      ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "./output_models:/workspace/output_models" \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        ''${HF_TOKEN:+-e HF_TOKEN="$HF_TOKEN"} \
        ${containerImage} \
        bash -c "
          git clone -b 0.35.0 --single-branch https://github.com/NVIDIA/Model-Optimizer.git /app/TensorRT-Model-Optimizer && \
          cd /app/TensorRT-Model-Optimizer && pip install -e '.[dev]' && \
          export ROOT_SAVE_PATH='/workspace/output_models' && \
          /app/TensorRT-Model-Optimizer/examples/llm_ptq/scripts/huggingface_example.sh \
          --model '$model' \
          --quant nvfp4 \
          --tp 1 \
          --export_fmt hf
        "
    }

    # Check that quantized model output files exist
    nvfp4-validate() {
      echo "Checking output_models/ for quantized model files..."
      if [ ! -d "./output_models" ]; then
        echo "Error: output_models/ directory not found. Run nvfp4-quantize first."
        return 1
      fi
      echo ""
      echo "Directory contents:"
      ls -la ./output_models/
      echo ""
      echo "Model files:"
      find ./output_models/ -name "*.bin" -o -name "*.safetensors" -o -name "config.json"
    }

    # Test-load the quantized model with a sample prompt
    nvfp4-test() {
      local model="''${1:-${defaultModel}}"
      local model_slug="''${model##*/}"
      local model_path="./output_models/saved_models_''${model_slug}_nvfp4_hf"
      if [ ! -d "$model_path" ]; then
        echo "Error: Model directory $model_path not found."
        echo "Run nvfp4-quantize first, or pass the model name used during quantization."
        return 1
      fi
      echo "Testing quantized model at: $model_path"
      ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --network host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        -v "$model_path:/workspace/model" \
        ''${HF_TOKEN:+-e HF_TOKEN="$HF_TOKEN"} \
        ${containerImage} \
        bash -c '
          python examples/llm-api/quickstart_advanced.py \
            --model_dir /workspace/model/ \
            --prompt "Paris is great because" \
            --max_tokens 64
        '
    }

    # Serve the quantized model with an OpenAI-compatible API
    nvfp4-serve() {
      local model="''${1:-${defaultModel}}"
      local model_slug="''${model##*/}"
      local model_path="./output_models/saved_models_''${model_slug}_nvfp4_hf"
      if [ ! -d "$model_path" ]; then
        echo "Error: Model directory $model_path not found."
        echo "Run nvfp4-quantize first, or pass the model name used during quantization."
        return 1
      fi
      echo "Starting NVFP4 server with model at: $model_path on port ${serverPort}..."
      exec ${podman}/bin/podman run --name nvfp4_server --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --network host \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
        -v "$model_path:/workspace/model" \
        ''${HF_TOKEN:+-e HF_TOKEN="$HF_TOKEN"} \
        ${containerImage} \
        trtllm-serve /workspace/model \
          --backend pytorch \
          --max_batch_size 4 \
          --port ${serverPort}
    }

    # Send a chat completion request to the running server
    nvfp4-chat() {
      local prompt="''${1:-What is artificial intelligence?}"
      echo "Sending chat request to localhost:${serverPort}..."
      curl -s http://localhost:${serverPort}/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"${defaultModel}\",
          \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
          \"max_tokens\": 256,
          \"temperature\": 0.7
        }" | jq -r '.choices[0].message.content'
    }

    # Remove output models and optionally cached data
    nvfp4-cleanup() {
      echo "Removing output_models/ directory..."
      rm -rf ./output_models
      echo "Done."
      echo ""
      echo "To also remove the Hugging Face cache, run:"
      echo "  rm -rf ~/.cache/huggingface"
      echo ""
      echo "To remove the container image, run:"
      echo "  podman rmi ${containerImage}"
    }

    export -f nvfp4-start
    export -f nvfp4-quantize
    export -f nvfp4-validate
    export -f nvfp4-test
    export -f nvfp4-serve
    export -f nvfp4-chat
    export -f nvfp4-cleanup
  '';
}
