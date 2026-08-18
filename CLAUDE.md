# nixos-dgx-spark

NixOS module, packages, and devshell-based playbooks for NVIDIA DGX Spark.

## Writing style

Use British English spelling throughout documentation, comments, and commit messages.

## Working with the flake

- **`git add` new and modified files before running `nix develop` or `nix build`.** This is a flake repo, so nix only sees files tracked in git. Untracked files cause confusing "path does not exist" errors at evaluation time.
- The flake uses flake-parts: system-independent outputs (nixosModules, overlays, templates, nixosConfigurations) live in the `flake` block, and per-system outputs (packages, devShells, checks, apps) live in `perSystem`. `systems = [ "aarch64-linux" ]` only.
- VM and evaluation tests live in `checks/` (not `tests/`, which holds the pytest suite for the kernel-config scripts). VM tests are built with the plain `testPkgs` (no CUDA, no overlays) so their closures substitute from cache.nixos.org.
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

No CI change is needed: `packages.devshell-closures` is derived from `config.devShells`, so registering the shell also enrols it in the label-gated `full-build` job.

When writing the shell.nix:

- Use `pkgs.python3Packages.<package>` (not `python3xxPackages`). Focus on Python 3.12+; ignore older versions.
- Skip unnecessary CUDA env vars -- they're handled automatically by Nix's CUDA packages.
- **Never fall back to CPU-only.** Always use the CUDA/GPU variant of a package; if the GPU build is broken, fix it rather than papering over with a CPU fallback.

## CI and automated updates

- The weekly flake.lock update PRs are opened with a PAT (`FLAKE_UPDATE_TOKEN`) precisely so CI runs on them, and the update workflow automatically posts an `@claude` brief on each one: fix CI failures first, then audit local workarounds/TODOs (overlays/fixes.nix, patches/, pins, disabled tests) for ones made obsolete by the bump. Commenting `@claude` on any issue or PR also triggers the Claude workflow.
- The label-gated `full-build` job covers the usb-image, the boot VM test, and `packages.devshell-closures` (every devShell's build inputs, plus a weights-free comfyui). It is the only job that builds CUDA torch and vllm.
- The Claude workflow runs on an ARM runner with nix installed and nixbuild.net configured as a remote builder (plain `nix build` dispatches remotely), plus the cachix/flox caches. Agent runs must never build expensive outputs (usb-image, the kernel, vllm, CUDA devShells) -- CI's label-gated full-build job covers the kernel.
- Pushes made by the Claude workflow use the default `GITHUB_TOKEN`, which does **not** re-trigger CI. To get a fresh CI run on such a PR, close and reopen it, or push an empty commit.

## DGX Spark networking quirks

- The dgx-spark NixOS module enables **rootful podman** with `dockerSocket.enable`, exposing `/run/docker.sock`. The Docker API client used by `openshell` reads `DOCKER_HOST` correctly. The `docker` CLI alias (which is podman) ignores `DOCKER_HOST` and shows the user's rootless instance instead -- to inspect rootful containers from the shell, use `CONTAINER_HOST=unix:///run/podman/podman.sock podman --remote ps`.
- The dgx-spark module trusts `podman+` interfaces in the firewall so containers can reach host services (e.g. ollama on `host.docker.internal`). Without this, the NixOS firewall drops the traffic.
