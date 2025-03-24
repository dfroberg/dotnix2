{ pkgs, ... }:

{
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages =
    [
      pkgs.gzip # GNU compression utility
      pkgs.home-manager
      (pkgs.stdenv.mkDerivation {
        name = "aerospace";
        version = "0.17.1-Beta";
        src = pkgs.fetchurl {
          url = "https://github.com/nikitabobko/AeroSpace/releases/download/v0.17.1-Beta/AeroSpace-v0.17.1-Beta.zip";
          sha256 = "15052621779bcf5adccba5da5e8267b27c845d6d690277383f84a383b18651e1";
        };
        nativeBuildInputs = [ pkgs.unzip ];
        installPhase = ''
          mkdir -p $out/Applications
          unzip $src
          mv *.app $out/Applications/
          mkdir -p $out/bin
          mv aerospace $out/bin/
          chmod +x $out/bin/aerospace
        '';
      })
      pkgs.fzf # Fuzzy finder
      pkgs.pet # Snippet manager
      pkgs.lazydocker # Docker TUI
      pkgs.lazygit # Git TUI
      pkgs.ripgrep # Faster grep
      pkgs.zoxide # Directory jump tool (z)
      pkgs.k9s # Kubernetes CLI to manage your clusters in styles
      pkgs.pandoc # Universal document converter
      pkgs.rustc # Rust programming language
      pkgs.rustup # Rust toolchain installer
      pkgs.lorri # Nix shell manager
      pkgs.htop # Interactive process viewer
      pkgs.tree # Display directories as trees
      pkgs.gh # GitHub CLI
      pkgs.go # Go programming language
      pkgs.kubectl # Kubernetes CLI
      pkgs.kubectx # Kubernetes context switcher
      pkgs.tenv # OpenTofu, Terraform, Terragrunt and Atmos version manager
      pkgs.delta # Terminal git diff viewer with syntax highlighting
      pkgs.curl # Command line tool for transferring data with URL syntax
      pkgs.jq # Command line JSON processor
      pkgs.yq # Command line YAML processor
      pkgs.oh-my-zsh # Many things
      pkgs.eza # ls replacement
      pkgs.terminal-notifier  # macOS notification system
      pkgs.xclip # Command line clipboard manager
      pkgs.xsel # Command line clipboard manager
      pkgs.slack # Slack client
      pkgs.zoom-us # Zoom client
      pkgs.keycastr  # Visual keyboard viewer
      (pkgs.writeScriptBin "clone-repos" ''
        #!${pkgs.stdenv.shell}
        ORG=$1 # Your organization in lowercase
        CLONE_PATH="/''$HOME/''${ORG}" # Path in your filesystem where you want to clone the repos to
        DEFAULT_SUBSET=""
        SUBSET=''${2:-''$DEFAULT_SUBSET} # Only clone repos that contain this string in their name

        # Check if gh is installed
        if ! command -v gh &> /dev/null
        then
            echo "gh could not be found"
            exit
        fi

        # Check if jq is installed
        if ! command -v jq &> /dev/null
        then
            echo "jq could not be found"
            exit
        fi

        # Check if ORG is set
        if [[ -z "''${ORG}" ]]; then
          echo "Help: clone-repos.sh <ORG> [<SUBSET>,<SUBSET>,<SUBSET>,...]"
          exit
        fi
        echo "Cloning repos from ''${ORG} to ''${CLONE_PATH} that contain \"''${SUBSET}\" in their name"
        # loop over comma separated list of strings in SUBSET variable and echo the subset
        for subset in $(echo ''${SUBSET} | tr "," "\n"); do
          echo "Searching for \"''${subset}\""
          REPOS=$(gh repo list INFURA --limit 9999 --no-archived --json sshUrl --jq ".[] | select(.sshUrl | contains(\"''${subset}\")) | .sshUrl")
          for REPO_URL in ''${REPOS}; do
            echo Getting ''${REPO_URL}
            temp=''${REPO_URL##*/}
            repo_name=''${temp%.*}
            gh repo clone "''${REPO_URL}" "''${CLONE_PATH}/''${repo_name}" -- -q 2>/dev/null || (
                cd "''${CLONE_PATH}/''${repo_name}"
                # Handle case where local checkout is on a non-main/master branch
                # - ignore checkout errors because some repos may have zero commits, 
                # so no main or master
                echo -n "  pulling "
                git config pull.rebase true
                git checkout -q main 2>/dev/null || true
                git checkout -q master 2>/dev/null || true
                git fetch -f --tags -q && git pull -q
            )
          done;
        done;
      '')
    ];

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  environment.darwinConfig = "$HOME/dotnix/darwin";
  
  # Auto upgrade nix package and the daemon service.
  nix = {
    enable = false;  # Let Determinate Systems handle this
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "@admin" "@wheel" ];
    };
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs = {
    zsh.enable = true;  # default shell on catalina
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    atkinson-hyperlegible
  ];

  services = {
    yabai = {
      enable = false;
      package = pkgs.yabai;
      extraConfig = ''
        #!/usr/bin/env bash
        # Doing nothing at this stage
      '';
      config = {
        layout = "bsp";
        mouse_modifier = "ctrl";
        mouse_drop_action = "stack";
        window_shadow = "float";
        window_gap = "10";
        focus_follows_mouse = "off";
        mouse_follows_focus = "off";
      };
    };
    jankyborders = {
      enable = true;
      blur_radius = 5.0;
      hidpi = true;
      active_color = "0xAAB279A7";
      inactive_color = "0x33867A74";
    };
    skhd = {
      enable = false;
      package = pkgs.skhd;
      skhdConfig = ''
        #!/bin/sh
        
        # Window management hotkeys can go here
      '';
    };
    aerospace = {
      enable = true;  # Enable AeroSpace service
      package = pkgs.stdenv.mkDerivation {
        name = "aerospace";
        version = "0.17.1-Beta";
        src = pkgs.fetchurl {
          url = "https://github.com/nikitabobko/AeroSpace/releases/download/v0.17.1-Beta/AeroSpace-v0.17.1-Beta.zip";
          sha256 = "15052621779bcf5adccba5da5e8267b27c845d6d690277383f84a383b18651e1";
        };
        nativeBuildInputs = [ pkgs.unzip ];
        installPhase = ''
          mkdir -p $out/Applications
          unzip $src
          mv *.app $out/Applications/
          mkdir -p $out/bin
          mv aerospace $out/bin/
          chmod +x $out/bin/aerospace
        '';
      };
    };
  };

  homebrew = {
    enable = true;

    taps = [
      # Removing the tap since we're installing manually
    ];

    brews = [
      "awscli"
      "aws-vault"
      "yarn"
      "npm"
      "pre-commit"
      "terragrunt"
      "tfenv"
      "tflint"
      "nushell"
      "bat"  # Better cat with syntax highlighting
      "fd"   # Better find
      "dust" # Better du
      "bottom" # Better top/htop
      "difftastic" # Better diff
      "hyperfine" # Benchmarking tool
    ];

    casks = [
      "1password"
      # Removing aerospace from casks since we're installing manually
      "bartender"
      "fantastical"
      "firefox"
      "hammerspoon"
      "joplin"
      "karabiner-elements"
      "keycastr"
      "obsidian"
      "raycast"
      "soundsource"
      "wezterm"
      "visual-studio-code"
      "warp"
    ];

    masApps = {
      Tailscale = 1475387142;
      Slack = 803453959;
      Bitwarden = 1352778147;
    };
  };

  system = {
    defaults = {
      dock = {
        autohide = true;
        orientation = "bottom";
        show-process-indicators = false;
        show-recents = false;
        static-only = true;
      };
      finder = {
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        ShowPathbar = true;
      };
      NSGlobalDomain = {
        AppleKeyboardUIMode = 3;
        "com.apple.keyboard.fnState" = true;
        NSAutomaticWindowAnimationsEnabled = false;
        InitialKeyRepeat = 15;    # Normal minimum is 15
        KeyRepeat = 2;            # Normal minimum is 2
        ApplePressAndHoldEnabled = false;  # Enable key repeat
        NSWindowResizeTime = 0.001;  # Make window resizing faster
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
      };
      screencapture = {
        location = "~/Pictures/Screenshots";
        type = "png";
      };
      # Add TCC permissions for Warp
      CustomUserPreferences = {
        "com.apple.TCC" = {
          "kTCCServiceAccessibility" = {
            "org.hammerspoon.Hammerspoon" = {
              allowed = 1;
              prompt-count = 1;
            };
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceSystemPolicyAllFiles" = {
            "org.hammerspoon.Hammerspoon" = {
              allowed = 1;
              prompt-count = 1;
            };
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceAppleEvents" = {
            "org.hammerspoon.Hammerspoon" = {
              allowed = 1;
              prompt-count = 1;
            };
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceScreenCapture" = {
            "org.hammerspoon.Hammerspoon" = {
              allowed = 1;
              prompt-count = 1;
            };
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
        };
      };
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = false;
    };
    activationScripts = {
      postActivation.text = ''
        # Load PAM module for sudo Touch ID authentication
        # Check if pam_tid.so is already configured
        if ! grep -q "pam_tid.so" /etc/pam.d/sudo; then
          sudo sed -i "" "/pam_tid.so/d" /etc/pam.d/sudo
          sudo sed -i "" '1a\
auth       sufficient     pam_tid.so
' /etc/pam.d/sudo
        fi

        # Configure Karabiner-Elements
        KARABINER_USERS="/Users/dfroberg /var/root"
        
        # Add a log function
        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
        }

        # Create temp file with rules content
        TEMP_FILE=''$(mktemp)
        cat > "''$TEMP_FILE" << 'EOF'
{
    "description": "Change caps_lock to command+control+option. Toggle Caps Lock when pressed alone.",
    "enabled": false,
    "manipulators": [
        {
            "from": {
                "key_code": "caps_lock",
                "modifiers": { "optional": ["any"] }
            },
            "parameters": {
              "basic.to_if_held_down_threshold_milliseconds": 250
            },
            "to_if_held_down": [
                {
                  "key_code": "left_option",
                  "modifiers": ["left_command", "left_control"]
                }
            ],
            "to_delayed_action": {
              "to_if_canceled": [
                {
                  "key_code": "caps_lock"
                }
              ]
            },
            "to_if_alone": [
                {
                    "key_code": "caps_lock",
                    "repeat": false,
                    "halt": true
                }
            ],
            "type": "basic"
        }
    ]
}
EOF

        # Loop through each user directory
        for USER_HOME in ''${KARABINER_USERS}; do
          KARABINER_CONFIG_DIR="''${USER_HOME}/.config/karabiner"
          KARABINER_FILE="''${KARABINER_CONFIG_DIR}/karabiner.json"
          log "Configuring Karabiner-Elements at ''${KARABINER_FILE}"

          # Ensure directory exists
          mkdir -p "''$KARABINER_CONFIG_DIR"

          # Create default config if it doesn't exist
          if [ ! -f "''$KARABINER_FILE" ]; then
            echo '{"profiles":[{"name":"Default profile","selected":true,"virtual_hid_keyboard":{"keyboard_type_v2":"ansi"},"complex_modifications":{"rules":[]}}]}' > "''$KARABINER_FILE"
          fi

          # Check if jq is available
          if ! command -v jq &> /dev/null; then
            echo "Warning: jq not found, skipping Karabiner configuration update"
          else
            # Update the rules using jq
            RULES=''$(cat "''$TEMP_FILE")
            jq --arg rules "''$RULES" '
              .profiles[0].complex_modifications.rules = (
                if (.profiles[0].complex_modifications.rules | length > 0) then
                  (.profiles[0].complex_modifications.rules | map(
                    if .description == "Section (§) to a Hyper Key" then
                      ($rules | fromjson)
                    else
                      .
                    end
                  ))
                else
                  [($rules | fromjson)]
                end
              )
            ' "''$KARABINER_FILE" > "''${KARABINER_FILE}.tmp" && mv "''${KARABINER_FILE}.tmp" "''$KARABINER_FILE" || echo "Error: Failed to update Karabiner configuration"
          fi

          # Check common installation paths
          for cli_path in "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" "/Applications/Karabiner-Elements.app/Contents/MacOS/karabiner_cli"; do
            if [ -x "''${cli_path}" ]; then
              KARABINER_CLI="''${cli_path}"
              break
            fi
          done

          if [ -n "''${KARABINER_CLI}" ]; then
            # Use the CLI
            "''${KARABINER_CLI}" --select-profile 'Default profile' || true
          else
            echo "Warning: karabiner_cli not found"
          fi
        done

        rm "''$TEMP_FILE"

        # Add Warp to admin group
        # echo "Adding Warp to admin group..."
        # sudo security authorizationdb write system.privilege.admin allow
        # sudo security authorizationdb write system.preferences allow
        # sudo security authorizationdb write com.apple.system-extensions.admin allow

        # Disable automatic space rearrangement
        /usr/bin/defaults write com.apple.dock "mru-spaces" -bool false
        # Disable space auto-rearrange based on most recent use
        /usr/bin/defaults write com.apple.dock "mru-spaces" -bool false
        # Disable automatic space switching
        /usr/bin/defaults write com.apple.dock "workspaces-auto-swoosh" -bool false
        
        # Restart Dock to apply changes
        killall Dock
        
        # Wait for Dock to restart
        sleep 5


        '';
    };
  };
  security = {
    pam = {
      services.sudo_local.touchIdAuth = true;
    };
    sudo = {
      extraConfig = ''
        # Yabai and darwin-rebuild
        %admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/yabai --load-sa
        %admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild

        # System configuration commands
        %admin ALL=(root) NOPASSWD: /usr/bin/sed -i "" "/pam_tid.so/d" /etc/pam.d/sudo
        %admin ALL=(root) NOPASSWD: /usr/bin/sed -i "" "1a*" /etc/pam.d/sudo
        %admin ALL=(root) NOPASSWD: /usr/bin/security authorizationdb write system.privilege.admin allow
        %admin ALL=(root) NOPASSWD: /usr/bin/security authorizationdb write system.preferences allow
        %admin ALL=(root) NOPASSWD: /usr/bin/security authorizationdb write com.apple.system-extensions.admin allow

        # Homebrew and Application setup
        %admin ALL=(root) NOPASSWD: /opt/homebrew/bin/brew

      '';
    };
  };
  
}
