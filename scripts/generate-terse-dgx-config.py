#!/usr/bin/env python3
"""
Generate terse NVIDIA DGX kernel configuration by comparing with NixOS baseline.

This script:
1. Builds the NixOS baseline kernel config (NVIDIA kernel source + NixOS common-config)
2. Exports the NVIDIA upstream config using Debian annotations
3. Compares the two and outputs only options where NVIDIA differs from NixOS
4. Generates a terse Nix file with lib.mkForce for differing options

The result is a minimal config that only sets options that need to be changed
from NixOS defaults, making it much more maintainable.

Workflow:
  nvidia-kernel-source.nix  →  fetch-kernel-source.nix  →  annotations export
           ↓
  extract-baseline-config.nix  →  NixOS baseline config
           ↓
  compare configs  →  nvidia-dgx-spark-<version>.nix (terse)
           ↓
  modules/dgx-spark.nix  →  imports and uses the terse config

Regeneration is needed when:
- NVIDIA kernel version changes (update nvidia-kernel-source.nix)
- NVIDIA annotations change (new kernel source checkout)
- NixOS common-config changes (nixpkgs update)
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Set, Tuple


def run_command(cmd, cwd=None, check=True, capture=True):
    """Run a shell command and return the result."""
    print(f"Running: {cmd}")
    result = subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        capture_output=capture,
        text=True,
        check=check
    )
    return result


def eval_nix_kernel_source(nix_file: Path) -> Dict[str, str]:
    """Evaluate nvidia-kernel-source.nix using nix eval to extract version info."""
    nix_expr = f'let src = import {nix_file}; in {{ version = src.nvidiaKernelVersion; rev = src.nvidiaKernelRev; hash = src.nvidiaKernelHash; }}'
    result = run_command(f'nix eval --impure --expr \'{nix_expr}\' --json')

    return json.loads(result.stdout)


def parse_kernel_config(config_text: str) -> Dict[str, str]:
    """Parse a kernel config file and return a dict of CONFIG_OPTION -> value."""
    config = {}

    for line in config_text.splitlines():
        line = line.strip()

        if not line or line.startswith('#'):
            match = re.match(r'^# (CONFIG_\w+) is not set$', line)
            if match:
                config[match.group(1)] = 'n'
            continue

        if line.startswith('CONFIG_') and '=' in line:
            key, value = line.split('=', 1)
            config[key] = value

    return config


def get_nixos_baseline_config(script_dir: Path) -> Dict[str, str]:
    """Build and extract the NixOS baseline kernel configuration."""
    print("\n=== Extracting NixOS baseline config ===")

    nix_file = script_dir / "extract-baseline-config.nix"
    if not nix_file.exists():
        raise FileNotFoundError(f"Baseline extraction script not found: {nix_file}")

    result = run_command(f"nix build --impure --no-link --print-out-paths --file {nix_file}")
    config_path = result.stdout.strip()

    print(f"Baseline config path: {config_path}")

    with open(config_path, 'r') as f:
        config_text = f.read()

    return parse_kernel_config(config_text)


def get_nvidia_kernel_source(script_dir: Path, local_source: Optional[Path] = None) -> Path:
    """
    Get the NVIDIA kernel source path.

    If local_source is provided, use that.
    Otherwise, fetch using Nix.
    """
    if local_source:
        return local_source

    print("\n=== Fetching NVIDIA kernel source via Nix ===")

    nix_file = script_dir / "fetch-kernel-source.nix"
    if not nix_file.exists():
        raise FileNotFoundError(f"Kernel source fetch script not found: {nix_file}")

    result = run_command(f"nix build --impure --no-link --print-out-paths --file {nix_file}")
    source_path = Path(result.stdout.strip())

    print(f"Kernel source path: {source_path}")

    return source_path


def get_nvidia_upstream_config(kernel_source_dir: Path, arch: str, flavour: str) -> Dict[str, str]:
    """Export NVIDIA upstream config using Debian annotations."""
    print("\n=== Extracting NVIDIA upstream config ===")

    kernel_source_path = kernel_source_dir.resolve()

    nvidia_annotations = kernel_source_path / "debian.nvidia-6.17/config/annotations"
    if not nvidia_annotations.exists():
        raise FileNotFoundError(f"NVIDIA annotations not found: {nvidia_annotations}")

    annotation_script = kernel_source_path / "debian/scripts/misc/annotations"
    if not annotation_script.exists():
        raise FileNotFoundError(f"Annotation script not found: {annotation_script}")

    cmd = f"python3 {annotation_script} --file {nvidia_annotations} --arch {arch} --flavour {flavour} --export"
    result = run_command(cmd, cwd=kernel_source_path)

    return parse_kernel_config(result.stdout)


def compare_configs(
    nvidia_config: Dict[str, str],
    nixos_config: Dict[str, str]
) -> Tuple[Dict[str, str], Set[str]]:
    """
    Compare NVIDIA and NixOS configs.

    Returns:
        - diff_options: Dict of options where NVIDIA differs from NixOS (or not in NixOS)
        - nixos_only: Set of options only in NixOS (NVIDIA doesn't set them)
    """
    diff_options = {}
    nixos_only = set()

    nvidia_options = set(nvidia_config.keys())
    nixos_options = set(nixos_config.keys())

    for option in nvidia_options:
        nvidia_val = nvidia_config[option]
        nixos_val = nixos_config.get(option)

        if nixos_val is None:
            diff_options[option] = nvidia_val
        elif nvidia_val != nixos_val:
            diff_options[option] = nvidia_val

    nixos_only = nixos_options - nvidia_options

    return diff_options, nixos_only


def value_to_nix(value: str) -> str:
    """Convert a kernel config value to Nix lib.kernel format."""
    if value == 'y':
        return 'yes'
    elif value == 'n':
        return 'no'
    elif value == 'm':
        return 'module'
    elif value.startswith('"') and value.endswith('"'):
        return f'(freeform {value})'
    elif value.isdigit():
        return f'(freeform "{value}")'
    else:
        return f'(freeform "{value}")'


def generate_terse_nix(
    diff_options: Dict[str, str],
    kernel_version: str,
    output_path: Path,
    excluded_options: list
):
    """Generate a terse Nix file with only differing options."""

    with open(output_path, 'w') as f:
        f.write(f'# Generated NVIDIA DGX Spark kernel configuration (terse)\n')
        f.write(f'# Kernel Version: {kernel_version}\n')
        f.write(f'# Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")}\n')
        f.write(f'#\n')
        f.write(f'# This file contains only options that differ from NixOS defaults.\n')
        f.write(f'# Options matching NixOS defaults are omitted for clarity.\n')
        f.write(f'# Total options: {len(diff_options)}\n\n')

        f.write('{ lib }: with lib.kernel; {\n')

        sorted_options = sorted(diff_options.items())
        count = 0

        for option, value in sorted_options:
            config_name = option.replace('CONFIG_', '')

            if config_name in excluded_options:
                continue

            nix_value = value_to_nix(value)

            if config_name[0].isdigit() or not config_name.replace('_', '').isalnum():
                f.write(f'  "{config_name}" = lib.mkForce {nix_value};\n')
            else:
                f.write(f'  {config_name} = lib.mkForce {nix_value};\n')
            count += 1

        f.write('}\n')

    print(f"\nGenerated terse config with {count} options")
    return count


def main():
    parser = argparse.ArgumentParser(
        description="Generate terse NVIDIA DGX kernel configuration"
    )
    parser.add_argument(
        "--kernel-source",
        default=None,
        help="Path to NVIDIA kernel source directory (default: fetch via Nix)"
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output path for generated Nix file"
    )
    parser.add_argument(
        "--arch",
        default="arm64",
        help="Target architecture (default: arm64)"
    )
    parser.add_argument(
        "--flavour",
        default="arm64-nvidia",
        help="Target flavour (default: arm64-nvidia)"
    )

    args = parser.parse_args()

    script_dir = Path(__file__).parent
    project_root = script_dir.parent

    kernel_source_info = eval_nix_kernel_source(
        project_root / "kernel-configs" / "nvidia-kernel-source.nix"
    )

    if 'version' not in kernel_source_info:
        print("Error: Could not parse kernel version from nvidia-kernel-source.nix")
        return 1

    kernel_version = kernel_source_info['version']
    print(f"Kernel version from nvidia-kernel-source.nix: {kernel_version}")

    if args.output:
        output_path = Path(args.output)
    else:
        output_path = project_root / "kernel-configs" / f"nvidia-dgx-spark-{kernel_version}.nix"

    try:
        nixos_config = get_nixos_baseline_config(script_dir)
        print(f"NixOS baseline config: {len(nixos_config)} options")

        kernel_source_path = get_nvidia_kernel_source(
            script_dir,
            Path(args.kernel_source) if args.kernel_source else None
        )

        nvidia_config = get_nvidia_upstream_config(kernel_source_path, args.arch, args.flavour)
        print(f"NVIDIA upstream config: {len(nvidia_config)} options")

        diff_options, nixos_only = compare_configs(nvidia_config, nixos_config)

        print(f"\n=== Comparison Results ===")
        print(f"Options where NVIDIA differs from NixOS: {len(diff_options)}")
        print(f"Options only in NixOS (not set by NVIDIA): {len(nixos_only)}")

        excluded_options = [
            "BLK_DEV_DM",
            "BLK_DEV_DM_BUILTIN",
            "PAHOLE_VERSION",
            "RUSTC_LLVM_VERSION",
            "RUSTC_VERSION",
            "GCC_VERSION",
            "LD_VERSION",
            "VERSION_SIGNATURE",
            "LOCALVERSION",
            "INITRAMFS_SOURCE",
            "SYSTEM_TRUSTED_KEYS",
            "SYSTEM_REVOCATION_KEYS",
            "MODULE_SIG_KEY",
            "SYSTEM_BLACKLIST_HASH_LIST",
            "EXTRA_FIRMWARE",
            "IPE_BOOT_POLICY",
        ]

        count = generate_terse_nix(diff_options, kernel_version, output_path, excluded_options)

        print(f"\nSuccess! Generated: {output_path}")
        return 0

    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
