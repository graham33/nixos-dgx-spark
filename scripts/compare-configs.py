#!/usr/bin/env python3
"""
Compare NixOS common config with generated NVIDIA DGX config.

This tool helps identify important NixOS-specific kernel options that might be
missing from the NVIDIA DGX configuration and provides recommendations for
options that should be preserved.
"""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Set, Tuple


def parse_config_file(config_path: Path) -> Dict[str, str]:
    """Parse a kernel config file and return a dict of option -> value."""
    config = {}

    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    with open(config_path, 'r') as f:
        for line in f:
            line = line.strip()

            # Skip empty lines and comments
            if not line or line.startswith('#'):
                # Handle "# CONFIG_FOO is not set" format
                match = re.match(r'^# (CONFIG_\w+) is not set$', line)
                if match:
                    config[match.group(1)] = 'n'
                continue

            # Handle "CONFIG_FOO=value" format (standard kernel config)
            if line.startswith('CONFIG_') and '=' in line:
                key, value = line.split('=', 1)
                config[key] = value
            # Handle "FOO=value" or "FOO? value" format (NixOS intermediate format)
            elif ' ' in line:
                parts = line.split(' ', 1)
                if len(parts) == 2:
                    key, value = parts
                    # Remove optional marker and add CONFIG_ prefix
                    key = key.rstrip('?')
                    key = f"CONFIG_{key}"
                    config[key] = value

    return config


def get_nixos_common_config(cache_file: Path = None) -> Dict[str, str]:
    """Get NixOS common kernel configuration by extracting it from nixpkgs."""
    import subprocess

    if cache_file and cache_file.exists():
        print(f"Using cached NixOS config from {cache_file}")
        return parse_config_file(cache_file)

    print("Extracting NixOS common kernel configuration from nixpkgs...")

    # Use the separate extract-nixos-config.nix file
    script_dir = Path(__file__).parent
    nix_file = script_dir / "extract-nixos-config.nix"

    if not nix_file.exists():
        raise FileNotFoundError(f"NixOS config extractor not found: {nix_file}")

    try:
        # Build the config file using the separate Nix expression
        result = subprocess.run([
            'nix-build', '--no-out-link', str(nix_file)
        ], capture_output=True, text=True, check=True)

        config_path = Path(result.stdout.strip())

        # Read and parse the generated config
        nixos_config = parse_config_file(config_path)

        # Cache the result if cache_file is provided
        if cache_file:
            cache_file.parent.mkdir(parents=True, exist_ok=True)
            with open(config_path, 'r') as src:
                config_content = src.read()
            with open(cache_file, 'w') as dst:
                dst.write(f"# NixOS common kernel configuration\n")
                dst.write(f"# Extracted from nixpkgs on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                dst.write(f"# Kernel version: 6.17\n#\n")
                dst.write(config_content)
            print(f"Cached NixOS config to {cache_file}")

        return nixos_config

    except subprocess.CalledProcessError as e:
        print(f"Error extracting NixOS config: {e}")
        print(f"Stderr: {e.stderr}")
        print("Falling back to minimal critical options...")

        # Fallback to essential options if nix extraction fails
        return {
            'CONFIG_SECURITY_APPARMOR': 'y',
            'CONFIG_SECURITY_APPARMOR_BOOTPARAM_VALUE': '1',
            'CONFIG_SECURITY_APPARMOR_RESTRICT_USERNS': 'y',
            'CONFIG_CGROUPS': 'y',
            'CONFIG_NAMESPACES': 'y',
            'CONFIG_USER_NS': 'y',
            'CONFIG_MEMCG': 'y',
            'CONFIG_BRIDGE': 'm',
            'CONFIG_TUN': 'm',
            'CONFIG_OVERLAY_FS': 'm',
            'CONFIG_EXT4_FS': 'y',
            'CONFIG_TMPFS': 'y',
            'CONFIG_VIRTIO': 'y',
            'CONFIG_VIRTIO_NET': 'm',
            'CONFIG_VIRTIO_BLK': 'm',
        }


def compare_configs(dgx_config: Dict[str, str], nixos_config: Dict[str, str]) -> Tuple[Set[str], Set[str], Set[str]]:
    """Compare two configurations and return differences."""
    dgx_options = set(dgx_config.keys())
    nixos_options = set(nixos_config.keys())

    # Options only in DGX config
    dgx_only = dgx_options - nixos_options

    # Options only in NixOS config (potentially missing from DGX)
    nixos_only = nixos_options - dgx_options

    # Options with different values
    conflicts = set()
    for option in dgx_options & nixos_options:
        if dgx_config[option] != nixos_config[option]:
            conflicts.add(option)

    return dgx_only, nixos_only, conflicts


def analyze_missing_options(missing_options: Set[str], nixos_config: Dict[str, str]) -> Dict[str, str]:
    """Analyze missing options and categorize by importance."""
    critical = {}
    important = {}
    optional = {}

    # Categories based on option prefixes and known importance
    critical_patterns = [
        'CONFIG_SECURITY_',
        'CONFIG_NAMESPACES',
        'CONFIG_USER_NS',
        'CONFIG_CGROUPS',
        'CONFIG_MEMCG',
    ]

    important_patterns = [
        'CONFIG_NETFILTER',
        'CONFIG_BRIDGE',
        'CONFIG_OVERLAY_FS',
        'CONFIG_EXT4_FS',
        'CONFIG_VIRTUALIZATION',
        'CONFIG_KVM',
    ]

    for option in missing_options:
        value = nixos_config[option]
        is_critical = any(option.startswith(pattern) for pattern in critical_patterns)
        is_important = any(option.startswith(pattern) for pattern in important_patterns)

        if is_critical:
            critical[option] = value
        elif is_important:
            important[option] = value
        else:
            optional[option] = value

    return {
        'critical': critical,
        'important': important,
        'optional': optional
    }


def print_comparison_report(dgx_config_path: Path, dgx_only: Set[str], nixos_only: Set[str],
                          conflicts: Set[str], dgx_config: Dict[str, str], nixos_config: Dict[str, str]):
    """Print a detailed comparison report."""
    print(f"# Kernel Configuration Comparison Report")
    print(f"# Generated for: {dgx_config_path}")
    print(f"# Total DGX options: {len(dgx_config)}")
    print(f"# Total NixOS critical options: {len(nixos_config)}")
    print()

    if nixos_only:
        print(f"## Missing NixOS Options ({len(nixos_only)} options)")
        print("The following NixOS options are not present in the DGX config:")
        print()

        categorized = analyze_missing_options(nixos_only, nixos_config)

        if categorized['critical']:
            print("### CRITICAL - These should likely be preserved:")
            for option, value in sorted(categorized['critical'].items()):
                print(f"  {option}={value}")
            print()

        if categorized['important']:
            print("### IMPORTANT - Consider preserving these:")
            for option, value in sorted(categorized['important'].items()):
                print(f"  {option}={value}")
            print()

        if categorized['optional']:
            print(f"### OPTIONAL - {len(categorized['optional'])} other options")
            print("(Use --verbose to see all optional options)")
            print()

    if conflicts:
        print(f"## Conflicting Options ({len(conflicts)} options)")
        print("The following options have different values:")
        print()
        for option in sorted(conflicts):
            dgx_val = dgx_config[option]
            nixos_val = nixos_config[option]
            print(f"  {option}: DGX={dgx_val}, NixOS={nixos_val}")
        print()

    print(f"## DGX-Specific Options ({len(dgx_only)} options)")
    print("These are NVIDIA/DGX-specific options not in standard NixOS config.")
    print("This is expected and shows the value of using the DGX annotations.")
    print()


def generate_recommended_overrides(missing_critical: Dict[str, str], conflicts: Set[str],
                                 dgx_config: Dict[str, str], nixos_config: Dict[str, str]) -> str:
    """Generate recommended structuredExtraConfig overrides."""
    overrides = []

    # Add critical missing options
    for option, value in missing_critical.items():
        config_name = option.replace('CONFIG_', '')
        if value == 'y':
            overrides.append(f"        {config_name} = yes;")
        elif value == 'n':
            overrides.append(f"        {config_name} = no;")
        elif value == 'm':
            overrides.append(f"        {config_name} = module;")
        else:
            overrides.append(f"        {config_name} = \"{value}\";")

    # Add conflicts that should use NixOS values
    nixos_preferred_conflicts = [
        'CONFIG_SECURITY_APPARMOR_RESTRICT_USERNS',
        'CONFIG_SECURITY_YAMA',
    ]

    for option in conflicts:
        if option in nixos_preferred_conflicts:
            config_name = option.replace('CONFIG_', '')
            value = nixos_config[option]
            if value == 'y':
                overrides.append(f"        {config_name} = lib.mkForce yes;")
            elif value == 'n':
                overrides.append(f"        {config_name} = lib.mkForce no;")
            elif value == 'm':
                overrides.append(f"        {config_name} = lib.mkForce module;")
            else:
                overrides.append(f"        {config_name} = lib.mkForce \"{value}\";")

    if overrides:
        return "      structuredExtraConfig = with lib.kernel; {\n" + "\n".join(overrides) + "\n      };"
    else:
        return "      # No additional overrides needed"


def main():
    parser = argparse.ArgumentParser(
        description="Compare NixOS and NVIDIA DGX kernel configurations"
    )
    parser.add_argument(
        "--dgx-config",
        default="./configs/nvidia-dgx-spark-latest.config",
        help="Path to DGX kernel config file"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show all missing options, not just critical ones"
    )
    parser.add_argument(
        "--generate-overrides",
        action="store_true",
        help="Generate recommended NixOS structuredExtraConfig overrides"
    )
    parser.add_argument(
        "--nixos-cache",
        default="./configs/nixos-common-config-6.17.config",
        help="Cache file for NixOS common config (speeds up subsequent runs)"
    )

    args = parser.parse_args()

    try:
        dgx_config_path = Path(args.dgx_config)
        dgx_config = parse_config_file(dgx_config_path)

        nixos_cache_path = Path(args.nixos_cache)
        nixos_config = get_nixos_common_config(nixos_cache_path)

        dgx_only, nixos_only, conflicts = compare_configs(dgx_config, nixos_config)

        print_comparison_report(dgx_config_path, dgx_only, nixos_only, conflicts,
                              dgx_config, nixos_config)

        if args.verbose and nixos_only:
            categorized = analyze_missing_options(nixos_only, nixos_config)
            if categorized['optional']:
                print("### All Optional Missing Options:")
                for option, value in sorted(categorized['optional'].items()):
                    print(f"  {option}={value}")
                print()

        if args.generate_overrides:
            categorized = analyze_missing_options(nixos_only, nixos_config)
            overrides = generate_recommended_overrides(
                categorized['critical'], conflicts, dgx_config, nixos_config
            )
            print("## Recommended NixOS Configuration Overrides:")
            print("```nix")
            print(overrides)
            print("```")

        return 0

    except Exception as e:
        print(f"Error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
