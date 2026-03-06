{ mkShell
, podman
, podman-compose
, curl
, git
, jq
}:

mkShell {
  packages = [
    podman
    podman-compose
    curl
    git
    jq
  ];

  shellHook = ''
    echo "=== Multi-Agent Chatbot Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/multi-agent-chatbot/instructions"
    echo ""
    echo "Start the multi-agent chatbot:"
    echo "  nix run .#multi-agent-chatbot-container"
    echo ""
    echo "Memory requirement: ~120 GB of 128 GB DGX Spark RAM"
    echo "Model download: ~114 GB (first run only)"
  '';
}
