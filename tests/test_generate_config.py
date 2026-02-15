#!/usr/bin/env python3
"""
Tests for generate-terse-dgx-config.py

These tests cover the core functionality with dummy kernel configs,
avoiding the need to fetch actual NVIDIA kernel sources.
"""

import importlib.util
import shutil
import sys
from pathlib import Path

import pytest

script_path = Path(__file__).parent.parent / "scripts" / "generate-terse-dgx-config.py"
spec = importlib.util.spec_from_file_location("gen", script_path)
gen = importlib.util.module_from_spec(spec)
sys.modules["gen"] = gen
spec.loader.exec_module(gen)

nix_available = shutil.which("nix") is not None


class TestEvalNixKernelSource:
    """Tests for evaluating nvidia-kernel-source.nix using nix eval."""

    @pytest.mark.skipif(not nix_available, reason="nix command not available")
    def test_eval_basic_info(self, tmp_path):
        nix_content = '''
let
  nvidiaKernelRev = "abc123";
  nvidiaKernelHash = "sha256-xxxxxxxx";
  nvidiaKernelVersion = "6.17.1";
in
{
  inherit nvidiaKernelRev nvidiaKernelHash nvidiaKernelVersion;
}
'''
        nix_file = tmp_path / "test.nix"
        nix_file.write_text(nix_content)

        info = gen.eval_nix_kernel_source(nix_file)

        assert info["version"] == "6.17.1"
        assert info["rev"] == "abc123"
        assert info["hash"] == "sha256-xxxxxxxx"

    @pytest.mark.skipif(not nix_available, reason="nix command not available")
    def test_eval_missing_version(self, tmp_path):
        nix_content = '''
let
  nvidiaKernelRev = "abc123";
  nvidiaKernelHash = "sha256-xxx";
in
{
  inherit nvidiaKernelRev nvidiaKernelHash;
}
'''
        nix_file = tmp_path / "test.nix"
        nix_file.write_text(nix_content)

        with pytest.raises(Exception):
            gen.eval_nix_kernel_source(nix_file)


class TestParseKernelConfig:
    """Tests for parsing kernel .config format."""

    def test_parse_yes_option(self):
        config_text = "CONFIG_FOO=y\n"
        result = gen.parse_kernel_config(config_text)
        assert result["CONFIG_FOO"] == "y"

    def test_parse_module_option(self):
        config_text = "CONFIG_BAR=m\n"
        result = gen.parse_kernel_config(config_text)
        assert result["CONFIG_BAR"] == "m"

    def test_parse_no_option(self):
        config_text = "# CONFIG_BAZ is not set\n"
        result = gen.parse_kernel_config(config_text)
        assert result["CONFIG_BAZ"] == "n"

    def test_parse_string_option(self):
        config_text = 'CONFIG_VERSION="6.17.1"\n'
        result = gen.parse_kernel_config(config_text)
        assert result["CONFIG_VERSION"] == '"6.17.1"'

    def test_parse_numeric_option(self):
        config_text = "CONFIG_NR_CPUS=256\n"
        result = gen.parse_kernel_config(config_text)
        assert result["CONFIG_NR_CPUS"] == "256"

    def test_parse_mixed_config(self):
        config_text = """
# Automatically generated file
CONFIG_FOO=y
CONFIG_BAR=m
# CONFIG_BAZ is not set
CONFIG_VERSION="test"
CONFIG_NUMBER=42
"""
        result = gen.parse_kernel_config(config_text)
        assert len(result) == 5
        assert result["CONFIG_FOO"] == "y"
        assert result["CONFIG_BAR"] == "m"
        assert result["CONFIG_BAZ"] == "n"
        assert result["CONFIG_VERSION"] == '"test"'
        assert result["CONFIG_NUMBER"] == "42"

    def test_parse_comments_ignored(self):
        config_text = """
# This is a comment
# CONFIG_FOO is not set
# Another comment
CONFIG_BAR=y
"""
        result = gen.parse_kernel_config(config_text)
        assert "CONFIG_FOO" in result
        assert "CONFIG_BAR" in result
        assert len(result) == 2


class TestValueToNix:
    """Tests for converting kernel config values to Nix format."""

    def test_yes_to_nix(self):
        assert gen.value_to_nix("y") == "yes"

    def test_no_to_nix(self):
        assert gen.value_to_nix("n") == "no"

    def test_module_to_nix(self):
        assert gen.value_to_nix("m") == "module"

    def test_string_to_nix(self):
        assert gen.value_to_nix('"test"') == '(freeform "test")'

    def test_numeric_to_nix(self):
        assert gen.value_to_nix("42") == '(freeform "42")'

    def test_other_to_nix(self):
        assert gen.value_to_nix("some_value") == '(freeform "some_value")'


class TestCompareConfigs:
    """Tests for comparing NVIDIA and NixOS configs."""

    def test_identical_configs(self):
        nvidia = {"CONFIG_FOO": "y", "CONFIG_BAR": "m"}
        nixos = {"CONFIG_FOO": "y", "CONFIG_BAR": "m"}

        diff, nixos_only = gen.compare_configs(nvidia, nixos)

        assert len(diff) == 0
        assert len(nixos_only) == 0

    def test_differing_values(self):
        nvidia = {"CONFIG_FOO": "y", "CONFIG_BAR": "m"}
        nixos = {"CONFIG_FOO": "n", "CONFIG_BAR": "m"}

        diff, nixos_only = gen.compare_configs(nvidia, nixos)

        assert len(diff) == 1
        assert diff["CONFIG_FOO"] == "y"
        assert len(nixos_only) == 0

    def test_nvidia_only_options(self):
        nvidia = {"CONFIG_FOO": "y", "CONFIG_NVIDIA_SPECIFIC": "y"}
        nixos = {"CONFIG_FOO": "y"}

        diff, nixos_only = gen.compare_configs(nvidia, nixos)

        assert len(diff) == 1
        assert diff["CONFIG_NVIDIA_SPECIFIC"] == "y"
        assert len(nixos_only) == 0

    def test_nixos_only_options(self):
        nvidia = {"CONFIG_FOO": "y"}
        nixos = {"CONFIG_FOO": "y", "CONFIG_NIXOS_SPECIFIC": "m"}

        diff, nixos_only = gen.compare_configs(nvidia, nixos)

        assert len(diff) == 0
        assert nixos_only == {"CONFIG_NIXOS_SPECIFIC"}

    def test_mixed_differences(self):
        nvidia = {
            "CONFIG_A": "y",
            "CONFIG_B": "m",
            "CONFIG_C": "n",
            "CONFIG_NVIDIA": "y",
        }
        nixos = {
            "CONFIG_A": "y",
            "CONFIG_B": "n",
            "CONFIG_C": "n",
            "CONFIG_NIXOS": "m",
        }

        diff, nixos_only = gen.compare_configs(nvidia, nixos)

        assert len(diff) == 2
        assert diff["CONFIG_B"] == "m"
        assert diff["CONFIG_NVIDIA"] == "y"
        assert nixos_only == {"CONFIG_NIXOS"}


class TestGenerateTerseNix:
    """Tests for generating terse Nix output."""

    def test_basic_generation(self, tmp_path):
        diff_options = {
            "CONFIG_FOO": "y",
            "CONFIG_BAR": "m",
        }

        output_file = tmp_path / "test.nix"
        count = gen.generate_terse_nix(diff_options, "6.17.1", output_file, [])

        assert count == 2
        content = output_file.read_text()
        assert "FOO = lib.mkForce yes" in content
        assert "BAR = lib.mkForce module" in content

    def test_excluded_options(self, tmp_path):
        diff_options = {
            "CONFIG_FOO": "y",
            "CONFIG_GCC_VERSION": "130300",
        }

        output_file = tmp_path / "test.nix"
        count = gen.generate_terse_nix(
            diff_options, "6.17.1", output_file, ["GCC_VERSION"]
        )

        assert count == 1
        content = output_file.read_text()
        assert "FOO = lib.mkForce yes" in content
        assert "GCC_VERSION" not in content

    def test_numeric_option_name(self, tmp_path):
        diff_options = {
            "CONFIG_64BIT": "y",
        }

        output_file = tmp_path / "test.nix"
        count = gen.generate_terse_nix(diff_options, "6.17.1", output_file, [])

        assert count == 1
        content = output_file.read_text()
        assert '"64BIT" = lib.mkForce yes' in content

    def test_freeform_values(self, tmp_path):
        diff_options = {
            "CONFIG_STRING": '"test"',
            "CONFIG_NUMBER": "42",
        }

        output_file = tmp_path / "test.nix"
        count = gen.generate_terse_nix(diff_options, "6.17.1", output_file, [])

        assert count == 2
        content = output_file.read_text()
        assert "STRING = lib.mkForce (freeform" in content
        assert "NUMBER = lib.mkForce (freeform" in content


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
