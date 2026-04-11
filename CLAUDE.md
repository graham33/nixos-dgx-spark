# nixos-dgx-spark

NixOS module, packages, and devshell-based playbooks for NVIDIA DGX Spark.

## Writing style

Use British English spelling throughout documentation, comments, and commit messages.

## Working with the flake

- **`git add` new and modified files before running `nix develop` or `nix build`.** This is a flake repo, so nix only sees files tracked in git. Untracked files cause confusing "path does not exist" errors at evaluation time.
- The flake outputs are built up from two flake-utils blocks (`eachSystem ["aarch64-linux"]` and `eachDefaultSystem`) merged with `nixpkgs.lib.recursiveUpdate`. Use `recursiveUpdate` (not `//`) when adding more blocks -- shallow merge would silently shadow per-system attrsets.
- To build/test a devShell without entering it: `nix build .#devShells.aarch64-linux.<name>.inputDerivation --builders ""`.

## Pre-commit hooks

The repo uses these hooks: `nixpkgs-fmt`, `prettier` (markdown), `trailing-whitespace`, `end-of-file-fixer`. Prettier in particular reformats markdown tables, so a commit may fail and rewrite a file -- re-stage and re-commit, do not amend blindly.

Run all hooks against all files before committing:

```bash
nix develop -c pre-commit run --all-files
```

If you get "No .pre-commit-config.yaml file was found" when committing, run `nix develop --command true` once to install the hooks, then retry.

## Adding a playbook

Each playbook lives in `playbooks/<name>/` with `shell.nix` and `README.md`. Register it in `flake.nix` under the aarch64-linux block as `devShells.<name> = pkgs.callPackage ./playbooks/<name>/shell.nix { inherit nixglhost; };`. Also add a row to the playbook table in the top-level `README.md`.

When writing the shell.nix:

- Use `pkgs.python3Packages.<package>` (not `python3xxPackages`). Focus on Python 3.12+; ignore older versions.
- Skip unnecessary CUDA env vars -- they're handled automatically by Nix's CUDA packages.
- **Never fall back to CPU-only.** Always use the CUDA/GPU variant of a package; if the GPU build is broken, fix it rather than papering over with a CPU fallback.

## DGX Spark networking quirks

- The dgx-spark NixOS module enables **rootful podman** with `dockerSocket.enable`, exposing `/run/docker.sock`. The Docker API client used by `openshell` reads `DOCKER_HOST` correctly. The `docker` CLI alias (which is podman) ignores `DOCKER_HOST` and shows the user's rootless instance instead -- to inspect rootful containers from the shell, use `CONTAINER_HOST=unix:///run/podman/podman.sock podman --remote ps`.
- The dgx-spark module trusts `podman+` interfaces in the firewall so containers can reach host services (e.g. ollama on `host.docker.internal`). Without this, the NixOS firewall drops the traffic.
