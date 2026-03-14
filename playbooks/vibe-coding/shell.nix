{ mkShell
, podman
, curl
, jq
, vscode
, nixglhost
}:

mkShell {
  packages = [
    nixglhost
    podman
    curl
    jq
    vscode
  ];

  shellHook = ''
    echo "=== Vibe Coding in VS Code Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/vibe-coding/instructions"
    echo ""
    echo "Start the Ollama backend:"
    echo "  vibe-coding-start"
    echo ""
    echo "Then install Continue.dev in VS Code and configure it"
    echo "to use Ollama at http://localhost:11434."
    echo ""
    echo "Pull a coding model:"
    echo "  curl http://localhost:11434/api/pull -d '{\"name\": \"gpt-oss:120b\"}'"
    echo ""

    vibe-coding-start() {
      echo "Starting Ollama backend for vibe coding..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --network host \
        -v ollama-data:/root/.ollama \
        docker.io/ollama/ollama
    }

    export -f vibe-coding-start
  '';
}
