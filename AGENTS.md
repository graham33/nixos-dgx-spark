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
