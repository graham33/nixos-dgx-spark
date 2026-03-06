{ mkShell
, podman
, podman-compose
, curl
, jq
}:

mkShell {
  packages = [
    podman
    podman-compose
    curl
    jq
  ];

  shellHook = ''
    echo "=== Video Search and Summarisation Agent Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/vss/instructions"
    echo ""
    echo "Prerequisites:"
    echo "  - Log in to NGC: podman login nvcr.io"
    echo "  - Accept Cosmos-Reason2-8B model terms on Hugging Face"
    echo ""
    echo "Start the VSS Event Reviewer (fully local):"
    echo "  nix run .#video-search-agent-container"
    echo ""
    echo "UIs (after startup):"
    echo "  CV UI:              http://localhost:7862"
    echo "  Alert Inspector UI: http://localhost:7860"
  '';
}
