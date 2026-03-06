{ mkShell
, curl
, git
, jq
, podman
}:

let
  ragPort = "8080";
  workbenchImage = "nvcr.io/nvidia/ai-workbench/python-basic:1.0.8";
  ragRepo = "https://github.com/NVIDIA/workbench-example-agentic-rag";
in
mkShell {
  packages = [
    curl
    git
    jq
    podman
  ];

  shellHook = ''
    echo "=== RAG Application in AI Workbench Playbook ==="
    echo "Container: ${workbenchImage}"
    echo "Instructions: https://build.nvidia.com/spark/rag-ai-workbench/instructions"
    echo ""
    echo "Prerequisites:"
    echo "  - NVIDIA_API_KEY (https://org.ngc.nvidia.com/setup/api-keys)"
    echo "  - TAVILY_API_KEY (https://tavily.com)"
    echo ""
    echo "To clone the example repository:"
    echo "  rag-clone"
    echo ""
    echo "To start the RAG application:"
    echo "  rag-start"
    echo ""
    echo "To test the RAG application (run in a separate shell):"
    echo "  rag-test \"How do I add an integration in the CLI?\""
    echo ""

    # Clone the agentic RAG example repository
    rag-clone() {
      if [ -d workbench-example-agentic-rag ]; then
        echo "Repository already cloned."
        return
      fi
      echo "Cloning ${ragRepo}..."
      ${git}/bin/git clone ${ragRepo}
    }

    # Start the RAG application container
    rag-start() {
      if [ -z "$NVIDIA_API_KEY" ]; then
        echo "Error: NVIDIA_API_KEY is not set."
        echo "Generate one at https://org.ngc.nvidia.com/setup/api-keys"
        return 1
      fi
      if [ -z "$TAVILY_API_KEY" ]; then
        echo "Error: TAVILY_API_KEY is not set."
        echo "Generate one at https://tavily.com"
        return 1
      fi
      if [ ! -d workbench-example-agentic-rag ]; then
        echo "Repository not found. Run rag-clone first."
        return 1
      fi
      echo "Starting RAG application on port ${ragPort}..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=1g \
        --network host \
        -e NVIDIA_API_KEY="$NVIDIA_API_KEY" \
        -e TAVILY_API_KEY="$TAVILY_API_KEY" \
        -v "$PWD/workbench-example-agentic-rag":/project/code \
        -w /project/code \
        ${workbenchImage} \
        /bin/bash -c "pip install -r requirements.txt && python3 -m chatui"
    }

    # Test the RAG application
    rag-test() {
      local query="''${1:-How do I add an integration in the CLI?}"
      echo "Testing RAG application with query: $query"
      ${curl}/bin/curl -s http://localhost:${ragPort}/api/predict \
        -H "Content-Type: application/json" \
        -d "{\"data\": [\"$query\"]}" | ${jq}/bin/jq '.'
    }

    export -f rag-clone
    export -f rag-start
    export -f rag-test
  '';
}
