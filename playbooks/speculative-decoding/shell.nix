{ mkShell
, podman
, curl
, jq
}:

let
  trtllmPort = "8000";
in
mkShell {
  packages = [
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== Speculative Decoding Playbook ==="
    echo "Container: nvcr.io/nvidia/tensorrt-llm/release:1.2.0rc6"
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
    echo "  nix run .#speculative-decoding-eagle3        Start EAGLE-3 server"
    echo "  nix run .#speculative-decoding-draft-target  Start Draft-Target server"
    echo "  nix run .#speculative-decoding-container     Interactive TRT-LLM shell"
    echo "  spec-test-completions                        Test the running server"
    echo ""
    echo "Requires: export HF_TOKEN=<your_huggingface_token>"
    echo ""

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

    export -f spec-test-completions
  '';
}
