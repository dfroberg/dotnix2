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
      pkgs.home-manager
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
      (pkgs.writeScriptBin "list-hotkeys" ''
        #!${pkgs.stdenv.shell}
        echo "=== SKHD Hotkeys ==="
        grep -v '^#' /etc/skhdrc | grep -v '^$' | sed 's/^/skhd: /'
        
        echo -e "\n=== System Keyboard Shortcuts ==="
        defaults read com.apple.symbolichotkeys | grep -A2 "enabled = 1" | grep -B2 "value ="
        
        echo -e "\n=== Yabai Hotkeys ==="
        grep -v '^#' /etc/yabairc | grep 'skhd' | sed 's/^/yabai: /'
      '')
      (pkgs.writeScriptBin "clone-repos" ''
        #!${pkgs.stdenv.shell}
        ORG=$1 # Your organization in lowercase
        CLONE_PATH="/$HOME/''${ORG}" # Path in your filesystem where you want to clone the repos to
        DEFAULT_SUBSET=""
        SUBSET=''${2:-$DEFAULT_SUBSET} # Only clone repos that contain this string in their name

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
      pkgs.keycastr  # Visual keyboard viewer
    ];

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  environment.darwinConfig = "$HOME/dotnix/darwin";
  
  # Auto upgrade nix package and the daemon service.
  nix = {
    package = pkgs.nix;
    settings = {
      "extra-experimental-features" = [ "nix-command" "flakes" ];
      "extra-platforms" = [ "x86_64-darwin" "aarch64-darwin"];
    };
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs = {
    gnupg.agent.enable = true;
    zsh.enable = true;  # default shell on catalina
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  fonts.packages = with pkgs; [
    (nerdfonts.override {
      fonts = [
        "JetBrainsMono"
      ];
    })
    atkinson-hyperlegible
  ];

  services = {
    nix-daemon.enable = true;
    yabai = {
      enable = true;
      package = pkgs.yabai;
      extraConfig = ''
        # Wait for yabai to be fully started
        sleep 5

        # Configure spaces
        echo "Setting up spaces..."
        
        # Function to ensure we have exactly 6 spaces
        setup_spaces() {
          # Get displays
          local displays=$(yabai -m query --displays)
          local main_display=$(echo "$displays" | jq -r '.[] | select(.index == 1) | .uuid')
          local second_display=$(echo "$displays" | jq -r '.[] | select(.index == 2) | .uuid')
          
          if [ -n "$main_display" ]; then
            # Get spaces on main display
            local main_spaces=$(yabai -m query --spaces | jq -r ".[] | select(.display == \"$main_display\") | .index")
            local main_count=$(echo "$main_spaces" | wc -l)
            
            # Ensure exactly 1 space on main display
            while [ "$main_count" -lt 1 ]; do
              yabai -m space --create
              main_count=$((main_count + 1))
              sleep 0.5
            done
          fi
          
          if [ -n "$second_display" ]; then
            # Get spaces on second display
            local second_spaces=$(yabai -m query --spaces | jq -r ".[] | select(.display == \"$second_display\") | .index")
            local second_count=$(echo "$second_spaces" | wc -l)
            
            # Ensure exactly 4 spaces on second display
            while [ "$second_count" -lt 4 ]; do
              yabai -m space --create
              second_count=$((second_count + 1))
              sleep 0.5
            done
          fi
          
          # Get final space list for labeling
          spaces=$(yabai -m query --spaces | jq -r '.[].index')
          
          # Label spaces based on display
          i=1
          for space in $spaces; do
            # Get display for this space
            local space_display=$(yabai -m query --spaces --space $space | jq -r '.display')
            
            if [ "$space_display" = "$main_display" ]; then
              # Label main display space
              yabai -m space $space --label main
            elif [ "$space_display" = "$second_display" ]; then
              # Label second display spaces
              case $i in
                1) yabai -m space $space --label code ;;
                2) yabai -m space $space --label docs ;;
                3) yabai -m space $space --label chat ;;
                4) yabai -m space $space --label social ;;
              esac
            fi
            i=$((i + 1))
          done
        }
        
        # Set up spaces
        setup_spaces
        
        # Wait for spaces to settle
        sleep 2
        
        # Basic window settings
        yabai -m config layout bsp
        yabai -m config window_placement second_child
        yabai -m config split_ratio 0.50
        yabai -m config auto_balance off
        yabai -m config window_origin_display default

        # Window opacity settings
        yabai -m config active_window_opacity 1.0
        yabai -m config normal_window_opacity 0.9

        # Padding
        yabai -m config top_padding    5
        yabai -m config bottom_padding 5
        yabai -m config left_padding   5
        yabai -m config right_padding  5

        # Name displays using display ID (more stable than index)
        yabai -m display 1 --label main # Built-in/Main display
        yabai -m display 2 --label top  # External display

        # sub-layer normal
        yabai -m rule --add app=".*" sub-layer=normal

        # South display rules
        yabai -m rule --add app="^Spotify$" display=south space=chat
        yabai -m rule --add app="^Joplin$" display=south space=docs
        yabai -m rule --add app="^Obsidian$" display=south space=docs
        yabai -m rule --add app="^Raycast$" display=south space=other

        # Set default split type
        yabai -m config split_type auto

        # Rules for unmanaged apps
        yabai -m rule --add app="^System Settings$" manage=off
        yabai -m rule --add app="^Calculator$" manage=off
        yabai -m rule --add app="^Karabiner-Elements$" manage=off
        yabai -m rule --add app="^QuickTime Player$" manage=off
        yabai -m rule --add app="^Finder$" manage=off
        yabai -m rule --add app="^Digital Color Meter$" manage=off
        yabai -m rule --add app="^Activity Monitor$" manage=off
        yabai -m rule --add app="^Path Finder$" manage=off
        yabai -m rule --add app="^1Password$" manage=off
        yabai -m rule --add app="^Raycast$" manage=off
        yabai -m rule --add app="^zoom.us$" manage=off
        yabai -m rule --add app="^Bitwarden$" manage=off
        yabai -m rule --add app="^OBSBOT_Main$" manage=off
        yabai -m rule --add app="^Finder$" manage=off
        yabai -m rule --add app="^Joplin$" manage=off
        yabai -m rule --add app="^YouTube$" manage=off
        yabai -m rule --add app="^Signal$" manage=off
        yabai -m rule --add app="^Google Meet$" manage=off
        yabai -m rule --add app="^Slack$" manage=off
        
        # Event handlers
        yabai -m signal --add event=window_created action="yabai -m query --windows --window &> /dev/null || reposition_windows"
        yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
        yabai -m signal --add event=window_moved action="reposition_windows"
        yabai -m signal --add event=window_resized action="reposition_windows"
        yabai -m signal --add event=space_changed action="reposition_windows"
        yabai -m signal --add event=display_changed action="reposition_windows"
        yabai -m signal --add event=display_added action="reposition_windows"
        yabai -m signal --add event=display_removed action="reposition_windows"
        yabai -m signal --add event=window_focused action="reposition_windows"
        yabai -m signal --add event=window_destroyed action="reposition_windows"

        # Mission control events
        yabai -m signal --add event=mission_control_exit action='
          yabai -m config active_window_opacity 1.0
          reposition_windows
        '
        yabai -m signal --add event=mission_control_enter action='
          yabai -m config normal_window_opacity 1.0
          reposition_windows
        '

        # Combined rules for fixed size windows and window management
        yabai -m rule --add app="^Signal$" manage=off space=2 sticky=off opacity=1.0
        yabai -m rule --add app="^Google Meet$" manage=off space=2 sticky=off opacity=1.0
        yabai -m rule --add app="^zoom.us$" manage=off space=2 sticky=off opacity=1.0
        yabai -m rule --add app="^Slack$" manage=off space=2 sticky=off opacity=1.0
        yabai -m rule --add app="^Warp$" manage=off space=2 sticky=off opacity=0.8
        yabai -m rule --add app="^Cursor$" manage=off space=2 sticky=off opacity=1.0
        yabai -m rule --add app="^YouTube$" manage=off space=2 sticky=off opacity=1.0

        function reposition_windows() {
            # First ensure all windows are on the right display and space
            windows=$(yabai -m query --windows)
            
            # Get window IDs regardless of current space/display
            signal_id=$(echo "$windows" | jq '.[] | select(.app=="Signal") | .id')
            warp_id=$(echo "$windows" | jq '.[] | select(.app=="Warp") | .id')
            cursor_id=$(echo "$windows" | jq '.[] | select(.app=="Cursor") | .id')
            youtube_id=$(echo "$windows" | jq '.[] | select(.app=="YouTube") | .id')

            if [ -n "$signal_id" ] && [ -n "$warp_id" ] && [ -n "$cursor_id" ] && [ -n "$youtube_id" ]; then
                echo "Found all windows, preparing to move..."
                
                # First ensure all windows are unmanaged
                for id in $signal_id $warp_id $cursor_id $youtube_id; do
                    # Check if window is managed
                    is_managed=$(yabai -m query --windows --window $id | jq '."is-floating" | not')
                    if [ "$is_managed" = "true" ]; then
                        yabai -m window $id --toggle float
                    fi
                done

                # Then move windows to correct display/space
                for id in $signal_id $warp_id $cursor_id $youtube_id; do
                    # First move to display 2
                    current_display=$(yabai -m query --windows --window $id | jq '.display')
                    if [ "$current_display" != "2" ]; then
                        yabai -m window $id --display 2
                    fi
                    # Then move to space 4
                    current_space=$(yabai -m query --windows --window $id | jq '.space')
                    if [ "$current_space" != "4" ]; then
                        yabai -m window $id --space 4
                    fi
                done

                # Wait a moment for windows to settle
                sleep 0.5
                
                # Get display dimensions for positioning
                display_info=$(yabai -m query --displays | jq '.[] | select(.index == 2)')
                display_width=$(echo "$display_info" | jq '.frame.w | floor')
                display_height=$(echo "$display_info" | jq '.frame.h | floor')
                display_x=$(echo "$display_info" | jq '.frame.x | floor')
                display_y=$(echo "$display_info" | jq '.frame.y | floor')
                
                # Calculate window positions and sizes
                left_width=$(( display_width / 5 ))
                middle_width=$(( display_width * 3 / 5 ))
                right_width=$(( display_width / 5 ))
                half_height=$(( display_height / 2 ))
                
                # Position Signal at top-left
                yabai -m window $signal_id --move abs:$((display_x)):$((display_y))
                yabai -m window $signal_id --resize abs:$left_width:$half_height

                # Position Warp below Signal
                yabai -m window $warp_id --move abs:$((display_x)):$((display_y + half_height))
                yabai -m window $warp_id --resize abs:$left_width:$half_height

                # Position Cursor in middle (larger space)
                yabai -m window $cursor_id --move abs:$((display_x + left_width)):$((display_y))
                yabai -m window $cursor_id --resize abs:$middle_width:$display_height

                # Position YouTube on right
                right_x=$((display_x + left_width + middle_width))
                yabai -m window $youtube_id --move abs:$right_x:$((display_y))
                yabai -m window $youtube_id --resize abs:$right_width:$display_height

                echo "Windows positioned successfully"
            else
                echo "Not all required windows found"
            fi
        }
        reposition_windows
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
  };

  homebrew = {
    enable = true;

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
        
        # Create temp file with rules content
        TEMP_FILE=''$(mktemp)
        cat > "''$TEMP_FILE" << 'EOF'
{
    "description": "Section (§) to a Hyper Key",
    "manipulators": [
        {
            "from": {
                "key_code": "non_us_backslash",
                "modifiers": { "optional": ["any"] }
            },
            "to": [{ "key_code": "f19" }],
            "to_if_alone": [{ "key_code": "escape" }],
            "type": "basic"
        },
        {
            "from": {
                "key_code": "f19",
                "modifiers": { "optional": ["any"] }
            },
            "to": [
                {
                    "key_code": "left_shift",
                    "modifiers": ["left_command", "left_control", "left_option"]
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
          echo "Configuring Karabiner-Elements at ''${KARABINER_FILE}"

          # Ensure directory exists
          mkdir -p "''$KARABINER_CONFIG_DIR"

          # Create default config if it doesn't exist
          if [ ! -f "''$KARABINER_FILE" ]; then
            echo '{"profiles":[{"name":"Default profile","selected":true,"virtual_hid_keyboard":{"keyboard_type_v2":"ansi"},"complex_modifications":{"rules":[]}}]}' > "''$KARABINER_FILE"
          fi

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
          ' "''$KARABINER_FILE" > "''${KARABINER_FILE}.tmp" && mv "''${KARABINER_FILE}.tmp" "''$KARABINER_FILE"

          # Ensure configuration is loaded
          KARABINER_CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
          if [ -x "''${KARABINER_CLI}" ]; then
            # Select the default profile to ensure changes are applied
            "''${KARABINER_CLI}" --select-profile 'Default profile' || true
            # Copy to system default to ensure persistence
            "''${KARABINER_CLI}" --copy-current-profile-to-system-default-profile || true
          else
            echo "Warning: karabiner_cli not found at ''${KARABINER_CLI}"
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
      enableSudoTouchIdAuth = true;
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
