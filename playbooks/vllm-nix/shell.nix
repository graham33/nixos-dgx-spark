{ mkShell
, curl
, hyperfine
, jq
, python3
, vllm
}:

let
  vllmPort = "8000";
in
mkShell {
  packages = [
    curl
    hyperfine
    jq
    python3
    vllm
  ];

  shellHook = ''
    echo "=== vLLM Nix Playbook ==="
    echo "Using vLLM from nixpkgs directly (no containers)"
    echo ""
    echo "To serve Qwen2.5-Math-1.5B-Instruct model:"
    echo "  vllm-serve-qwen-math"
    echo ""
    echo "To test the model (run in a separate shell):"
    echo "  vllm-test-math \"12*17\""
    echo ""

    # Create vllm-serve-qwen-math command
    vllm-serve-qwen-math() {
      echo "Starting vLLM server with Qwen2.5-Math-1.5B-Instruct model..."
      exec vllm serve "Qwen/Qwen2.5-Math-1.5B-Instruct" \
        --host 0.0.0.0 \
        --port ${vllmPort} \
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
