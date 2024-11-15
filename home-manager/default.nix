{ pkgs, lib, config, ... }:

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
        "bws"
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
      thefuck
      uv
      (pkgs.fetchFromGitHub {
        owner = "wbingli";
        repo = "zsh-wakatime";
        rev = "master";
        sha256 = "sha256-QN/MUDm+hVJUMA4PDqs0zn9XC2wQZrgQr4zmCF0Vruk=";
      })
    ];
    activation.decryptSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
      echo "Decrypting secrets..."
      if [ -f ${config.home.homeDirectory}/.config/sops/age/keys.txt ]; then
        mkdir -p ${config.home.homeDirectory}/.config/secrets
        SOPS_AGE_KEY_FILE=${config.home.homeDirectory}/.config/sops/age/keys.txt ${pkgs.sops}/bin/sops -d ${toString ./../.config/secrets/test.age} > ${config.home.homeDirectory}/.config/secrets/test-secret.yaml
        echo "Decryption completed."
      else
        echo "Decryption failed, add your age key."
        exit 1
      fi
    '';
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
      SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      ZSH_WAKATIME_PROJECT_DETECTION = "true"; # enable project detection
    };
  };

  programs = {
    dircolors.enable = true;
    fzf.enable = true;
    starship.enable = true;
    zoxide.enable = true;
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
      plugins = [
        {
          # will source zsh-autosuggestions.plugin.zsh
          name = "zsh-wakatime";
          src = pkgs.fetchFromGitHub {
            owner = "wbingli";
            repo = "zsh-wakatime";
            rev = "master";
            sha256 = "sha256-QN/MUDm+hVJUMA4PDqs0zn9XC2wQZrgQr4zmCF0Vruk=";
          };
        }
      ];
      oh-my-zsh = {
        enable = true;
        theme = "terminalparty";
        plugins = [
	        "git"
          "kubectl"
          "helm"
          "docker"
          "golang"
          "thefuck"
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
