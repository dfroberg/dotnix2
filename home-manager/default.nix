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
      ec2-api-tools
      awscli2
      aws-vault
      aws-iam-authenticator
      kubectl
      kubectx
      k9s
      yarn
      nodePackages.pnpm
      # Security tools
      sops
      age
      bws
      
      # Shell and environment
      oh-my-zsh
      wakatime
      jankyborders
      sketchybar
      jq
      eza
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
          cd ${config.home.homeDirectory}/.gnupg && PATH="${pkgs.gzip}/bin:$PATH" ${pkgs.gnutar}/bin/tar xzf /tmp/gnupg.tar.gz
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
      ".config/karabiner/karabiner.json".text = builtins.toJSON {
        global = {
          check_for_updates_on_startup = true;
          show_in_menu_bar = true;
          show_profile_name_in_menu_bar = false;
        };
        profiles = [
          {
            name = "Default profile";
            selected = true;
            simple_modifications = [];
            complex_modifications = {
              parameters = {
                "basic.simultaneous_threshold_milliseconds" = 50;
                "basic.to_delayed_action_delay_milliseconds" = 500;
                "basic.to_if_alone_timeout_milliseconds" = 1000;
                "basic.to_if_held_down_threshold_milliseconds" = 500;
                "mouse_motion_to_scroll.speed" = 100;
              };
              rules = [
                {
                  description = "Change caps_lock to command+control+option. Toggle Caps Lock when pressed alone";
                  manipulators = [
                    {
                      from = {
                        key_code = "caps_lock";
                        modifiers.optional = ["any"];
                      };
                      parameters."basic.to_if_held_down_threshold_milliseconds" = 250;
                      to_if_held_down = [
                        {
                          key_code = "left_option";
                          modifiers = ["left_command" "left_control"];
                        }
                      ];
                      to_delayed_action.to_if_canceled = [
                        {
                          key_code = "caps_lock";
                        }
                      ];
                      to_if_alone = [
                        {
                          key_code = "caps_lock";
                          repeat = false;
                          halt = true;
                        }
                      ];
                      type = "basic";
                    }
                  ];
                }
              ];
            };
            virtual_hid_keyboard = {
              country_code = 0;
              indicate_sticky_modifier_keys_state = true;
              mouse_key_xy_scale = 100;
              keyboard_type = "ansi";
              keyboard_type_v2 = "ansi";
              caps_lock_delay_milliseconds = 0;
            };
          }
        ];
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
        "/run/current-system/sw/bin"  # System binaries first
        "$HOME/.nix-profile/bin"
        "${config.home.homeDirectory}/.local/bin"
        "/nix/var/nix/profiles/default/bin"
        "$PATH"
      ];
      # Set SHELL to the correct path
      SHELL = "/run/current-system/sw/bin/zsh";
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
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "kubectl"
          "helm"
          "docker"
          "golang"
        ];
        theme = "terminalparty";
      };
      
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

        # History configuration
        HISTSIZE="10000"
        SAVEHIST="10000"
        HISTFILE="$HOME/.zsh_history"
        
        setopt HIST_FCNTL_LOCK
        unsetopt APPEND_HISTORY
        setopt HIST_IGNORE_DUPS
        unsetopt HIST_IGNORE_ALL_DUPS
        unsetopt HIST_SAVE_NO_DUPS
        unsetopt HIST_FIND_NO_DUPS
        setopt HIST_IGNORE_SPACE
        unsetopt HIST_EXPIRE_DUPS_FIRST
        setopt SHARE_HISTORY
        unsetopt EXTENDED_HISTORY

        # Source wakatime plugin
        if [[ -f "$HOME/.zsh/plugins/zsh-wakatime/zsh-wakatime.plugin.zsh" ]]; then
          source "$HOME/.zsh/plugins/zsh-wakatime/zsh-wakatime.plugin.zsh"
        fi
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
        aerospaceinfo = "/Users/dannyfroberg/dotnix/.config/aerospace/info.sh";
        aerospacereset = "/Users/dannyfroberg/dotnix/.config/aerospace/reset.sh";
        aerospacesetup = "/Users/dannyfroberg/dotnix/.config/aerospace/setup.sh";
        yabaisetup = "/Users/dannyfroberg/.config/yabai/yabaisetup.sh";
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
      profiles = {
        default = {
          extensions = with pkgs.vscode-extensions; [
            wakatime.vscode-wakatime
          ];
        };
      };
    };
  };

  services = {
  };
}

