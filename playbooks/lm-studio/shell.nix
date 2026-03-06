{ mkShell
, curl
, jq
}:

let
  lmsPort = "1234";
in
mkShell {
  packages = [
    curl
    jq
  ];

  shellHook = ''
    echo "=== LM Studio on DGX Spark Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/lm-studio/instructions"
    echo ""
    echo "Step 1: Install LM Studio CLI (lms):"
    echo "  curl -fsSL https://lmstudio.ai/install.sh | bash"
    echo ""
    echo "Step 2: Start the API server:"
    echo "  lms server start --bind 0.0.0.0 --port ${lmsPort}"
    echo ""
    echo "Step 3: Download and load a model:"
    echo "  lms get openai/gpt-oss-120b"
    echo "  lms load openai/gpt-oss-120b"
    echo ""
    echo "Test from your laptop:"
    echo "  lms-test-server <SPARK_IP>"
    echo "  lms-test-chat <SPARK_IP>"
    echo ""

    # Test server connectivity
    lms-test-server() {
      local host="''${1:-localhost}"
      echo "Testing LM Studio server at $host:${lmsPort}..."
      curl -s "http://$host:${lmsPort}/api/v1/models" | jq
    }

    # Test chat completion
    lms-test-chat() {
      local host="''${1:-localhost}"
      local model="''${2:-openai/gpt-oss-120b}"
      echo "Testing chat completion with $model at $host:${lmsPort}..."
      curl -s "http://$host:${lmsPort}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"$model\",
          \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}],
          \"max_tokens\": 200
        }" | jq -r '.choices[0].message.content'
    }

    export -f lms-test-server
    export -f lms-test-chat
  '';
}
