{ config, pkgs, lib, ... }:

{
  # Enable systemd in the initial ramdisk
  boot.initrd.systemd.enable = true;

  # Enable specific hardware modules for USB boot and emergency access
  # Based on hardware.enableAllHardware but excluding missing modules like pata_pcmcia
  boot.initrd.kernelModules = [
    # USB controllers (critical for ARM64 USB boot)
    "xhci_plat_hcd" # Platform USB 3.0 controllers for ARM64 systems

    # USB storage and modern USB support (for boot device access)
    "uas" # USB Attached SCSI protocol for modern USB drives

    # USB input devices (essential for emergency mode keyboard access)
    "usbhid" # USB Human Interface Device driver
    "hid_generic" # Generic HID support

    # Storage access (for reading from USB drives)
    "sd_mod" # SCSI disk support

    # Modern storage support
    "nvme" # NVMe SSD support
  ];

  # USB storage support
  boot.supportedFilesystems = [ "vfat" "ext4" "ntfs" "iso9660" ];

  # Boot loader configuration for USB
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # File systems configuration handled automatically by ISO image

  # Networking
  networking.hostName = "nixos-usb";
  networking.networkmanager.enable = true;

  # Time zone
  time.timeZone = "Europe/London";

  # Enable GNOME desktop environment for live USB
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Auto-login for live USB environment
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "nixos";

  # Enable audio for desktop environment
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # User configuration
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "nixos";
  };

  # Enable root login for emergency mode
  users.users.root.initialHashedPassword = null;

  # Enable sudo without password for the nixos user
  security.sudo.wheelNeedsPassword = false;

  # System packages for live USB environment
  environment.systemPackages = with pkgs; [
    # Essential tools
    vim
    wget
    curl
    git
    htop
    lshw
    pciutils
    usbutils

    # GUI applications for live environment
    firefox
    gnome-terminal
    nautilus
    gnome-text-editor
    gnome-system-monitor

    # Live USB utilities
    gparted
    parted
    rsync
    tree
    file
    unzip
    zip

    # NixOS installer
    calamares-nixos
  ];

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
    };
  };

  # Enable Flakes and the new command-line tool
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Automatically optimize the Nix store
  nix.settings.auto-optimise-store = true;

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Enable zram swap
  zramSwap.enable = true;

  # System state version
  system.stateVersion = "25.11";
}
