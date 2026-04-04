{ config, lib, pkgs, ... }:

{
  imports = [
    ../modules/dgx-spark.nix
  ];

  hardware.dgx-spark.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "dgx-spark";
  networking.networkmanager.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
    };
  };

  system.stateVersion = "25.11";
}
