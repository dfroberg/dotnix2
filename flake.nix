{
  description = "Danny's Nix System Configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    # sops-nix - secrets with `sops`
    # https://github.com/Mic92/sops-nix
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Add minimum Nix version requirement
  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" ];
    min-version = "2.18.1";  # Require at least Nix 2.18.1 for Determinate Systems compatibility
  };

  outputs = { nixpkgs, darwin, home-manager, nixos-wsl, agenix, ... } @ inputs: let
    nixpkgs.config.allowUnfree = true;
    darwinSystem = {user, arch ? "aarch64-darwin"}:
      darwin.lib.darwinSystem {
        system = arch;
        modules = [
          ./darwin/darwin.nix
          { nixpkgs.config.allowUnfree = true; }
          # Check nix-darwin version
          ({ lib, ... }: {
            assertions = [{
              assertion = lib.versionAtLeast (lib.versions.majorMinor darwin.version) "1.1";
              message = "nix-darwin version >= 1.1 is required for proper Determinate Systems compatibility";
            }];
          })
          agenix.darwinModules.default
          home-manager.darwinModules.home-manager
          {
            _module.args = { inherit inputs; };
            home-manager = {
              users.${user} = import ./home-manager;
            };
            users.users.${user}.home = "/Users/${user}";
            nix.settings.trusted-users = [ user ];
          }
        ];
      };
  in
  {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "aarch64-darwin";
        modules = [
          nixos-wsl.nixosModules.wsl
          ./nixos/configuration.nix
          ./.config/wsl
          agenix.packages.default
          # sops-nix.packages.${system}.default
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              users.nixos = import ./home-manager;
            };
            nix.settings.trusted-users = [ "nixos" ];
          }
        ];
      };
    };
    darwinConfigurations = {
      "XM14644HYP" = darwinSystem {
        user = "dfroberg";
      };
      "Dannys-MacBook-Pro" = darwinSystem {
        user = "dfroberg";
        arch = "aarch64-darwin";
      };
      "Admins-MacBook-Pro" = darwinSystem {
        user = "dannyfroberg";
        arch = "aarch64-darwin";
      };
    };
  };
}
