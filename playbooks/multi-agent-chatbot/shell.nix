{ mkShell
, nixglhost
, podman
, podman-compose
, curl
, jq
, gnused
, fetchFromGitHub
}:

let
  dgxSparkPlaybooks = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "dgx-spark-playbooks";
    rev = "f2709b8694580c1b23ceb6498b3d321f06d1f826";
    hash = "sha256-N40dW5gnQPOqZsXMjbhPuShsNiinoPPgViPDRg6g1EY=";
  };
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
      local src_dir="${dgxSparkPlaybooks}/nvidia/multi-agent-chatbot/assets"
      local work_dir="''${MULTI_AGENT_CHATBOT_DIR:-$PWD/multi-agent-chatbot-workspace}"

      mkdir -p "$work_dir"

      # Copy source to mutable work dir so podman can build containers.
      # Remove stale package-lock.json to avoid npm integrity checksum
      # errors from upstream canary next.js versions.
      for d in backend frontend; do
        if [ ! -d "$work_dir/$d" ]; then
          cp -r "$src_dir/$d" "$work_dir/$d"
          chmod -R u+w "$work_dir/$d"
        fi
      done
      rm -f "$work_dir/frontend/package-lock.json"
      for f in docker-compose.yml docker-compose-models.yml model_download.sh Dockerfile.llamacpp; do
        cp -f "$src_dir/$f" "$work_dir/$f"
      done

      # Fix upstream bug: /frontend is an absolute path that doesn't exist;
      # should be ./frontend for the bind mount to work.
      ${gnused}/bin/sed -i 's|- /frontend:|- ./frontend:|' "$work_dir/docker-compose.yml"

      if [ ! -d "$work_dir/models" ] || [ -z "$(ls -A "$work_dir/models" 2>/dev/null)" ]; then
        echo "Downloading models (~114 GB, this may take a while)..."
        (cd "$work_dir" && bash "$work_dir/model_download.sh")
      fi

      echo "Starting multi-agent chatbot services..."
      echo "Frontend: http://localhost:3000"
      echo "Backend:  http://localhost:8000"
      cd "$work_dir"
      exec ${podman-compose}/bin/podman-compose \
        -f "$work_dir/docker-compose.yml" \
        -f "$work_dir/docker-compose-models.yml" \
        up --build
    }

    export -f multi-agent-chatbot-start
  '';
}
