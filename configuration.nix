{ config, pkgs, lib, ... }:

{
  # ── Tell disko-generated fileSystems that /nix must be up before anything ──
  # Disko writes the fileSystems."/nix" entry. This single-attribute override
  # merges with it without duplicating the whole block.
  fileSystems."/nix".neededForBoot = true;

  # ── Boot ────────────────────────────────────────────────────────────────────
  boot.loader = {
    systemd-boot.enable      = true;
    efi.canTouchEfiVariables = true;
  };

  # ── Flash Wear Protection ───────────────────────────────────────────────────

  # No swap to disk — ever.
  swapDevices = [];

  # Compressed swap in RAM instead of writing to flash.
  zramSwap = {
    enable    = true;
    algorithm = "zstd";   # best compression ratio in the kernel
    memoryMax = null;     # let NixOS calculate a sane default (usually ~50% RAM)
  };

  # Keep all journal logs in RAM. Never written to the USB.
  services.journald.extraConfig = "Storage=volatile";

  # Weekly TRIM pass — safe for USB, avoids synchronous stalls from "discard".
  services.fstrim = {
    enable   = true;
    interval = "weekly";
  };

  # ── Persistent State (/nix/persist lives on your ext4 partition) ────────────
  #
  # Create the directories on the USB that will be bind-mounted into the RAM root.
  # systemd.tmpfiles.rules runs before bind-mounts, so the source paths exist.

  systemd.tmpfiles.rules = [
    # NetworkManager connections
    "d /nix/persist/etc/NetworkManager/system-connections 0700 root root -"
    # Machine ID (some tools need a stable ID across reboots)
    "f /nix/persist/etc/machine-id 0444 root root -"
    # Add more as needed, e.g.:
    # "d /nix/persist/home/youruser 0700 youruser users -"
  ];

  # ── Impermanence — declarative bind-mounts into the tmpfs root ─────────────
  #
  # The impermanence module creates proper systemd mount units for each entry.
  # These are idempotent and safe to run on every nixos-rebuild switch,
  # unlike shell bind-mounts in activationScripts.

  environment.persistence."/nix/persist" = {
    hideMounts = true; # keep `mount` output tidy

    directories = [
      # NetworkManager connections persist across reboots
      { directory = "/etc/NetworkManager/system-connections"; mode = "0700"; }

      # Optional: persist your user's home directory selectively
      # { directory = "/home/youruser/.ssh";         mode = "0700"; user = "youruser"; }
      # { directory = "/home/youruser/.config/fish"; mode = "0755"; user = "youruser"; }
    ];

    files = [
      # A stable machine-id prevents log correlation issues with some tools
      "/etc/machine-id"
    ];
  };

  # ── Networking ──────────────────────────────────────────────────────────────
  networking = {
    hostName = "nixos-usb";
    networkmanager.enable = true;
  };

  # Option A: Declarative Wi-Fi (survives reboots natively, no bind-mount needed)
  # Uncomment and fill in. The profile is baked into the Nix store itself.
  #
  # networking.networkmanager.ensureProfiles.profiles."MyHomeWiFi" = {
  #   connection    = { id = "MyHomeWiFi"; type = "wifi"; };
  #   wifi          = { mode = "infrastructure"; ssid = "MyHomeWiFi"; };
  #   wifi-security = { key-mgmt = "wpa-psk"; psk = "your-password"; };
  #   ipv4          = { method = "auto"; };
  #   ipv6          = { addr-gen-mode = "stable-privacy"; method = "auto"; };
  # };
  #
  # Option B: Use nmcli normally after boot. The impermanence bind-mount above
  # (/etc/NetworkManager/system-connections) means any connection you add with
  # nmcli is written to /nix/persist and survives the next reboot automatically.

  # ── Background Services ─────────────────────────────────────────────────────
  # Define your tasks declaratively. Scripts live in /nix/persist (on USB) so
  # they survive reboots. The unit definition itself is in the Nix store.

  # Example — uncomment and adapt:
  # systemd.services.my-bg-task = {
  #   description = "My DevOps Background Task";
  #   after       = [ "network-online.target" ];
  #   wants       = [ "network-online.target" ];
  #   wantedBy    = [ "multi-user.target" ];
  #   serviceConfig = {
  #     ExecStart = "${pkgs.bash}/bin/bash /nix/persist/scripts/my-task.sh";
  #     Restart   = "on-failure";
  #     # Keep any output in the volatile journal (RAM), not a log file
  #     StandardOutput = "journal";
  #     StandardError  = "journal";
  #   };
  # };

  # ── Packages ────────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    curl
    htop
    # Add your tools here
  ];

  # ── Misc ────────────────────────────────────────────────────────────────────
  time.timeZone = "UTC"; # change to your zone

  # Required — must match the NixOS release you are installing.
  system.stateVersion = "25.11";
}
