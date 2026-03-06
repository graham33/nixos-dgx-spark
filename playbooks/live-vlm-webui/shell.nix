{ mkShell
, podman
, curl
, jq
}:

let
  webuiPort = "8090";
  ollamaPort = "11434";
  image = "ghcr.io/nvidia-ai-iot/live-vlm-webui:latest";
in
mkShell {
  packages = [
    podman
    curl
    jq
  ];

  shellHook = ''
    echo "=== Live VLM WebUI Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/live-vlm-webui/instructions"
    echo ""
    echo "Commands:"
    echo "  live-vlm-start        Start Ollama + Live VLM WebUI containers"
    echo "  live-vlm-pull-model   Pull the default vision model (gemma3:4b)"
    echo "  live-vlm-models       List available models in Ollama"
    echo "  live-vlm-stop         Stop all Live VLM containers"
    echo ""
    echo "Access the interface at: https://localhost:${webuiPort}"
    echo ""

    live-vlm-start() {
      echo "Starting Ollama server..."
      ${podman}/bin/podman run -d --rm \
        --name ollama \
        --device nvidia.com/gpu=all \
        --network host \
        -v ollama-data:/root/.ollama \
        docker.io/ollama/ollama:latest

      echo "Waiting for Ollama to be ready..."
      for i in $(seq 1 30); do
        if ${curl}/bin/curl -s http://localhost:${ollamaPort}/api/tags >/dev/null 2>&1; then
          echo "Ollama is ready."
          break
        fi
        sleep 1
      done

      echo "Pulling gemma3:4b model (this may take a while on first run)..."
      ${curl}/bin/curl -s http://localhost:${ollamaPort}/api/pull \
        -d '{"name": "gemma3:4b"}' | ${jq}/bin/jq -r '.status // empty'

      echo "Starting Live VLM WebUI..."
      ${podman}/bin/podman run -d --rm \
        --name live-vlm-webui \
        --network host \
        ${image}

      echo ""
      echo "Live VLM WebUI is running at: https://localhost:${webuiPort}"
      echo "Ollama API is available at: http://localhost:${ollamaPort}"
    }

    live-vlm-pull-model() {
      local model="''${1:-gemma3:4b}"
      echo "Pulling model: $model"
      ${curl}/bin/curl -s http://localhost:${ollamaPort}/api/pull \
        -d "{\"name\": \"$model\"}" | ${jq}/bin/jq -r '.status // empty'
    }

    live-vlm-models() {
      ${curl}/bin/curl -s http://localhost:${ollamaPort}/v1/models | ${jq}/bin/jq '.'
    }

    live-vlm-stop() {
      echo "Stopping Live VLM WebUI containers..."
      ${podman}/bin/podman stop live-vlm-webui 2>/dev/null || true
      ${podman}/bin/podman stop ollama 2>/dev/null || true
      echo "Stopped."
    }

    export -f live-vlm-start
    export -f live-vlm-pull-model
    export -f live-vlm-models
    export -f live-vlm-stop
  '';
}
