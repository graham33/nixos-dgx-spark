# NixOS configuration for DGX Spark
# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Define your hostname.
  networking.hostName = "dgx-spark"; # Change this to your preferred hostname

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "UTC"; # Change to your timezone, e.g. "Europe/London"

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable the X11 windowing system and GNOME Desktop Environment.
  services.xserver.enable = true;
  services.displayManager.gdm = {
    enable = true;
    autoSuspend = false; # Prevents auto-suspend for server workloads
  };
  services.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver.xkb.layout = "us"; # Change to your keyboard layout

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.users.nixos = {
    # Change "nixos" to your preferred username
    isNormalUser = true;
    shell = pkgs.bash; # or pkgs.zsh if you prefer zsh
    extraGroups = [
      "wheel" # Enable 'sudo' for the user
      "networkmanager"
      "video" # GPU access
    ];

    # Add your SSH public keys here for remote access
    # openssh.authorizedKeys.keys = [
    #   "ssh-rsa AAAA... your-key-here"
    # ];
  };

  # Nix configuration
  nix.settings = {
    # Add trusted users for multi-user Nix operations
    trusted-users = [ "root" "nixos" ]; # Replace "nixos" with your username

    # Enable experimental features
    experimental-features = [ "nix-command" "flakes" ];

    # Automatically optimize the Nix store
    auto-optimise-store = true;
  };

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Enable Firefox web browser
  programs.firefox.enable = true;

  # Enable Zsh (optional)
  # programs.zsh.enable = true;

  # System packages - essential tools for DGX Spark development
  environment.systemPackages = with pkgs; [
    # Essential system tools
    curl
    git
    htop
    lshw
    pciutils
    usbutils
    vim # or neovim
    wget

    # Development tools
    tmux
    tree
    unzip
    zip
  ];

  # Enable the OpenSSH daemon for remote access
  services.openssh = {
    enable = true;
    settings = {
      # Disable root login for security (recommended)
      PermitRootLogin = "no";
    };
  };

  # Optional: Configure firewall
  # networking.firewall.allowedTCPPorts = [ ];
  # networking.firewall.allowedUDPPorts = [ ];

  # Or disable the firewall entirely (not recommended for production)
  # networking.firewall.enable = false;

  # Enable zram swap for better memory management
  zramSwap.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
