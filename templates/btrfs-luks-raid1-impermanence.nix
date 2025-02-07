let

in {
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

            crypt_p1 = {
              size = "100%";
              content = {
                type = "luks";
                name = "p1";
                settings = {
                  allowDiscards = true;
                  keyFile = "/tmp/luks.key1";
                };
                additionalKeyFiles = [ "/tmp/luks.key2" ];
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

            crypt_p2 = {
              size = "100%";
              content = {
                type = "luks";
                name = "p2";
                settings = {
                  allowDiscards = true;
                  keyFile = "/tmp/luks.key1";
                };
                additionalKeyFiles = [ "/tmp/luks.key2" ];
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "-d raid1"
                    "/dev/mapper/p1" # Use decrypted mapped device, same name as defined in disk1
                  ];
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
    };
  };
}
