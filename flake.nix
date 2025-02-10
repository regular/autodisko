{
  description = "Automatically pick a disk layout and format drives";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, disko }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    apps.x86_64-linux.default = {
      type = "app";
      program = "${self.packages.${system}.default}/bin/autodisko";
    };

    packages.${system} = {
      default = pkgs.writeScriptBin "autodisko" ''
        #!${pkgs.bash}/bin/bash
        set -eux
        echo
        echo "AUTODISKO"
        echo "---------"
        #${pkgs.libcap}/bin/capsh --current --print
        export PATH="${pkgs.gawk}/bin''${PATH:+:''${PATH}}"
        
        # for sleep
        export PATH="${pkgs.coreutils-full}/bin''${PATH:+:''${PATH}}"

        # for mountpoint
        export PATH="${pkgs.util-linux}/bin''${PATH:+:''${PATH}}"

        # for gzip (run by tar)
        export PATH="${pkgs.gzip}/bin''${PATH:+:''${PATH}}"
        
        # for mount
        export PATH="/run/wrappers/bin''${PATH:+:''${PATH}}"
        echo

        # for nixos-generate-config, nixos0-install
        export PATH="${pkgs.nixos-install-tools}/bin''${PATH:+:''${PATH}}"
        export PATH="${pkgs.nix}/bin''${PATH:+:''${PATH}}"
        export PATH="${pkgs.bcachefs-tools}/bin''${PATH:+:''${PATH}}"

        ${pkgs.util-linux}/bin/lsblk -Jbo VENDOR,SUBSYSTEMS,TRAN,TYPE,MODEL,LABEL,NAME,START,SIZE,FSUSE%,PATH > tmp/disks.json
        DEBUG=* ${self.packages.${system}.autodisko}/bin/autodisko /tmp/disks.json /tmp/disk-config.nix

        #TODO
        echo "secret1" > /tmp/luks.key1
        echo "secret2" > /tmp/luks.key2

        if [ $# -eq 1 ]; then
          URL=$1
          echo "Flake download from $URL"
          ${pkgs.curl}/bin/curl -vX POST \
            -H "Content-Type: application/json" \
            -d @/tmp/disks.json \
            -D /tmp/headers.txt \
            $URL \
            -o /tmp/flake.tar.gz
          conf=$(gawk -F': ' '/x-nixos-configuration:/ {gsub(/\r/,""); print $2}' /tmp/headers.txt)
          disk_devices=$(gawk -F': ' '/x-disk-devices:/ {gsub(/\r/,""); print $2}' /tmp/headers.txt)
          rm -rf /tmp/flake && mkdir -p /tmp/flake
          ${pkgs.gnutar}/bin/tar -xzf /tmp/flake.tar.gz --strip-components=1 -C /tmp/flake
          nixos-generate-config --show-hardware-config --no-filesystems --root /mnt > /tmp/flake/hardware/$conf.nix
          disk_args=$(echo "$disk_devices" | gawk -F',' '{for(i=1;i<=NF;i++) printf "--disk disk%d /dev/%s ", i, $i}')
          #mkdir -p /tmp/mnt
          #chmod 755 /tmp/mnt
          #${disko.packages.${system}.default}/bin/disko-install --mount-point /tmp/mnt --write-efi-boot-entries --flake /tmp/flake\#$conf $disk_args
          ${disko.packages.${system}.default}/bin/disko --debug --mode disko --flake /tmp/flake\#$conf 
          mount

          mkdir -p /mnt/etc/nixos
          rm -rf /mnt/etc/nixos/configuration || true
          cp -av /tmp/flake /mnt/etc/nixos/configuration
          nixos-install --flake "/mnt/etc/nixos/configuration\#$conf" --root /mnt --no-channel-copy --no-root-password --show-trace --verbose
          fix-bootorder # instlled by deployment-target
        else
          ${disko.packages.${system}.default}/bin/disko --mode disko /tmp/disk-config.nix
          mount
        fi
        echo "Gernating /tmp/hardware-configuration.nix"
        nixos-generate-config --show-hardware-config --root /mnt > /tmp/hardware-configuration.nix
        nixos-generate-config --show-hardware-config --no-filesystems --root /mnt > /tmp/hardware-configuration-no-fs.nix
      '';

      autodisko = pkgs.buildNpmPackage rec {
        name = "autodisko";
        src = ./.;
        npmDepsHash = "sha256-oLV91cM4IvsTeWNlbEK9/U+Tczh6ZVXLggwsyIVEpH4";

        dontNpmBuild = true;
        makeCacheWritable = true;
      };
    };

    nixosModules.default = (import ./service.nix) inputs; 
    
  };
}
