{config, lib, ...} : 
let
  disks = config.fileSystems;
  hasMirroredBoot = disks ? "/boot" && disks ? "/boot2";
in {
  # For impermanence
  boot.initrd.systemd.services.rollback = {
    description = "Rollback BTRFS root subvolume to a pristine state";
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    wantedBy = [ "initrd.target" ];
    after = if hasMirroredBoot 
      then [ "systemd-cryptsetup@crypted1.service" "systemd-cryptsetup@crypted2.service" ]
      else [ "systemd-cryptsetup@crypted.service" ];
    before = [ "sysroot.mount" ];

    script = ''
      vgchange -ay pool
      mkdir -p /btrfs_tmp
      mount /dev/pool/root /btrfs_tmp

      if [[ -e /btrfs_tmp/root ]]; then
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
      fi

      delete_subvolume_recursively() {
          IFS=$'\n'
          for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
              delete_subvolume_recursively "/btrfs_tmp/$i"
          done
          btrfs subvolume delete "$1"
      }

      for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
          delete_subvolume_recursively "$i"
      done

      btrfs subvolume create /btrfs_tmp/root
      umount /btrfs_tmp
    '';
  };

  fileSystems = {
    "/persist" = {
      neededForBoot = true;
    };
  } // lib.mkIf hasMirroredBoot {
    "/boot2" = {
      neededForBoot = true;
    };
  };

  disko.devices = {
    disk = {
      disk1 = {
        type = "disk";
        device = "${mainDevicePath}";

        content = {
          type = "gpt";
          partitions = {
            esp = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" "umask=0077" ];
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted1";
                content = {
                  type = "lvm_pv";
                  vg = "pool";
                };
              };
            };
          };
        };
      };

      disk2 = {
        type = "disk";
        device = "${secondaryDevicePath}";

        content = {
          type = "gpt";
          partitions = {
            esp = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot2";
                mountOptions = [ "defaults" "umask=0077" ];
              };
            };

            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted2";
                content = {
                  type = "lvm_pv";
                  vg = "pool";
                };
              };
            };
          };
        };
      };
    };

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" "-d raid1" "-m raid1" ];

              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                };

                "/persist" = {
                  mountpoint = "/persist";
                  mountOptions = [ "compress=zstd" "subvol=persist" "noatime" ];
                };

                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "compress=zstd" "subvol=nix" "noatime" ];
                };
              };
            };
          };
        };
      };
    };
  };

  boot = let
    disk1 = config.disko.devices.disk.disk1.device;
    disk2 = config.disko.devices.disk.disk2.device;
  in {
    loader = {
      grub = lib.mkIf (config.boot.loader.grub.enable && hasMirroredBoot) {
        devices = [ disk1 disk2 ];
        mirroredBoots = [
          { path = "/boot"; devices = [disk1]; }
          { path = "/boot2"; devices = [disk2]; }
        ];
      };
      
      systemd-boot = lib.mkIf (config.boot.loader.systemd-boot.enable && hasMirroredBoot) {
        mirroredBoots = [
          { path = "/boot"; }
          { path = "/boot2"; }
        ];
      };
    };
  };
}
