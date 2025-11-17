let
  pkgs = import <nixpkgs> { system = "aarch64-linux"; };
  lib = pkgs.lib;

  # Get the common config module
  commonConfigModule = import "${pkgs.path}/pkgs/os-specific/linux/kernel/common-config.nix" {
    inherit lib;
    stdenv = pkgs.stdenv;
    version = pkgs.linux_6_17.version;
    rustAvailable = false; # Keep it simple for now
    features = { };
  };

  # Use exactly the same approach as in generic.nix
  kernelConfigModule = import "${pkgs.path}/nixos/modules/system/boot/kernel_config.nix";

  moduleStructuredConfig = (lib.evalModules {
    modules = [
      kernelConfigModule
      {
        settings = commonConfigModule;
        _file = "common-config.nix";
      }
    ];
  }).config;

in
pkgs.writeText "nixos-common-config" moduleStructuredConfig.intermediateNixConfig
