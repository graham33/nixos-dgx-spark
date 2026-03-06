{ mkShell
, git
, podman
, python3Packages
}:

mkShell {
  packages = [
    git
    podman
    (python3Packages.python.withPackages (ps: with ps; [
      jax
    ]))
  ];

  shellHook = ''
    echo "=== Optimised JAX Playbook ==="
    echo "Instructions: https://build.nvidia.com/spark/jax/instructions"
    echo ""
    echo "Container version:"
    echo "  jax-container"
    echo ""
    echo "Nix-native (this shell):"
    echo "  python -c 'import jax; print(jax.devices())'"
    echo ""

    # Build and run NVIDIA optimised JAX container with GPU support
    jax-container() {
      set -euo pipefail
      local WORKDIR
      WORKDIR="$(mktemp -d)"
      trap 'rm -rf "$WORKDIR"' EXIT
      ${git}/bin/git clone --depth 1 https://github.com/NVIDIA/dgx-spark-playbooks "$WORKDIR/playbooks"
      ${podman}/bin/podman build -t jax-on-spark "$WORKDIR/playbooks/nvidia/jax/assets"
      exec ${podman}/bin/podman run --rm -it \
        --device nvidia.com/gpu=all \
        --shm-size=1g \
        --ulimit memlock=-1 \
        --ulimit stack=67108864 \
        -p 8080:8080 \
        jax-on-spark
    }

    export -f jax-container
  '';
}
