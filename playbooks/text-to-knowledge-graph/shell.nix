{ mkShell
, fetchFromGitHub
, podman
, podman-compose
, curl
, jq
, nixglhost
}:

let
  dgxSparkPlaybooks = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "dgx-spark-playbooks";
    rev = "a79c14d8f54021c7fce33057faf4a58ea85b79a9";
    hash = "sha256-+anAUXQIne2YZWm5CYv1IdM2M2OHd1oXNquVzlHfCwI=";
  };
  assetsDir = "${dgxSparkPlaybooks}/nvidia/txt2kg/assets";
in
mkShell {
  packages = [
    nixglhost
    podman
    podman-compose
    curl
    jq
  ];

  shellHook = ''
    echo "=== Text to Knowledge Graph Playbook ==="
    echo "Services: Ollama (LLM) + ArangoDB (graph DB) + Next.js (frontend)"
    echo "Instructions: https://build.nvidia.com/spark/txt2kg/instructions"
    echo ""
    echo "Playbook assets: ${dgxSparkPlaybooks}/nvidia/txt2kg/assets"
    echo ""
    echo "Commands:"
    echo "  txt2kg-start          Start the pipeline"
    echo "  txt2kg-start-vllm     Start with Neo4j + vLLM backend"
    echo "  txt2kg-stop           Stop all services"
    echo "  txt2kg-pull-model     Pull a model into Ollama (default: llama3.1:8b)"
    echo "  txt2kg-test           Test Ollama is responding"
    echo ""

    export TXT2KG_ASSETS_DIR="${assetsDir}"

    txt2kg-start() {
      cd "$TXT2KG_ASSETS_DIR"
      echo "Starting ArangoDB + Ollama stack..."
      ${podman-compose}/bin/podman-compose -f deploy/compose/docker-compose.yml up -d
      echo ""
      echo "Services:"
      echo "  Web UI:     http://localhost:3001"
      echo "  ArangoDB:   http://localhost:8529"
      echo "  Ollama API: http://localhost:11434"
      echo ""
      echo "Next: txt2kg-pull-model to download a model"
    }

    txt2kg-start-vllm() {
      cd "$TXT2KG_ASSETS_DIR"
      echo "Starting Neo4j + vLLM stack..."
      ${podman-compose}/bin/podman-compose -f deploy/compose/docker-compose.vllm.yml up -d
      echo ""
      echo "Services:"
      echo "  Web UI:       http://localhost:3001"
      echo "  Neo4j:        http://localhost:7474"
      echo "  vLLM API:     http://localhost:8001"
    }

    txt2kg-stop() {
      cd "$TXT2KG_ASSETS_DIR"
      ${podman-compose}/bin/podman-compose -f deploy/compose/docker-compose.yml down
    }

    txt2kg-pull-model() {
      local model="''${1:-llama3.1:8b}"
      echo "Pulling model: $model"
      ${podman}/bin/podman exec ollama-compose ollama pull "$model"
    }

    txt2kg-test() {
      echo "Testing Ollama API..."
      ${curl}/bin/curl -s http://localhost:11434/api/tags | ${jq}/bin/jq .
    }

    export -f txt2kg-start
    export -f txt2kg-start-vllm
    export -f txt2kg-stop
    export -f txt2kg-pull-model
    export -f txt2kg-test
  '';
}
