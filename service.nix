inputs: { config, lib, pkgs, ... }: let
  description = "A modern lsblk with json output";
in {
  options.services.autodisko = with lib; {
    tty = mkOption rec {
      type = types.path;
      default = "/dev/tty1";
      defaultText = default;
      description = "What tty to use for output (should match tty on kernel command line";
    };

    ignoreDiskWithLabel = mkOption rec {
      type = types.str;
      default = "";
      defaultText = default;
      description = "When enumerating disks, ignore this on (typically used for the boot medium, if it is an installer";
    };
  };

  config = let
    cfg = config.services.autodisko;
  in {
    boot = {
      kernelParams = [
        "systemd.unit=autodisko.target"
      ];
    };

    systemd = {

      targets.autodisko = rec {
        inherit description;
        requires = [ "multi-user.target" ];
        after = requires;
        #AllowIsolate = "yes";
      };

      services.autodisko = {
        inherit description;
        after = [  "multi-user.target" ];
        wantedBy = [ "autodisko.target" ];

        serviceConfig = rec {
          ExecStart = "${inputs.self.apps.x86_64-linux.default.program}";
          RemainAfterExit = true;
          Type = "idle";

          StandardOutput = "tty";
          StandardError = "tty";
          TTYPath = "${cfg.tty}";

          Environment = [
            "HOME=/run/home"
            "autodisko_ignore_disks__label=${cfg.ignoreDiskWithLabel}"
          ];

          # Needed to share mounts with global namespace
          PrivateMounts = "no";

          User = "regular";
          #DynamicUser = true;
          
          # Using ReadWritePaths sets up
          # a new fs namespace tha prevents
          # mounts from propagating to the main NS, so we
          # cannot use it!
          #ReadWritePaths=[
          #  "/dev/vdc"
          #  "/dev/zero"
          #  "/dev/null"
          #  "/nix/store"
          #  "/proc" #TODO
          #  "/mnt"
          #  "/dev"
          #  "/etc/fstab"
          #  "/run"
          #  "/var/run"
          #];
          
          AmbientCapabilities = [ 
            # TODO file bug for systemd v 255: these properties are not merged!
            "CAP_DAC_OVERRIDE CAP_SYS_RAWIO CAP_FOWNER CAP_SYS_MOUNT CAP_SYS_ADMIN"
            #"CAP_SYS_ADMIN" # Needed for remounting /nix/store read/write
          ];
          CapabilityBoundingSet = AmbientCapabilities;
          NoNewPrivileges = true;
          
          #PrivateDevices = true;

          DevicePolicy = "closed";
          DeviceAllow = [ 
            "${cfg.tty} w"
            "block-* rwm"
          ];

          # TODO: has no effect when non-root user
          PrivateNetwork = true;
          RestrictAddressFamilies = "AF_UNIX";
          IPAddressDeny = "any";

          SystemCallFilter = [
           "~@clock"
           "~@debug"
           "~@module"
            #"~@mount"
            #"~@privileged"
            #"~@raw-io"
           "~@reboot"
            #"~@resources"
            #"~@swap"
            "~@obsolete"
            "~@cpu-emulation"
          ];

          ProtectHostname = true;
          ProtectClock = true;

          # TODO: Each one of these seem to create an fs namespac, so we can't use them
          #ProtectHome = true; // TODO: interferes with mount?
          #ProtectKernelLogs = true;
          #ProtectKernelModules = true;
          #ProtectControlGroups = true;
          #ProtectKernelTunables = true; # Unable to write changes to (some device) otherwise

          # This causes
          # GC Warning: Could not open /proc/stat
          # which seems harmless (?)
          #ProtectProc = "invisible";
          #ProcSubset = "pid";

          # Needs to be false by nix build sandbox (only when user root)
          #RestrictNamespaces = true; 

          #PrivateUsers = true; #TODO: This seems to prevent dd (access to /vdc)from working. WHY?
          SystemCallArchitectures = "native";
          UMask = "0077";
          RestrictRealtime = true;
          LockPersonality = true;
          #MemoryDenyWriteExecute = true; # for V8
        };

      };
    };
  };
}
