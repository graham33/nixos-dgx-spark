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
    echo "=== Vibe Coding in VS Code Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/vibe-coding/instructions"
    echo ""
    echo "Start the Ollama backend:"
    echo "  nix run .#vibe-coding-container"
    echo ""
    echo "Then install Continue.dev in VS Code and configure it"
    echo "to use Ollama at http://localhost:11434."
    echo ""
    echo "Pull a coding model:"
    echo "  curl http://localhost:11434/api/pull -d '{\"name\": \"gpt-oss:120b\"}'"
  '';
}
