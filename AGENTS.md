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
