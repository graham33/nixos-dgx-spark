{ mkShell
, fetchFromGitHub
, podman-compose
, curl
, jq
}:

let
  vssSrc = fetchFromGitHub {
    owner = "NVIDIA-AI-Blueprints";
    repo = "video-search-and-summarization";
    rev = "v2.4.1";
    hash = "sha256-rTF2GV2iYkyyFz3tj+UlSuKZIzm4EMtVhblQAHWODR4=";
  };
  composeDir = "${vssSrc}/deploy/docker/event_reviewer";
in

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
    echo "  vss-start"
    echo ""
    echo "UIs (after startup):"
    echo "  CV UI:              http://localhost:7862"
    echo "  Alert Inspector UI: http://localhost:7860"
    echo ""

    vss-start() {
      local compose_dir="''${1:-${composeDir}}"

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

      exec ${podman-compose}/bin/podman-compose -f "$compose_dir/compose.yaml" up
    }

    export -f vss-start
  '';
}
