{ mkShell
, git
, podman
, podman-compose
, curl
, jq
}:

let
  repoUrl = "https://github.com/NVIDIA/dgx-spark-playbooks.git";
  repoDir = "dgx-spark-playbooks";
  assetsDir = "${repoDir}/nvidia/txt2kg/assets";
in
mkShell {
  packages = [
    git
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
    echo "Commands:"
    echo "  txt2kg-start          Start the pipeline (clones repo if needed)"
    echo "  txt2kg-start-vllm     Start with Neo4j + vLLM backend"
    echo "  txt2kg-stop           Stop all services"
    echo "  txt2kg-pull-model     Pull a model into Ollama (default: llama3.1:8b)"
    echo "  txt2kg-test           Test Ollama is responding"
    echo ""

    txt2kg-clone() {
      if [ ! -d "${assetsDir}" ]; then
        echo "Cloning NVIDIA DGX Spark playbooks..."
        ${git}/bin/git clone --depth 1 ${repoUrl}
      fi
    }

    txt2kg-start() {
      txt2kg-clone
      cd ${assetsDir}
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
      txt2kg-clone
      cd ${assetsDir}
      echo "Starting Neo4j + vLLM stack..."
      ${podman-compose}/bin/podman-compose -f deploy/compose/docker-compose.vllm.yml up -d
      echo ""
      echo "Services:"
      echo "  Web UI:       http://localhost:3001"
      echo "  Neo4j:        http://localhost:7474"
      echo "  vLLM API:     http://localhost:8001"
    }

    txt2kg-stop() {
      if [ -d "${assetsDir}" ]; then
        cd ${assetsDir}
        ${podman-compose}/bin/podman-compose -f deploy/compose/docker-compose.yml down
      else
        echo "Repository not cloned yet; nothing to stop."
      fi
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

    export -f txt2kg-clone
    export -f txt2kg-start
    export -f txt2kg-start-vllm
    export -f txt2kg-stop
    export -f txt2kg-pull-model
    export -f txt2kg-test
  '';
}
