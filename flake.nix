{
  description = "Danny's Nix System Configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/2d9b63316926aa130a5a51136d93b9be28808f26";
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
    # aerospace - window manager for macOS
    aerospace = {
      url = "github:nikitabobko/AeroSpace";
      flake = false;
    };
  };

  # Add minimum Nix version requirement
  nixConfig = {
    extra-experimental-features = [ "nix-command" "flakes" ];
    min-version = "2.18.1";  # Minimum version for Determinate Systems compatibility
  };

  outputs = { nixpkgs, darwin, home-manager, nixos-wsl, agenix, aerospace, ... } @ inputs: let
    nixpkgs.config.allowUnfree = true;
    darwinSystem = {user, arch ? "aarch64-darwin"}:
      darwin.lib.darwinSystem {
        system = arch;
        modules = [
          ./darwin/darwin.nix
          { nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              (final: prev: {
                aerospace = final.stdenv.mkDerivation {
                  pname = "aerospace";
                  version = "0.7.0";
                  src = aerospace;

                  buildInputs = with final; [
                    swift
                    swiftPackages.swiftpm
                    final.darwin.apple_sdk.frameworks.AppKit
                    final.darwin.apple_sdk.frameworks.Foundation
                  ];

                  buildPhase = ''
                    # Set Swift tools version to 6.0
                    echo "// swift-tools-version:6.0" > Package.swift
                    swift build --configuration release --disable-sandbox
                  '';

                  installPhase = ''
                    mkdir -p $out/bin
                    cp .build/release/aerospace $out/bin/
                  '';

                  meta = with final.lib; {
                    description = "A tiling window manager for macOS";
                    homepage = "https://github.com/nikitabobko/AeroSpace";
                    platforms = platforms.darwin;
                  };
                };
              })
            ];
          }
          # Check nix-darwin version - 1.2 includes the fix for Homebrew --no-lock removal
          ({ lib, ... }: {
            assertions = [{
              assertion = (inputs.darwin.sourceInfo.lastModified or 0) >= 1742373336;
              message = "nix-darwin version >= 1.2 is required for compatibility with latest Homebrew changes (--no-lock removal)";
            }];
          })
          agenix.darwinModules.default
          home-manager.darwinModules.home-manager
          {
            _module.args = { inherit inputs; };
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";  # Add backup extension for conflicting files
              extraSpecialArgs = { inherit inputs; };
              sharedModules = [({ lib, pkgs, ... }: {
                nix.enable = lib.mkForce false;  # Disable nix management in home-manager
                home.enableNixpkgsReleaseCheck = false;  # Prevent version mismatch warnings
                home.packages = with pkgs; [
                  # Core system utilities
                  coreutils
                  findutils
                  gnused
                  gnutar
                  gzip
                  # Your original packages
                  amber
                  devenv
                  markdown-oxide
                  nixd
                  ollama
                  ripgrep
                  smartcat
                  gnupg
                  sops
                  age
                  bws
                  oh-my-zsh
                  fish
                  wakatime
                  (python3.withPackages (ps: with ps; [
                    psutil
                    thefuck
                  ]))
                  uv
                  wakatime-cli
                  jankyborders
                  sketchybar
                  jq
                  pkgs.nerd-fonts.jetbrains-mono
                ];
              })];
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
      bootstrap = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ({ pkgs, ... }: {
            # Minimal config to bootstrap the system
            nixpkgs.config.allowUnfree = true;
            services.nix-daemon.enable = false;  # Let Determinate Systems handle this
            nix = {
              enable = false;
              settings = {
                experimental-features = [ "nix-command" "flakes" ];
                trusted-users = [ "root" "@admin" "@wheel" ];
              };
            };
            system.stateVersion = 4;
          })
        ];
      };
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
