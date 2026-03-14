{ mkShell
, hyperfine
, jq
, podman
}:

let
  vllmPort = "8000";
in
mkShell {
  packages = [
    hyperfine
    jq
    podman
  ];

  shellHook = ''
    echo "=== vLLM NVIDIA DGX Spark Playbook ==="
    echo "Container: nvcr.io/nvidia/vllm:25.09-py3"
    echo "Instructions: https://build.nvidia.com/spark/vllm/instructions"
    echo ""
    echo "To serve Qwen2.5-Math-1.5B-Instruct model:"
    echo "  vllm-serve-qwen-math"
    echo ""
    echo "To test the model (run in a separate shell):"
    echo "  vllm-test-math \"12*17\""
    echo ""
    echo "To pull the latest image:"
    echo "  podman pull nvcr.io/nvidia/vllm:25.09-py3"
    echo ""

    # Create vllm-serve-qwen-math command
    vllm-serve-qwen-math() {
      echo "Starting vLLM server with Qwen2.5-Math-1.5B-Instruct model..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=1g \
        --network host \
        -v "$PWD":/workspace \
        -w /workspace \
        nvcr.io/nvidia/vllm:25.09-py3 \
        vllm serve "Qwen/Qwen2.5-Math-1.5B-Instruct" \
          --gpu-memory-utilization 0.6
    }

    # Create vllm-test-math command
    vllm-test-math() {
      local query="''${1:-12*17}"
      echo "Testing vLLM math model with query: $query"
      curl -s http://localhost:${vllmPort}/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"Qwen/Qwen2.5-Math-1.5B-Instruct\",
          \"messages\": [{\"role\": \"user\", \"content\": \"$query\"}],
          \"max_tokens\": 500
        }" | jq -r '.choices[0].message.content'
    }

    export -f vllm-serve-qwen-math
    export -f vllm-test-math
  '';
}
