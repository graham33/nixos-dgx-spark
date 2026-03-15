{ mkShell
, curl
, fetchFromGitHub
, jq
, nixglhost
, podman
}:

let
  ragPort = "8080";
  workbenchImage = "nvcr.io/nvidia/ai-workbench/python-basic:1.0.8";
  ragWorkbenchSrc = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "workbench-example-agentic-rag";
    rev = "a40e9742c8f473c0785742317cb8e0f23290b9b3";
    hash = "sha256-mYsXNvUiXqOX2epC5CmE15jIIoWEVe6rUwItosNavOM=";
  };
in
mkShell {
  packages = [
    curl
    jq
    nixglhost
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
    echo "Source available at: ${ragWorkbenchSrc}"
    echo ""
    echo "To start the RAG application:"
    echo "  rag-start"
    echo ""
    echo "To test the RAG application (run in a separate shell):"
    echo "  rag-test \"How do I add an integration in the CLI?\""
    echo ""

    export RAG_WORKBENCH_SRC="${ragWorkbenchSrc}"

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
      echo "Starting RAG application on port ${ragPort}..."
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=1g \
        --network host \
        -e NVIDIA_API_KEY="$NVIDIA_API_KEY" \
        -e TAVILY_API_KEY="$TAVILY_API_KEY" \
        -v "${ragWorkbenchSrc}":/project/code \
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

    export -f rag-start
    export -f rag-test
  '';
}
