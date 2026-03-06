{ config, pkgs, lib, ... }:

{
  # ── Boot ────────────────────────────────────────────────────────────────────
  boot = {
    loader = {
      systemd-boot.enable      = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.kernelModules = [ "usb_storage" "uas" "xhci_hcd" ];
    kernelParams = [ "rootdelay=10" ];
  };

  # ── Filesystems ─────────────────────────────────────────────────────────────
  fileSystems."/nix" = lib.mkForce {
    device        = "/dev/disk/by-label/nixos";
    fsType        = "ext4";
    options       = [ "noatime" "nodiratime" ];
    neededForBoot = true;
  };

  fileSystems."/boot" = lib.mkForce {
    device  = "/dev/disk/by-label/BOOT";
    fsType  = "vfat";
    options = [ "umask=0077" ];
  };

  # ── Flash Wear Protection ───────────────────────────────────────────────────
  swapDevices = [];

  zramSwap = {
    enable    = true;
    algorithm = "zstd";
  };

  services.journald.extraConfig = "Storage=volatile";

  services.fstrim = {
    enable   = true;
    interval = "weekly";
  };

  # ── Persistent State ─────────────────────────────────────────────────────────
  systemd.tmpfiles.rules = [
    "d /nix/persist/etc/NetworkManager/system-connections 0700 root root -"
    "f /nix/persist/etc/machine-id                        0444 root root -"
    "d /nix/persist/var/lib/nixos                         0755 root root -"
  ];

  environment.persistence."/nix/persist" = {
    hideMounts = true;

    directories = [
      { directory = "/etc/NetworkManager/system-connections"; mode = "0700"; }
      "/var/lib/nixos"
    ];

    files = [
      "/etc/machine-id"
    ];
  };

  # ── Networking ───────────────────────────────────────────────────────────────
  networking = {
    hostName              = "nixos-usb";
    networkmanager.enable = true;
  };

  # ── Users ────────────────────────────────────────────────────────────────────
  users.users.root.hashedPasswordFile = "/nix/persist/password/audacioustux";
  users.users.audacioustux = {
    isNormalUser    = true;
    uid             = 1000;
    extraGroups     = [ "wheel" "networkmanager" ];
    hashedPasswordFile = "/nix/persist/password/audacioustux";
  };

  # ── Packages ─────────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    curl
    htop
    neovim
    sysstat
  ];

  # ── Misc ─────────────────────────────────────────────────────────────────────
  hardware.enableRedistributableFirmware = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  time.timeZone = "UTC";

  system.stateVersion = "25.11";
}
