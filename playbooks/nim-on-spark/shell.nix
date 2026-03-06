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
    echo "=== NIM on Spark Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/nim-llm/instructions"
    echo ""
    echo "NVIDIA NIM provides optimised inference microservices."
    echo ""
    echo "Start a NIM container:"
    echo "  nix run .#nim-on-spark-container"
    echo ""
    echo "OpenAI-compatible API at: http://localhost:8000/v1"
  '';
}
