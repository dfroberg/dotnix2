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

  launchd.agents.aerospace = {
    enable = true;
    config = {
      ProgramArguments = [ "${config.programs.aerospace-custom.package}/bin/aerospace" ];
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/tmp/aerospace.log";
      StandardErrorPath = "/tmp/aerospace.error.log";
    };
  };

  home = {
    stateVersion = "24.05"; # Updated to match home-manager version
    enableNixpkgsReleaseCheck = false;  # Disable version mismatch warning

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
      (python3.withPackages (ps: with ps; [
        psutil
        thefuck
      ]))
      uv
      wakatime-cli
      jankyborders
      sketchybar
      (pkgs.fetchFromGitHub {
        owner = "wbingli";
        repo = "zsh-wakatime";
        rev = "master";
        hash = "sha256-iMHPDz4QvaL3YdRd3vaaz1G4bj8ftRVD9cD0KyJVeAs=";
      })
      jq
      pkgs.nerd-fonts.jetbrains-mono
    ];

    activation = {
      decryptSecrets = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p ${config.home.homeDirectory}/.config/sops/age
        echo "Decrypting secrets..."
        if [ -f ${config.home.homeDirectory}/.config/sops/age/keys.txt ]; then
          mkdir -p ${config.home.homeDirectory}/.config/secrets
          export SOPS_AGE_KEY_FILE=${config.home.homeDirectory}/.config/sops/age/keys.txt 

          # create .sopsrc
          echo "Creating .sopsrc file..."
          echo "ageKeyFile: ${config.home.homeDirectory}/.config/sops/age/keys.txt" > ${config.home.homeDirectory}/.sopsrc

          # Test secrets
          ${pkgs.sops}/bin/sops -d ${toString ./../.config/secrets/test.age} > ${config.home.homeDirectory}/.config/secrets/test-secret.yaml

          ${pkgs.sops}/bin/sops -d ${toString ./../.config/secrets/wakatime.age} > ${config.home.homeDirectory}/.wakatime.cfg
          # Decrypt secrets
          echo "Decryption completed."
        else
          echo "Decryption failed, add your age key."
          echo "Please add your age key to ${config.home.homeDirectory}/.config/sops/age/keys.txt"
          exit 1
        fi
      '';

      # Add experimental features to nix commands during activation
      enableExperimentalFeatures = lib.hm.dag.entryBefore ["installPackages"] ''
        export NIX_CONFIG="experimental-features = nix-command flakes"
      '';

      cleanupHammerspoon = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
        echo "Cleaning up Hammerspoon symlinks..."
        rm -rf ${config.home.homeDirectory}/.hammerspoon
      '';

      linkAerospaceConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
        echo "Creating symlink for aerospace.toml..."
        mkdir -p ${config.home.homeDirectory}/.config/aerospace
        rm -f ${config.home.homeDirectory}/.config/aerospace/aerospace.toml
        ln -sf ${config.home.homeDirectory}/dotnix/.config/aerospace/aerospace.toml ${config.home.homeDirectory}/.config/aerospace/aerospace.toml
        echo "Symlink created."
      '';
    };

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
      NIX_CONFIG = "experimental-features = nix-command flakes";
    };
  };

  programs = {
    dircolors.enable = true;
    fzf.enable = true;
    starship.enable = true;
    zoxide.enable = true;
    
    aerospace-custom = {
      enable = true;
      package = pkgs.aerospace;
      settings = {
        start-at-login = true;
        enable-normalization-flatten-containers = true;
        enable-normalization-opposite-orientation-for-nested-containers = true;
        accordion-padding = 30;
        default-root-container-layout = "tiles";
        default-root-container-orientation = "auto";
        on-focused-monitor-changed = ["move-mouse monitor-lazy-center"];
      };
    };
    
    zsh = {
      enable = true;
      enableCompletion = false; # enabled in oh-my-zsh
      
      shellAliases = {
        asl = "aws sso login";
        ls = "eza -l";
        ll = "eza -la";
        da = "direnv allow";
        nud = "nix --extra-experimental-features \"nix-command flakes\" run nix-darwin -- switch --flake ~/dotnix";
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
            sha256 = "sha256-iMHPDz4QvaL3YdRd3vaaz1G4bj8ftRVD9cD0KyJVeAs=";
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
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        wakatime.vscode-wakatime
      ];
    };
  };
}
