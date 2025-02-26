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

        # Add logging with file output
        yabai_log() {
          local log_message="[$(date '+%Y-%m-%d %H:%M:%S')] [YABAI] ''$1"
          echo "''${log_message}"
          echo "''${log_message}" >> "/tmp/yabai_window_manager.log"
        }

        # Add error handling for yabai commands
        yabai_cmd() {
          yabai -m "$@" || yabai_log "Error: yabai command failed: $*"
        }

        # Function to check if window exists
        window_exists() {
          yabai -m query --windows --window "$1" &>/dev/null
        }

        # Check if yabai is available
        if ! command -v yabai &> /dev/null; then
          yabai_log "Error: yabai not found"
          exit 1
        fi

        # Configure spaces
        yabai_log "Setting up spaces..."
        
        # Function to work with existing spaces
        setup_spaces() {
          # Get displays
          local displays=''$(yabai -m query --displays)
          local main_display=''$(echo "''${displays}" | jq -r '.[] | select(.index == 1) | .uuid')
          local second_display=''$(echo "''${displays}" | jq -r '.[] | select(.index == 2) | .uuid')
          
          yabai_log "Found displays: main=''${main_display}, second=''${second_display}"
          
          # Get all spaces
          local all_spaces=''$(yabai -m query --spaces | jq -r '.[].index')
          yabai_log "Found spaces: ''${all_spaces}"
          
          # Label existing spaces based on display
          i=1
          for space in ''${all_spaces}; do
            # Get display for this space
            local space_display=''$(yabai -m query --spaces --space ''${space} | jq -r '.display')
            
            if [ "''${space_display}" = "''${main_display}" ]; then
              # Label main display space
              yabai_log "Labeling space ''${space} as main"
              yabai -m space ''${space} --label main || yabai_log "Failed to label space ''${space}"
            elif [ "''${space_display}" = "''${second_display}" ]; then
              # Label second display spaces
              case ''${i} in
                1) 
                  yabai_log "Labeling space ''${space} as code"
                  yabai -m space ''${space} --label code || yabai_log "Failed to label space ''${space}"
                  ;;
                2) 
                  yabai_log "Labeling space ''${space} as docs"
                  yabai -m space ''${space} --label docs || yabai_log "Failed to label space ''${space}"
                  ;;
                3) 
                  yabai_log "Labeling space ''${space} as chat"
                  yabai -m space ''${space} --label chat || yabai_log "Failed to label space ''${space}"
                  ;;
                4) 
                  yabai_log "Labeling space ''${space} as social"
                  yabai -m space ''${space} --label social || yabai_log "Failed to label space ''${space}"
                  ;;
                *) 
                  yabai_log "Labeling space ''${space} as extra-''${i}"
                  yabai -m space ''${space} --label "extra-''${i}" || yabai_log "Failed to label space ''${space}"
                  ;;
              esac
              i=''$((i + 1))
            fi
          done
          
          yabai_log "Spaces labeled successfully"
        }
        
        # Set up spaces
        setup_spaces
        
        # Wait for spaces to settle
        sleep 2
        
        # Basic window settings
        yabai_cmd config layout bsp
        yabai_cmd config window_placement second_child
        yabai_cmd config split_ratio 0.50
        yabai_cmd config auto_balance off
        yabai_cmd config window_origin_display default

        # Window opacity settings
        yabai_cmd config active_window_opacity 1.0
        yabai_cmd config normal_window_opacity 0.9

        # Padding
        yabai_cmd config top_padding    5
        yabai_cmd config bottom_padding 5
        yabai_cmd config left_padding   5
        yabai_cmd config right_padding  5

        # Name displays using display ID (more stable than index)
        yabai_cmd display 1 --label main # Built-in/Main display
        yabai_cmd display 2 --label top  # External display

        # sub-layer normal
        yabai_cmd rule --add app=".*" sub-layer=normal

        # Set default split type
        yabai_cmd config split_type auto

        # Rules for unmanaged apps
        yabai_cmd rule --add app="^System Settings$" manage=off
        yabai_cmd rule --add app="^Calculator$" manage=off
        yabai_cmd rule --add app="^Karabiner-Elements$" manage=off
        yabai_cmd rule --add app="^QuickTime Player$" manage=off
        yabai_cmd rule --add app="^Finder$" manage=off
        yabai_cmd rule --add app="^Digital Color Meter$" manage=off
        yabai_cmd rule --add app="^Activity Monitor$" manage=off
        yabai_cmd rule --add app="^Path Finder$" manage=off
        yabai_cmd rule --add app="^1Password$" manage=off
        yabai_cmd rule --add app="^Raycast$" manage=off
        yabai_cmd rule --add app="^zoom.us$" manage=off
        yabai_cmd rule --add app="^Bitwarden$" manage=off
        yabai_cmd rule --add app="^OBSBOT_Main$" manage=off
        yabai_cmd rule --add app="^Finder$" manage=off
        yabai_cmd rule --add app="^Joplin$" manage=off
        yabai_cmd rule --add app="^YouTube$" manage=off
        yabai_cmd rule --add app="^Signal$" manage=off
        yabai_cmd rule --add app="^Google Meet$" manage=off
        yabai_cmd rule --add app="^Slack$" manage=off
        
        # Event handlers
        yabai_cmd signal --add event=window_created action="yabai -m query --windows --window \$YABAI_WINDOW_ID &>/dev/null || reposition_windows"
        yabai_cmd signal --add event=dock_did_restart action="sudo yabai --load-sa"
        yabai_cmd signal --add event=window_moved action="reposition_windows"
        yabai_cmd signal --add event=window_resized action="reposition_windows"
        yabai_cmd signal --add event=space_changed action="reposition_windows"
        yabai_cmd signal --add event=display_changed action="reposition_windows"
        yabai_cmd signal --add event=display_added action="reposition_windows"
        yabai_cmd signal --add event=display_removed action="reposition_windows"
        yabai_cmd signal --add event=window_focused action="reposition_windows"
        yabai_cmd signal --add event=window_destroyed action="reposition_windows"

        # Mission control events
        yabai_cmd signal --add event=mission_control_exit action='
          yabai -m config active_window_opacity 1.0
          reposition_windows
        '
        yabai_cmd signal --add event=mission_control_enter action='
          yabai -m config normal_window_opacity 1.0
          reposition_windows
        '

        # Function to reposition windows based on Hammerspoon layout
        reposition_windows() {
          yabai_log "Repositioning windows..."
          
          # Check if Hammerspoon layout file exists
          yabai_log "Searching for Hammerspoon layout file..."
          for user_home in /Users/*; do
            yabai_log "Checking user home: ''${user_home}"
            if [ -d "''${user_home}" ]; then
              # Check .hammerspoon directory
              config_dir="''${user_home}/.hammerspoon"
              LAYOUT_FILE="''${config_dir}/window_layouts.json"
              yabai_log "Checking for layout file at: ''${LAYOUT_FILE}"
              if [ -f "''${LAYOUT_FILE}" ]; then
                yabai_log "Found Hammerspoon layouts at ''${LAYOUT_FILE}"
                break
              fi
            fi
          done
          
          # If no layout file was found, create one
          if [ ! -f "''${LAYOUT_FILE}" ]; then
            yabai_log "Layout file not found, creating one"
            
            # Create directory if it doesn't exist
            mkdir -p "$(dirname "''${LAYOUT_FILE}")"
            
            # Create a basic layout file
            cat > "''${LAYOUT_FILE}" << 'EOF'
{
  "displays": {
    "main": {
      "apps": {}
    },
    "external": {
      "apps": {
        "Signal": { "x": 0, "y": 0, "w": 0.2, "h": 0.5 },
        "Warp": { "x": 0, "y": 0.5, "w": 0.2, "h": 0.5 },
        "Cursor": { "x": 0.2, "y": 0, "w": 0.6, "h": 1.0 },
        "YouTube": { "x": 0.8, "y": 0, "w": 0.2, "h": 1.0 }
      }
    }
  }
}
EOF
            yabai_log "Created layout file at ''${LAYOUT_FILE}"
          fi
          
          # Read the layout file
          yabai_log "Using Hammerspoon layouts from ''${LAYOUT_FILE}"
          LAYOUTS=$(cat "''${LAYOUT_FILE}")
          yabai_log "Layout content: ''${LAYOUTS}"
          
          # Get all running windows
          windows=$(yabai -m query --windows)
          yabai_log "Running apps: $(echo "''${windows}" | jq -r '.[].app' | sort | uniq)"
          
          # Process each app in the layout
          for display_type in main external; do
            yabai_log "Checking ''${display_type} display layouts"
            
            # Get apps for this display
            apps=$(echo "''${LAYOUTS}" | jq -r ".displays.''${display_type}.apps | keys[]" 2>/dev/null || echo "")
            
            if [ -n "''${apps}" ]; then
              yabai_log "''${display_type} display has $(echo "''${apps}" | wc -l | tr -d ' ') apps in layout"
              
              for app in ''${apps}; do
                yabai_log "Processing app: ''${app}"
                
                # Find window for this app
                window_id=$(echo "''${windows}" | jq -r ".[] | select(.app==\"''${app}\") | .id" | head -1)
                
                if [ -n "''${window_id}" ]; then
                  yabai_log "Found window for ''${app}: ''${window_id}"
                  
                  # Check if window is managed
                  is_managed=$(yabai -m query --windows --window ''${window_id} | jq '.["is-managed"]')
                  yabai_log "''${app} is_managed: ''${is_managed}"
                  
                  # Set window to floating if it's managed
                  if [ "''${is_managed}" = "true" ]; then
                    yabai_log "Setting ''${app} to floating"
                    yabai -m window ''${window_id} --toggle float
                    sleep 0.1
                  fi
                  
                  # Get layout for this app
                  x_percent=$(echo "''${LAYOUTS}" | jq -r ".displays.''${display_type}.apps.\"''${app}\".x")
                  y_percent=$(echo "''${LAYOUTS}" | jq -r ".displays.''${display_type}.apps.\"''${app}\".y")
                  w_percent=$(echo "''${LAYOUTS}" | jq -r ".displays.''${display_type}.apps.\"''${app}\".w")
                  h_percent=$(echo "''${LAYOUTS}" | jq -r ".displays.''${display_type}.apps.\"''${app}\".h")
                  
                  yabai_log "''${app} layout: x=''${x_percent}, y=''${y_percent}, w=''${w_percent}, h=''${h_percent}"
                  
                  # Define a standard grid (e.g., 20x20 for finer control)
                  grid_rows=20
                  grid_cols=20
                  
                  # Convert percentage-based layout to grid coordinates
                  grid_x=$(echo "''${x_percent} * ''${grid_cols}" | bc -l | awk '{printf "%.0f", $1}')
                  grid_y=$(echo "''${y_percent} * ''${grid_rows}" | bc -l | awk '{printf "%.0f", $1}')
                  grid_w=$(echo "''${w_percent} * ''${grid_cols}" | bc -l | awk '{printf "%.0f", $1}')
                  grid_h=$(echo "''${h_percent} * ''${grid_rows}" | bc -l | awk '{printf "%.0f", $1}')
                  
                  yabai_log "''${app} grid position: ''${grid_rows}:''${grid_cols}:''${grid_x}:''${grid_y}:''${grid_w}:''${grid_h}"
                  
                  # Apply grid positioning
                  yabai -m window ''${window_id} --grid "''${grid_rows}:''${grid_cols}:''${grid_x}:''${grid_y}:''${grid_w}:''${grid_h}"
                  
                  # Ensure window is floating
                  is_floating=$(yabai -m query --windows --window ''${window_id} | jq '."is-floating"')
                  if [ "''${is_floating}" = "false" ]; then
                    yabai_log "''${app} is not floating, forcing it"
                    yabai -m window ''${window_id} --toggle float
                    sleep 0.1
                  fi
                  
                  # Verify final position
                  final_frame=$(yabai -m query --windows --window ''${window_id} | jq '.frame')
                  yabai_log "''${app} final frame: ''${final_frame}"
                  
                  # Add a rule to keep it unmanaged
                  yabai_log "Adding rule to keep ''${app} unmanaged"
                  yabai -m rule --add app="^''${app}$" manage=off sticky=off opacity=1.0
                  
                  yabai_log "Positioned ''${app} window according to layout"
                else
                  yabai_log "Window for app ''${app} not found"
                fi
              done
            fi
          done
          
          # Final verification - log the positions of all windows
          yabai_log "Final window positions:"
          for app in $(echo "''${windows}" | jq -r '.[].app' | sort | uniq); do
            # Get window IDs for this app
            app_windows=$(echo "''${windows}" | jq -r ".[] | select(.app==\"''${app}\") | .id")
            
            for window_id in ''${app_windows}; do
              # Get window details
              window_info=$(yabai -m query --windows --window ''${window_id})
              frame=$(echo "''${window_info}" | jq '.frame')
              space=$(echo "''${window_info}" | jq '.space')
              display=$(echo "''${window_info}" | jq '.display')
              is_floating=$(echo "''${window_info}" | jq '."is-floating"')
              
              yabai_log "Window ''${window_id} (''${app}): space=''${space}, display=''${display}, floating=''${is_floating}, frame=''${frame}"
            done
          done
          
          yabai_log "Window positioning complete"
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
        
        # Add a log function
        log() {
          echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
        }

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
