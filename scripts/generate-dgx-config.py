#!/usr/bin/env python3
"""
Generate NVIDIA DGX Spark kernel configuration from Debian annotations.

This script uses Ubuntu's annotation tooling to process both master and NVIDIA-specific
annotations, automatically handling inheritance to produce a complete kernel config
suitable for NixOS.
"""

import argparse
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


def run_command(cmd, cwd=None, check=True):
    """Run a shell command and return the result."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            check=check
        )
        return result
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {cmd}")
        print(f"Exit code: {e.returncode}")
        print(f"Stdout: {e.stdout}")
        print(f"Stderr: {e.stderr}")
        raise


def get_kernel_version(kernel_source_dir):
    """Extract kernel version from the NVIDIA kernel source."""
    makefile_path = Path(kernel_source_dir) / "Makefile"

    if not makefile_path.exists():
        raise FileNotFoundError(f"Makefile not found at {makefile_path}")

    version_info = {}
    with open(makefile_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('VERSION ='):
                version_info['major'] = line.split('=')[1].strip()
            elif line.startswith('PATCHLEVEL ='):
                version_info['minor'] = line.split('=')[1].strip()
            elif line.startswith('SUBLEVEL ='):
                version_info['patch'] = line.split('=')[1].strip()
            elif line.startswith('EXTRAVERSION ='):
                extra = line.split('=')[1].strip()
                if extra:
                    version_info['extra'] = extra

    # Build version string
    version = f"{version_info['major']}.{version_info['minor']}.{version_info['patch']}"
    if 'extra' in version_info:
        version += version_info['extra']

    return version


def generate_config_header(kernel_version, annotation_file, arch, flavour):
    """Generate a header for the config file with metadata."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")

    header = f"""#
# NVIDIA DGX Spark Kernel Configuration
# Generated from Debian annotations for NixOS
#
# Kernel Version: {kernel_version}
# Target Architecture: {arch}
# Target Flavour: {flavour}
# Source Annotation: {annotation_file}
# Generated: {timestamp}
# Generator: generate-dgx-config.py
#
# This configuration combines Ubuntu master annotations with NVIDIA-specific
# overrides to provide a complete kernel config suitable for DGX Spark systems.
#

"""
    return header


def generate_kernel_config(kernel_source_dir, output_dir, arch="arm64", flavour="arm64-nvidia"):
    """Generate kernel configuration from NVIDIA annotations."""
    kernel_source_path = Path(kernel_source_dir).resolve()
    output_path = Path(output_dir).resolve()

    # Verify paths exist
    if not kernel_source_path.exists():
        raise FileNotFoundError(f"Kernel source directory not found: {kernel_source_path}")

    # Get kernel version
    kernel_version = get_kernel_version(kernel_source_path)
    print(f"Detected kernel version: {kernel_version}")

    # Path to NVIDIA annotations
    nvidia_annotations = kernel_source_path / "debian.nvidia-6.17/config/annotations"
    if not nvidia_annotations.exists():
        raise FileNotFoundError(f"NVIDIA annotations not found: {nvidia_annotations}")

    # Path to annotation script
    annotation_script = kernel_source_path / "debian/scripts/misc/annotations"
    if not annotation_script.exists():
        raise FileNotFoundError(f"Annotation script not found: {annotation_script}")

    # Create output directory
    output_path.mkdir(parents=True, exist_ok=True)

    # Generate config filename
    config_filename = f"nvidia-dgx-spark-{kernel_version}.config"
    config_path = output_path / config_filename

    print(f"Generating config: {config_path}")
    print(f"Using annotations: {nvidia_annotations}")
    print(f"Target: {arch}/{flavour}")

    # Run annotation tool to export config
    cmd = f"python3 {annotation_script} --file {nvidia_annotations} --arch {arch} --flavour {flavour} --export"
    print(f"Running: {cmd}")

    result = run_command(cmd, cwd=kernel_source_path)

    if result.returncode != 0:
        print(f"Error generating config: {result.stderr}")
        return False

    # Generate header
    header = generate_config_header(kernel_version, str(nvidia_annotations), arch, flavour)

    # Convert from standard kernel config format to NixOS structuredExtraConfig format
    nix_config_options = {}

    for line in result.stdout.splitlines():
        line = line.strip()
        if line.startswith('CONFIG_') and '=' in line:
            # CONFIG_FOO=y -> FOO = yes;
            option, value = line.split('=', 1)
            option = option.replace('CONFIG_', '')

            if value == 'y':
                nix_config_options[option] = 'lib.mkForce yes'
            elif value == 'n':
                nix_config_options[option] = 'lib.mkForce no'
            elif value == 'm':
                nix_config_options[option] = 'lib.mkForce module'
            elif value.startswith('"') and value.endswith('"'):
                # String values - keep as freeform
                nix_config_options[option] = f'lib.mkForce (freeform {value})'
            elif value.isdigit():
                # Numeric values - keep as freeform
                nix_config_options[option] = f'lib.mkForce (freeform "{value}")'
            else:
                # Other values - treat as freeform strings
                nix_config_options[option] = f'lib.mkForce (freeform "{value}")'
        elif line.startswith('# CONFIG_') and 'is not set' in line:
            # # CONFIG_FOO is not set -> FOO = no;
            match = line.split(' ')[1]  # Extract CONFIG_FOO
            option = match.replace('CONFIG_', '')
            nix_config_options[option] = 'lib.mkForce no'

    # Generate config filename
    config_filename = f"nvidia-dgx-spark-{kernel_version}.nix"
    config_path = output_path / config_filename

    # Write Nix file with structured config
    with open(config_path, 'w') as f:
        f.write(f'# Generated NVIDIA DGX Spark kernel configuration\n')
        f.write(f'# Kernel Version: {kernel_version}\n')
        f.write(f'# Architecture: {arch}, Flavour: {flavour}\n')
        f.write(f'# Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S UTC")}\n\n')
        f.write('{ lib }: with lib.kernel; {\n')

        # Sort options alphabetically for consistency
        for option in sorted(nix_config_options.keys()):
            value = nix_config_options[option]
            # Quote attribute names that start with numbers or contain special characters
            if option[0].isdigit() or not option.replace('_', '').isalnum():
                f.write(f'  "{option}" = {value};\n')
            else:
                f.write(f'  {option} = {value};\n')

        f.write('}\n')

    print(f"Successfully generated: {config_path}")
    print(f"Config contains {len(nix_config_options)} options")

    return True


def main():
    parser = argparse.ArgumentParser(
        description="Generate NVIDIA DGX Spark kernel configuration from Debian annotations"
    )
    parser.add_argument(
        "--kernel-source",
        default="/home/graham/git/NV-Kernels",
        help="Path to NVIDIA kernel source directory"
    )
    parser.add_argument(
        "--output-dir",
        default="./configs",
        help="Output directory for generated config files"
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
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )

    args = parser.parse_args()

    try:
        success = generate_kernel_config(
            args.kernel_source,
            args.output_dir,
            args.arch,
            args.flavour
        )
        if success:
            print("\n✓ Configuration generated successfully!")
            return 0
        else:
            print("\n✗ Failed to generate configuration")
            return 1

    except Exception as e:
        print(f"\n✗ Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
