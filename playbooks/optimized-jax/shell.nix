{ mkShell
, podman
, python3Packages
}:

mkShell {
  packages = [
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
    echo "  nix run .#optimized-jax-container"
    echo ""
    echo "Nix-native (this shell):"
    echo "  python -c 'import jax; print(jax.devices())'"
  '';
}
