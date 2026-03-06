{ mkShell
, podman-compose
, curl
, jq
}:

mkShell {
  packages = [
    podman-compose
    curl
    jq
  ];

  shellHook = ''
    echo "=== Video Search and Summarisation Agent Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/vss/instructions"
    echo ""
    echo "Prerequisites:"
    echo "  - Log in to NGC: podman login nvcr.io"
    echo "  - Accept Cosmos-Reason2-8B model terms on Hugging Face"
    echo ""
    echo "Start the VSS Event Reviewer (fully local):"
    echo "  vss-start [path/to/compose/dir]"
    echo ""
    echo "UIs (after startup):"
    echo "  CV UI:              http://localhost:7862"
    echo "  Alert Inspector UI: http://localhost:7860"
    echo ""

    vss-start() {
      local compose_dir="''${1:-.}"

      if [ ! -f "$compose_dir/docker-compose.yml" ] && [ ! -f "$compose_dir/compose.yaml" ]; then
        echo "Error: No docker-compose.yml or compose.yaml found in $compose_dir"
        echo "Clone the VSS repository first — see the playbook README for details."
        return 1
      fi

      export IS_SBSA=1
      export VLM_DEFAULT_NUM_FRAMES_PER_CHUNK=8
      export ALERT_REVIEW_MEDIA_BASE_DIR="''${ALERT_REVIEW_MEDIA_BASE_DIR:-/tmp/alert-media-dir}"

      echo "=== Video Search and Summarisation Agent ==="
      echo "Starting VSS Event Reviewer (fully local)..."
      echo ""
      echo "UIs available after startup:"
      echo "  CV UI:              http://localhost:7862"
      echo "  Alert Inspector UI: http://localhost:7860"
      echo ""

      exec ${podman-compose}/bin/podman-compose -f "$compose_dir/docker-compose.yml" up
    }

    export -f vss-start
  '';
}
