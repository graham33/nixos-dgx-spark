# Instructions for AI Agents

## Writing Style

Use British English spelling throughout all documentation and comments.

## Before Committing Changes

Always run the following steps before creating commits:

1. **Run pre-commit hooks** to ensure code quality and formatting:

   ```bash
   nix develop -c pre-commit run --all-files
   ```

2. **Check that all hooks pass** - fix any issues before proceeding

3. **Create the commit** only after all pre-commit checks pass

## Pre-commit Hooks Enabled

This repository uses the following pre-commit hooks:

- `nixpkgs-fmt` - Format Nix files
- `prettier` - Format Markdown files
- `trailing-whitespace` - Remove trailing whitespace
- `end-of-file-fixer` - Ensure files end with newline

## Important Notes

- Pre-commit must be run within the Nix devshell using `nix develop -c`
- All hooks must pass before committing
- The warning "Git tree is dirty" is expected when there are uncommitted changes
- If you get a "No .pre-commit-config.yaml file was found" error when committing, run `nix develop --command true` to install the pre-commit hooks, then retry the commit

## Creating New Playbooks

When creating new playbooks (e.g., converting container-based playbooks to native Nix):

1. **Create playbook directory**: `playbooks/<playbook-name>/`
2. **Create shell.nix**: Define the devShell with required packages
3. **Add to flake.nix**: Register as a devShell entry:
   ```nix
   devShells.<playbook-name> = import ./playbooks/<playbook-name>/shell.nix { inherit pkgs; };
   ```
4. **Use python3Packages**: When referencing Python packages, use `pkgs.python3Packages.<package>` not `python311Packages`
5. **Skip unnecessary env vars**: CUDA paths are typically handled automatically by Nix packages
6. **Never fallback to CPU**: Always use GPU versions of packages when available, never fallback to CPU-only versions
7. **Python version focus**: Focus on Python 3.12+ support, ignore Python 3.11 compatibility

## CUDA Package Overlays

When creating overlays that modify CUDA packages (like cutlass, cudnn, etc.):

1. **Use the `_cuda.extend` pattern** to apply changes across all CUDA package sets:

   ```nix
   final: prev: {
     _cuda = prev._cuda.extend (
       _: prevAttrs: {
         extensions = prevAttrs.extensions ++ [
           (cudaFinal: cudaPrev: {
             packageName = cudaPrev.packageName.overrideAttrs (oldAttrs: {
               # modifications here
             });
           })
         ];
       }
     );
   }
   ```

2. **Examples**: See `overlays/cuda-sbsa.nix` and `overlays/cutlass-4.3.nix`

3. **Do NOT** use the simple overlay pattern `final: prev: { cudaPackages = prev.cudaPackages // { ... } }`
   - This only affects the default cudaPackages and won't propagate to cudaPackages_12, cudaPackages_13, etc.
