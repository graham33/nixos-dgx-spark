{ mkShell
, nixglhost
, podman
, curl
, jq
, ollama
, openshell
}:

mkShell {
  packages = [
    curl
    jq
    nixglhost
    ollama
    openshell
    podman
  ];

  shellHook = ''
    if [ ! -f /etc/NIXOS ]; then
      if [ ! -f "$HOME/.config/containers/policy.json" ] && [ ! -f /etc/containers/policy.json ]; then
        echo "ERROR: No container policy.json found. Podman will not be able to pull images."
        echo "Fix with: mkdir -p ~/.config/containers && cp ${../../containers/policy.json} ~/.config/containers/policy.json"
        return 1
      fi
      if [ ! -f "$HOME/.config/containers/registries.conf" ] && [ ! -f /etc/containers/registries.conf ]; then
        echo "ERROR: No registries.conf found. Podman will not be able to resolve short image names."
        echo "Fix with: mkdir -p ~/.config/containers && cp ${../../containers/registries.conf} ~/.config/containers/registries.conf"
        return 1
      fi
      if [ ! -f /etc/cdi/nvidia.yaml ] && [ ! -f /var/run/cdi/nvidia-container-toolkit.json ]; then
        echo "ERROR: No CDI spec found. Podman will not be able to access GPUs."
        echo "Fix with: sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml"
        return 1
      fi
    fi

    # Point OpenShell at the rootful podman socket via docker compat.
    # k3s requires rootful container networking so the gateway can reach
    # host services like Ollama.
    if [ -z "''${DOCKER_HOST:-}" ]; then
      if [ -S "/run/docker.sock" ]; then
        export DOCKER_HOST="unix:///run/docker.sock"
      elif [ -S "/run/podman/podman.sock" ]; then
        export DOCKER_HOST="unix:///run/podman/podman.sock"
      else
        echo "WARNING: No rootful podman socket found."
        echo "OpenShell gateway requires rootful podman for k3s support."
        echo "Enable with: virtualisation.podman.dockerSocket.enable = true;"
      fi
    fi

    echo "=== OpenShell Playbook ==="
    echo "Secure Long Running AI Agents with OpenShell on DGX Spark"
    echo "Instructions: https://build.nvidia.com/spark/openshell"
    echo ""
    echo "Setup (run these in order):"
    echo "  1. openshell-gpu-check      Verify GPU access via podman"
    echo "  2. openshell-ollama-start   Start Ollama for local inference"
    echo "  3. openshell-gateway-start  Deploy the OpenShell gateway"
    echo "  4. openshell-provider-create  Create local Ollama provider"
    echo "  5. openshell-inference-set  Configure inference routing"
    echo "  6. openshell-sandbox-create Launch OpenClaw in a sandbox"
    echo ""
    echo "Other commands:"
    echo "  openshell-status            Show gateway and sandbox status"
    echo "  openshell-cleanup           Remove sandbox, provider, and gateway"
    echo ""
    echo "Memory requirement: ~70 GB for nemotron-3-super:120b"
    echo "                    ~25 GB for nemotron-3-nano"
    echo ""

    # Step 1: Verify GPU access via podman
    openshell-gpu-check() {
      echo "Checking GPU access via podman..."
      ${podman}/bin/podman run --rm \
        --device nvidia.com/gpu=all \
        ubuntu nvidia-smi
    }

    # Step 2: Start Ollama listening on all interfaces
    openshell-ollama-start() {
      local ollama_cmd="${ollama}/bin/ollama"
      if [ ! -f /etc/NIXOS ]; then
        ollama_cmd="${nixglhost}/bin/nixglhost ${ollama}/bin/ollama"
      fi
      echo "Starting Ollama on 0.0.0.0:11434..."
      echo "Pull a model first if needed, e.g.:"
      echo "  ollama pull nemotron-3-super:120b"
      echo ""
      OLLAMA_HOST=0.0.0.0 exec $ollama_cmd serve
    }

    # Step 3: Start the OpenShell gateway
    openshell-gateway-start() {
      echo "Starting OpenShell gateway (this may take a few minutes on first run)..."
      echo "Note: OpenShell uses Docker internally. Podman docker-compat provides this."
      ${openshell}/bin/openshell gateway start
      ${openshell}/bin/openshell status
    }

    # Step 4: Create the local Ollama inference provider
    openshell-provider-create() {
      # Use host.docker.internal which rootful podman maps to the host.
      local host="''${OPENSHELL_HOST_IP:-host.docker.internal}"
      echo "Using host: $host"
      echo "Override with: export OPENSHELL_HOST_IP=<your-ip>"
      echo ""
      ${openshell}/bin/openshell provider create \
        --name local-ollama \
        --type openai \
        --credential OPENAI_API_KEY=not-needed \
        --config "OPENAI_BASE_URL=http://$host:11434/v1"
      echo ""
      ${openshell}/bin/openshell provider list
    }

    # Step 5: Configure inference routing
    # Usage: openshell-inference-set [model]
    openshell-inference-set() {
      local model="''${1:-nemotron-3-nano}"
      shift 2>/dev/null || true
      echo "Setting inference to provider local-ollama, model $model..."
      echo "(Skipping verification -- first request loads the model which can be slow)"
      ${openshell}/bin/openshell inference set \
        --provider local-ollama \
        --model "$model" \
        --no-verify \
        "$@"
      echo ""
      ${openshell}/bin/openshell inference get
    }

    # Step 6: Create a sandbox with OpenClaw
    openshell-sandbox-create() {
      local name="''${1:-dgx-demo}"
      echo "Creating sandbox '$name' with OpenClaw..."
      echo "This will launch an interactive onboarding wizard."
      echo ""
      echo "Wizard settings to use:"
      echo "  Setup type: Quickstart"
      echo "  Provider:   Custom Provider"
      echo "  API URL:    https://inference.local/v1"
      echo "  API key:    ollama"
      echo "  Compat:     OpenAI-compatible"
      echo "  Model ID:   nemotron-3-nano (or your model from step 5)"
      echo ""
      exec ${openshell}/bin/openshell sandbox create \
        --keep \
        --forward 18789 \
        --name "$name" \
        --from openclaw \
        -- openclaw-start
    }

    # Show status
    openshell-status() {
      ${openshell}/bin/openshell status
      echo ""
      ${openshell}/bin/openshell inference get 2>/dev/null
      echo ""
      ${openshell}/bin/openshell forward list 2>/dev/null
    }

    # Cleanup everything
    openshell-cleanup() {
      local name="''${1:-dgx-demo}"
      echo "Cleaning up sandbox '$name'..."
      ${openshell}/bin/openshell sandbox delete "$name" 2>/dev/null
      ${openshell}/bin/openshell provider delete local-ollama 2>/dev/null
      ${openshell}/bin/openshell gateway stop
      echo ""
      echo "Gateway stopped. To permanently destroy it:"
      echo "  openshell gateway destroy"
      echo "To remove Ollama models:"
      echo "  ollama rm <model-name>"
    }

    export -f openshell-gpu-check
    export -f openshell-ollama-start
    export -f openshell-gateway-start
    export -f openshell-provider-create
    export -f openshell-inference-set
    export -f openshell-sandbox-create
    export -f openshell-status
    export -f openshell-cleanup
  '';
}
