{ mkShell
, podman-compose
, curl
, git
, jq
}:

mkShell {
  packages = [
    podman-compose
    curl
    git
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
      local playbook_dir="''${MULTI_AGENT_CHATBOT_DIR:-$HOME/dgx-spark-playbooks/nvidia/multi-agent-chatbot/assets}"

      if [ ! -d "$playbook_dir" ]; then
        echo "Cloning NVIDIA DGX Spark playbooks..."
        ${git}/bin/git clone https://github.com/NVIDIA/dgx-spark-playbooks "$HOME/dgx-spark-playbooks"
      fi

      cd "$playbook_dir"

      if [ ! -d models ] || [ -z "$(ls -A models 2>/dev/null)" ]; then
        echo "Downloading models (~114 GB, this may take a while)..."
        chmod +x model_download.sh
        ./model_download.sh
      fi

      echo "Starting multi-agent chatbot services..."
      echo "Frontend: http://localhost:3000"
      echo "Backend:  http://localhost:8000"
      exec ${podman-compose}/bin/podman-compose \
        -f docker-compose.yml \
        -f docker-compose-models.yml \
        up --build
    }

    export -f multi-agent-chatbot-start
  '';
}
