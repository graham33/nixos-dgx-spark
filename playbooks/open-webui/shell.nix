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
    echo "=== Open WebUI with Ollama Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/open-webui/instructions"
    echo ""
    echo "Start Open WebUI with Ollama:"
    echo "  nix run .#open-webui-container"
    echo ""
    echo "Access the interface at: http://localhost:8080"
    echo ""
    echo "Pull a model:"
    echo "  curl http://localhost:11434/api/pull -d '{\"name\": \"llama3.2\"}'"
  '';
}
