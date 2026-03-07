{ mkShell
, git
, git-lfs
, podman
}:

mkShell {
  packages = [
    git
    git-lfs
    podman
  ];

  shellHook = ''
    echo "=== Isaac Sim and Isaac Lab Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/isaac/instructions"
    echo ""
    echo "Run Isaac Sim container (headless):"
    echo "  isaac-sim-container"
    echo ""
    echo "Run Isaac Sim container with display:"
    echo "  export DISPLAY=:0 && xhost +local: && isaac-sim-container"
    echo ""
    echo "Build Isaac Sim from source (recommended for DGX Spark):"
    echo "  git clone --depth=1 --recursive https://github.com/isaac-sim/IsaacSim"
    echo "  cd IsaacSim && git lfs install && git lfs pull && ./build.sh"
    echo ""
    echo "Note: Isaac Sim requires significant GPU memory."

    isaac-sim-container() {
      CACHE_DIR="''${HOME}/docker/isaac-sim"
      mkdir -p "$CACHE_DIR/cache/main" \
               "$CACHE_DIR/cache/computecache" \
               "$CACHE_DIR/logs" \
               "$CACHE_DIR/config" \
               "$CACHE_DIR/data" \
               "$CACHE_DIR/pkg"

      DISPLAY_FLAGS=""
      if [ -n "''${DISPLAY:-}" ]; then
        DISPLAY_FLAGS="-e DISPLAY -v $HOME/.Xauthority:/isaac-sim/.Xauthority"
      fi

      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --network host \
        -e "ACCEPT_EULA=Y" \
        -e "PRIVACY_CONSENT=Y" \
        $DISPLAY_FLAGS \
        -v "$CACHE_DIR/cache/main:/isaac-sim/.cache:rw" \
        -v "$CACHE_DIR/cache/computecache:/isaac-sim/.nv/ComputeCache:rw" \
        -v "$CACHE_DIR/logs:/isaac-sim/.nvidia-omniverse/logs:rw" \
        -v "$CACHE_DIR/config:/isaac-sim/.nvidia-omniverse/config:rw" \
        -v "$CACHE_DIR/data:/isaac-sim/.local/share/ov/data:rw" \
        -v "$CACHE_DIR/pkg:/isaac-sim/.local/share/ov/pkg:rw" \
        nvcr.io/nvidia/isaac-sim:5.1.0 \
        "$@"
    }

    export -f isaac-sim-container
  '';
}
