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
    ./gpg.nix
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

    sessionPath = [
      "$HOME/.nix-profile/bin"  # User profile first
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
    ];

    # The home.packages option allows you to install Nix packages into your
    # environment.
    packages = with pkgs; [
      # Core tools
      direnv
      wakatime-cli
      devenv
      gnupg
      pinentry_mac
      
      # Development tools
      amber
      markdown-oxide
      nixd
      ollama
      ripgrep
      smartcat
      
      # Security tools
      sops
      age
      bws
      
      # Shell and environment
      oh-my-zsh
      fish
      wakatime
      jankyborders
      sketchybar
      jq
      pkgs.nerd-fonts.jetbrains-mono
      
      # Wakatime ZSH plugin
      (pkgs.fetchFromGitHub {
        owner = "wbingli";
        repo = "zsh-wakatime";
        rev = "master";
        hash = "sha256-iMHPDz4QvaL3YdRd3vaaz1G4bj8ftRVD9cD0KyJVeAs=";
      })
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

          # Decrypt and setup GPG files
          echo "Setting up GPG configuration..."
          mkdir -p ${config.home.homeDirectory}/.gnupg
          chmod 700 ${config.home.homeDirectory}/.gnupg
          ${pkgs.sops}/bin/sops -d ${toString ./../.config/secrets/gnupg/gnupg.tar.gz.age} > /tmp/gnupg.tar.gz
          cd ${config.home.homeDirectory}/.gnupg && ${pkgs.gnutar}/bin/tar xzf /tmp/gnupg.tar.gz
          rm /tmp/gnupg.tar.gz
          chmod 700 ${config.home.homeDirectory}/.gnupg/*
          chmod 600 ${config.home.homeDirectory}/.gnupg/*.conf

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
      # GPG configuration
      GPG_TTY = "$(tty)";
      # Ensure XDG paths are set
      XDG_DATA_HOME = "${config.home.homeDirectory}/.local/share";
      XDG_CONFIG_HOME = "${config.home.homeDirectory}/.config";
      XDG_CACHE_HOME = "${config.home.homeDirectory}/.cache";
      XDG_STATE_HOME = "${config.home.homeDirectory}/.local/state";
      # Add local bin to PATH
      PATH = lib.concatStringsSep ":" [
        "$HOME/.nix-profile/bin"  # User profile first
        "${config.home.homeDirectory}/.local/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "$PATH"
      ];
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
      
      initExtra = ''
        # Source nix profile
        if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
          . "$HOME/.nix-profile/etc/profile.d/nix.sh"
        fi
        if [ -f "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
          . "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
        fi

        # Ensure all nix paths are available first
        export PATH="/nix/var/nix/profiles/default/bin:$PATH"
        export PATH="/run/current-system/sw/bin:$PATH"
        export PATH="$HOME/.nix-profile/bin:$PATH"

        # Initialize direnv
        if command -v direnv >/dev/null 2>&1; then
          eval "$(direnv hook zsh)"
        fi

        # Initialize thefuck from Homebrew
        if command -v thefuck >/dev/null; then
          eval $(thefuck --alias)
        fi

        # Ensure Homebrew is in PATH
        eval "$(/opt/homebrew/bin/brew shellenv)"
      '';
      
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
        ];
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      stdlib = ''
        # Add support for devenv
        use_devenv() {
          watch_file devenv.nix devenv.lock devenv.yaml
          if has devenv; then
            eval "$(devenv print-dev-env)"
          else
            echo "devenv is not installed. Please install it with:"
            echo "nix --extra-experimental-features 'nix-command flakes' profile install github:cachix/devenv/latest"
          fi
        }
      '';
    };

    jujutsu.enable = true;

    vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        wakatime.vscode-wakatime
      ];
    };

    fish = {
      enable = true;
      interactiveShellInit = ''
        # Disable greeting
        set fish_greeting

        # Ensure all nix paths are available first
        fish_add_path --prepend --move /nix/var/nix/profiles/default/bin
        fish_add_path --prepend --move /run/current-system/sw/bin
        fish_add_path --prepend --move $HOME/.nix-profile/bin

        # Initialize direnv
        if command -v direnv >/dev/null 2>&1
          direnv hook fish | source
        end

        # Initialize Homebrew
        eval (/opt/homebrew/bin/brew shellenv)

        # Initialize thefuck from Homebrew
        if command -v thefuck >/dev/null
          thefuck --alias | source
        end
      '';
      
      shellAliases = {
        # Inherit all ZSH aliases
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
      
      shellInit = ''
        # Set environment variables
        set -gx EDITOR nvim
        set -gx VISUAL $EDITOR
        
        # Ensure nix experimental features are enabled
        set -gx NIX_CONFIG "experimental-features = nix-command flakes"
        
        # Set wakatime variables
        set -gx ZSH_WAKATIME_PROJECT_DETECTION "true"
        set -gx WAKATIME_HOME "$HOME/.wakatime"

        # Add nix paths to fish_user_paths to ensure persistence
        contains /nix/var/nix/profiles/default/bin $fish_user_paths; or set -U fish_user_paths /nix/var/nix/profiles/default/bin $fish_user_paths
        contains /run/current-system/sw/bin $fish_user_paths; or set -U fish_user_paths /run/current-system/sw/bin $fish_user_paths
        contains $HOME/.nix-profile/bin $fish_user_paths; or set -U fish_user_paths $HOME/.nix-profile/bin $fish_user_paths
      '';
    };
  };

  services = {
  };
}

