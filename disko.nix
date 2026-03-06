{
  disko.devices = {

    # ── Volatile root in RAM ────────────────────────────────────────────────
    # This is not a real disk partition; disko registers it as a tmpfs mount.
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=4G"   # 4 GB out of 32 GB RAM; raise to 8G if you run heavy workloads
        "mode=755"
      ];
    };

    # ── USB Flash Drive ─────────────────────────────────────────────────────
    disk.usb = {
      type   = "disk";
      device = "/dev/sda"; # ← CHANGE THIS

      content = {
        type = "gpt";

        partitions = {

          # EFI System Partition (bootloader + kernel)
          ESP = {
            priority = 1;
            size     = "512M";
            type     = "EF00"; # GPT partition type code for EFI System
            content  = {
              type         = "filesystem";
              format       = "vfat";
              mountpoint   = "/boot";
              mountOptions = [ "umask=0077" ]; # only root can read EFI files
              extraArgs    = [ "-n" "BOOT" ];  # -n sets the FAT volume label
            };
          };

          # Nix store — the rest of the drive
          nix = {
            priority = 2;
            size     = "100%";
            content  = {
              type         = "filesystem";
              format       = "ext4";
              mountpoint   = "/nix";
              mountOptions = [
                "noatime"     # do NOT write access times on file reads
                "nodiratime"  # do NOT write access times on directory reads
                # NOTE: no "discard" here — synchronous TRIM stalls USB IO.
                #       Weekly fstrim in configuration.nix handles this instead.
              ];
              extraArgs = [ "-L" "nixos" ]; # -L sets the ext4 volume label
            };
          };

        };
      };
    };

  };
}
