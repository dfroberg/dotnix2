{ pkgs, lib, config, ... }:

{
  imports = [
    ./git.nix
    ./helix.nix
    ./nvim
    ./starship.nix
    ./tmux.nix
    ./wezterm.nix
    ./aerospace.nix
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
      wakatime-cli
      (pkgs.fetchFromGitHub {
        owner = "wbingli";
        repo = "zsh-wakatime";
        rev = "master";
        sha256 = "sha256-QN/MUDm+hVJUMA4PDqs0zn9XC2wQZrgQr4zmCF0Vruk=";
      })
      jq
      (nerdfonts.override {
        fonts = [
          "JetBrainsMono"
        ];
        enableWindowsFonts = true;
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

    activation.cleanupHammerspoon = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      echo "Cleaning up Hammerspoon symlinks..."
      rm -rf ${config.home.homeDirectory}/.hammerspoon
    '';

    # Home Manager is pretty good at managing dotfiles. The primary way to manage
    # plain files is through 'home.file'.
    file = {
      hammerspoon = lib.mkIf pkgs.stdenvNoCC.isDarwin {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotnix/.config/hammerspoon";
        target = ".hammerspoon";
        recursive = true;
        onChange = ''
          if command -v hs >/dev/null 2>&1; then
            /usr/bin/env hs -c "hs.reload()"
          fi
        '';
      };
      yabaisetup = lib.mkIf pkgs.stdenvNoCC.isDarwin {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotnix/.config/yabai";
        target = ".config/yabai";
        recursive = true;
      };
    };
    # activation.yabaisetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    #   echo "Running yabai activation..."
    #   if command -v /run/current-system/sw/bin/yabai >/dev/null 2>&1; then
    #     echo "yabai is installed"
    #     chmod +x "${config.home.homeDirectory}/.config/yabai/yabaisetup.sh"
    #     echo "yabaisetup.sh is executable"
    #     echo "Running yabaisetup.sh"
    #     # Run in background to avoid blocking home-manager activation
    #     /usr/bin/env timeout 60s "${config.home.homeDirectory}/.config/yabai/yabaisetup.sh"
    #     echo "yabaisetup.sh has been started in background"
    #   else
    #     echo "yabai is not installed"
    #   fi
    # '';
    sessionVariables = {
      EDITOR = "nvim";
      SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
      ZSH_WAKATIME_PROJECT_DETECTION = "true"; # enable project detection
      WAKATIME_HOME = "${config.home.homeDirectory}/.wakatime";
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
        nud = "darwin-rebuild switch --flake ~/dotnix";
        showapps = "yabai -m query --windows | jq -r '.[].app' | sort | uniq";
        showwindows = "yabai -m query --windows | jq -r '.[] | \"id: \\(.id) app: \\(.app) floating: \\(.\"is-floating\") title: \\(.title)\"'";
        showspaces = "yabai -m query --spaces | jq -r '.[].label'";
        showdisplays = "yabai -m query --displays | jq -r '.[].name'";
        yabaisetup = "${config.home.homeDirectory}/.config/yabai/yabaisetup.sh";
        aerospacesetup = "${config.home.homeDirectory}/dotnix/.config/aerospace/setup.sh";
        aerospacereset = "${config.home.homeDirectory}/dotnix/.config/aerospace/reset.sh";
        aerospaceinfo = "${config.home.homeDirectory}/dotnix/.config/aerospace/info.sh";
      };
      plugins = [
        {
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

    vscode = {
      extensions = with pkgs.vscode-extensions; [
        wakatime.vscode-wakatime
      ];
    };
  };
}
