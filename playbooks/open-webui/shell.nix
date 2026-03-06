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
    echo "  open-webui-start"
    echo ""
    echo "Access the interface at: http://localhost:8080"
    echo ""
    echo "Pull a model:"
    echo "  curl http://localhost:11434/api/pull -d '{\"name\": \"llama3.2\"}'"
    echo ""

    open-webui-start() {
      echo "Starting Open WebUI with Ollama..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        -p 8080:8080 \
        -v open-webui:/app/backend/data \
        -v open-webui-ollama:/root/.ollama \
        --name open-webui \
        ghcr.io/open-webui/open-webui:ollama
    }

    export -f open-webui-start
  '';
}
