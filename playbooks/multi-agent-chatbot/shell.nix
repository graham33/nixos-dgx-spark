{ mkShell
, podman
, podman-compose
, curl
, jq
, fetchFromGitHub
}:

let
  dgxSparkPlaybooks = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "dgx-spark-playbooks";
    rev = "main";
    hash = "sha256-+anAUXQIne2YZWm5CYv1IdM2M2OHd1oXNquVzlHfCwI=";
  };
in
mkShell {
  packages = [
    podman
    podman-compose
    curl
    jq
  ];

  shellHook = ''
    echo "=== Multi-Agent Chatbot Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/multi-agent-chatbot/instructions"
    echo ""
    echo "Start the multi-agent chatbot:"
    echo "  multi-agent-chatbot-start"
    echo ""
    echo "Memory requirement: ~120 GB of 128 GB DGX Spark RAM"
    echo "Model download: ~114 GB (first run only)"
    echo ""

    multi-agent-chatbot-start() {
      set -euo pipefail
      local playbook_dir="${dgxSparkPlaybooks}/nvidia/multi-agent-chatbot/assets"
      local work_dir="''${MULTI_AGENT_CHATBOT_DIR:-$HOME/dgx-spark-playbooks/nvidia/multi-agent-chatbot/assets}"

      mkdir -p "$work_dir"

      if [ ! -d "$work_dir/models" ] || [ -z "$(ls -A "$work_dir/models" 2>/dev/null)" ]; then
        echo "Downloading models (~114 GB, this may take a while)..."
        (cd "$work_dir" && bash "$playbook_dir/model_download.sh")
      fi

      echo "Starting multi-agent chatbot services..."
      echo "Frontend: http://localhost:3000"
      echo "Backend:  http://localhost:8000"
      exec ${podman-compose}/bin/podman-compose \
        --project-directory "$work_dir" \
        -f "$playbook_dir/docker-compose.yml" \
        -f "$playbook_dir/docker-compose-models.yml" \
        up --build
    }

    export -f multi-agent-chatbot-start
  '';
}
