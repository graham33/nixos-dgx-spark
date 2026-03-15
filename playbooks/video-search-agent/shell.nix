{ mkShell
, fetchFromGitHub
, nixglhost
, podman-compose
, gnused
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
    nixglhost
    podman-compose
    gnused
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

      # podman-compose does not support bash-style conditional parameter
      # expansion (''${VAR:+...}) in volume mounts, so we preprocess the
      # upstream compose file to replace them with simple bind mounts.
      local workdir
      workdir="$(mktemp -d)"
      cp -r ${composeDir}/* "$workdir/"
      chmod -R u+w "$workdir"

      # Copy upstream .env so podman-compose picks up default values
      # (STORAGE_HTTP_PORT, VST paths, etc.) and fix ''${PWD} references
      cp ${composeDir}/.env "$workdir/.env"
      ${gnused}/bin/sed -i \
        -e "s|\''${PWD}|$workdir|g" \
        "$workdir/.env"

      ${gnused}/bin/sed -i \
        -e 's|"''${MODEL_ROOT_DIR:-/dummy}''${MODEL_ROOT_DIR:+:''${MODEL_ROOT_DIR:-}}"|"''${MODEL_ROOT_DIR:-/dev/null}:/dev/null"|g' \
        -e 's|"''${ALERT_REVIEW_MEDIA_BASE_DIR:-/dummy}''${ALERT_REVIEW_MEDIA_BASE_DIR:+:''${ALERT_REVIEW_MEDIA_BASE_DIR:-}}"|"''${ALERT_REVIEW_MEDIA_BASE_DIR}:''${ALERT_REVIEW_MEDIA_BASE_DIR}"|g' \
        -e 's|''${IS_SBSA:+-sbsa}|-sbsa|g' \
        -e '/^  vss-shared-network:/{n;s/external: true/external: false/;}' \
        -e 's|^\(\s*\)runtime: nvidia|\1devices:\n\1  - nvidia.com/gpu=all|' \
        "$workdir/compose.yaml"

      exec ${podman-compose}/bin/podman-compose -f "$workdir/compose.yaml" up
    }

    export -f vss-start
  '';
}
