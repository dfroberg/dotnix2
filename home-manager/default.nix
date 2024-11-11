{ pkgs, lib, ... }:

{
  imports = [
    ./git.nix
    ./helix.nix
    ./nvim
    ./starship.nix
    ./tmux.nix
    ./wezterm.nix
  ];
  nixpkgs = {
    config = {
      allowUnfree = true;
      # allowUnfreePredicate = (_: true);
      allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "ec2-api-tools"
      ];
    };
  };

  home = {
    stateVersion = "24.05"; # Please read the comment before changing.

    # The home.packages option allows you to install Nix packages into your
    # environment.
    packages = with pkgs; [
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
    ];
    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    file = {
      hammerspoon = lib.mkIf pkgs.stdenvNoCC.isDarwin {
        source = ./../.config/hammerspoon;
        target = ".hammerspoon";
        recursive = true;
      };
      kanata = lib.mkIf pkgs.stdenvNoCC.isDarwin {
        source = ./../.config/kanata;
        target = "./config/kanata";
        recursive = true;
      };
    };

    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  programs = {
    zsh = {
      enable = true;
      enableCompletion = false; # enabled in oh-my-zsh
      shellAliases = {
        asl = "aws sso login";
        ls = "eza -l";
        ll = "eza -la";
        da = "direnv allow";
        nu = "darwin-rebuild switch --flake ~/dotnix";
      };
      oh-my-zsh = {
        enable = true;
        theme = "terminalparty";
        plugins = [
	        "git"
          "kubectl"
          "helm"
          "docker"
        ];
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    jujutsu.enable = true;
  };
}
