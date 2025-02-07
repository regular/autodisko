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
        set -eu
        echo
        echo "AUTODISKO"
        echo "---------"
        #${pkgs.libcap}/bin/capsh --current --print
        export PATH="${pkgs.gawk}/bin''${PATH:+:''${PATH}}"
        
        # for sleep
        export PATH="${pkgs.coreutils-full}/bin''${PATH:+:''${PATH}}"
        
        # for mount
        export PATH="/run/wrappers/bin''${PATH:+:''${PATH}}"
        echo

        DEBUG=* ${self.packages.${system}.autodisko}/bin/autodisko <(${pkgs.util-linux}/bin/lsblk -Jbo VENDOR,SUBSYSTEMS,TRAN,TYPE,MODEL,LABEL,NAME,START,SIZE,FSUSE%,PATH) /tmp/disk-config.nix
        #TODO
        echo "secret1" > /tmp/luks.key1
        echo "secret2" > /tmp/luks.key2

        ${disko.packages.${system}.default}/bin/disko --mode disko /tmp/disk-config.nix
        mount
        echo "Gernating /tmp/hardware-configuration.nix"
        export PATH="${pkgs.nixos-install-tools}/bin''${PATH:+:''${PATH}}"
        export PATH="${pkgs.bcachefs-tools}/bin''${PATH:+:''${PATH}}"
        nixos-generate-config --show-hardware-config --root /mnt > /tmp/hardware-configuration.nix
        nixos-generate-config --show-hardware-config --no-filesystems --root /mnt > /tmp/hardware-configuration-no-fs.nix
        #echo "Now sleeping ..."
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
