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
    echo "=== LLaMA Factory Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/llama-factory/instructions"
    echo ""
    echo "Start LLaMA Factory with WebUI:"
    echo "  llama-factory-start"
    echo ""
    echo "Access the WebUI at: http://localhost:7860"
    echo ""

    llama-factory-start() {
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --ipc=host \
        --network host \
        -v "''${HUGGINGFACE_HUB_CACHE:-$HOME/.cache/huggingface/hub}":/root/.cache/huggingface/hub \
        -e GRADIO_SERVER_NAME=0.0.0.0 \
        docker.io/hiyouga/llamafactory:latest \
        llamafactory-cli webui
    }

    export -f llama-factory-start
  '';
}
