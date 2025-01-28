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

  fonts.packages = [
    pkgs.atkinson-hyperlegible
    pkgs.jetbrains-mono
  ];

  services = {
    nix-daemon.enable = true;
    yabai = {
      enable = true;
      config = {
        layout = "bsp";
        mouse_modifier = "ctrl";
        mouse_drop_action = "stack";
        window_shadow = "float";
        window_gap = "10";
        focus_follows_mouse = "autofocus";
        mouse_follows_focus = "off";
      };
      extraConfig = ''
        # Name displays using display ID (more stable than index)
        yabai -m display 1 --name north  # Built-in/Main display
        yabai -m display 3 --name south  # External display

        # Set up spaces
        yabai -m space 1 --label code
        yabai -m space 2 --label docs
        yabai -m space 3 --label chat
        yabai -m space 5 --label external

        # Basic window settings
        yabai -m config layout bsp
        yabai -m config window_placement second_child
        yabai -m config split_ratio 0.75
        yabai -m config auto_balance off
        yabai -m config window_origin_display default

        # Rules for external display apps
        yabai -m rule --add app="^Cursor$" space=external manage=on
        yabai -m rule --add app="^Google Chrome$" space=external manage=on
        yabai -m rule --add app="^Warp$" space=external manage=on sub-layer=below sticky=off layer=normal

        # Layout setup for external display
        yabai -m signal --add event=window_created action='
          if yabai -m query --displays | jq ". | length > 1"; then
            window_id=$YABAI_WINDOW_ID
            app_name=$(yabai -m query --windows --window "$window_id" | jq -r ".app")
            space_index=$(yabai -m query --spaces --window "$window_id" | jq ".[0].index")
            
            case "$app_name" in
              "Cursor")
                yabai -m window "$window_id" --move abs:864:-1415
                yabai -m window "$window_id" --resize abs:2555:1415
                ;;
              "Warp")
                yabai -m window "$window_id" --move abs:2535:-1415
                yabai -m window "$window_id" --resize abs:883:720
                ;;
              "Google Chrome")
                # First, check if Warp exists in the same space
                warp_id=$(yabai -m query --windows --space "$space_index" | jq -r '.[] | select(.app=="Warp") | .id')
                if [ ! -z "$warp_id" ]; then
                  # If Warp exists, stack Chrome on top of it
                  yabai -m window "$window_id" --stack "$warp_id"
                  yabai -m window "$window_id" --move abs:2535:-685
                  yabai -m window "$window_id" --resize abs:883:684
                else
                  # If Warp doesn't exist, just position Chrome
                  yabai -m window "$window_id" --move abs:2535:-685
                  yabai -m window "$window_id" --resize abs:883:684
                fi
                ;;
            esac
          fi
        '

        # Add a signal for when windows are destroyed to maintain stack
        yabai -m signal --add event=window_destroyed action='
          space_index=$(yabai -m query --spaces --space | jq ".[0].index")
          chrome_windows=$(yabai -m query --windows --space "$space_index" | jq -r '.[] | select(.app=="Google Chrome") | .id')
          warp_id=$(yabai -m query --windows --space "$space_index" | jq -r '.[] | select(.app=="Warp") | .id')
          
          if [ ! -z "$warp_id" ] && [ ! -z "$chrome_windows" ]; then
            echo "$chrome_windows" | while read -r chrome_id; do
              yabai -m window "$chrome_id" --stack "$warp_id"
            done
          fi
        '

        # Add a signal for when displays are added
        yabai -m signal --add event=display_added action='
          if yabai -m query --displays | jq ". | length > 1"; then
            space_index=5  # external space
            
            # Move and resize Cursor
            cursor_id=$(yabai -m query --windows --space "$space_index" | jq -r '.[] | select(.app=="Cursor") | .id')
            if [ ! -z "$cursor_id" ]; then
              yabai -m window "$cursor_id" --move abs:864:-1415
              yabai -m window "$cursor_id" --resize abs:2555:1415
            fi
            
            # Move and resize Warp
            warp_id=$(yabai -m query --windows --space "$space_index" | jq -r '.[] | select(.app=="Warp") | .id')
            if [ ! -z "$warp_id" ]; then
              yabai -m window "$warp_id" --move abs:2535:-1415
              yabai -m window "$warp_id" --resize abs:883:720
            fi
            
            # Move and resize Chrome windows and stack them
            if [ ! -z "$warp_id" ]; then
              yabai -m query --windows --space "$space_index" | jq -r '.[] | select(.app=="Google Chrome") | .id' | while read chrome_id; do
                yabai -m window "$chrome_id" --move abs:2535:-685
                yabai -m window "$chrome_id" --resize abs:883:684
                yabai -m window "$chrome_id" --stack "$warp_id"
              done
            fi
          fi
        '

        # South display rules
        yabai -m rule --add app="^OBS$" display=south space=chat
        yabai -m rule --add app="^Spotify$" display=south space=chat
        yabai -m rule --add app="^Joplin$" display=south space=docs

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

        # Padding
        yabai -m config top_padding    10
        yabai -m config bottom_padding 10
        yabai -m config left_padding   10
        yabai -m config right_padding  10
      '';
    };
    jankyborders = {
      enable = true;
      blur_radius = 5.0;
      hidpi = true;
      active_color = "0xAAB279A7";
      inactive_color = "0x33867A74";
    };
    skhd = {
      enable = true;
      skhdConfig = ''
        # float / unfloat window
        shift + alt - space : yabai -m window --toggle float; yabai -m window --grid 4:4:1:1:2:2

        # toggle sticky, topmost, pip
        shift + alt - s : yabai -m window --toggle sticky
        shift + alt - t : yabai -m window --toggle topmost
        shift + alt - p : yabai -m window --toggle pip

        # Space navigation
        alt - 1 : yabai -m space --focus 1
        alt - 2 : yabai -m space --focus 2
        alt - 3 : yabai -m space --focus 3
        alt - 4 : yabai -m space --focus 4
        alt - 5 : yabai -m space --focus 5

        # Move window to space and follow focus
        shift + alt - 1 : yabai -m window --space 1; yabai -m space --focus 1
        shift + alt - 2 : yabai -m window --space 2; yabai -m space --focus 2
        shift + alt - 3 : yabai -m window --space 3; yabai -m space --focus 3
        shift + alt - 4 : yabai -m window --space 4; yabai -m space --focus 4
        shift + alt - 5 : yabai -m window --space 5; yabai -m space --focus 5

        # Create and destroy spaces
        shift + cmd - n : yabai -m space --create
        shift + cmd - d : yabai -m space --destroy

        # Fast focus desktop
        cmd + alt - x : yabai -m space --focus recent
        cmd + alt - z : yabai -m space --focus prev || skhd -k "ctrl + alt + cmd - z"
        cmd + alt - c : yabai -m space --focus next || skhd -k "ctrl + alt + cmd - c"
        cmd + alt - 1 : yabai -m space --focus  1 || skhd -k "ctrl + alt + cmd - 1"
        cmd + alt - 2 : yabai -m space --focus  2 || skhd -k "ctrl + alt + cmd - 2"
        cmd + alt - 3 : yabai -m space --focus  3 || skhd -k "ctrl + alt + cmd - 3"
        cmd + alt - 4 : yabai -m space --focus  4 || skhd -k "ctrl + alt + cmd - 4"
        cmd + alt - 5 : yabai -m space --focus  5 || skhd -k "ctrl + alt + cmd - 5"

        # Focus display
        alt - tab : yabai -m display --focus recent

        # Window movement
        shift + alt - h : yabai -m window --warp west
        shift + alt - j : yabai -m window --warp south
        shift + alt - k : yabai -m window --warp north
        shift + alt - l : yabai -m window --warp east

        # Window resize
        shift + cmd - h : yabai -m window --resize left:-50:0; yabai -m window --resize right:-50:0
        shift + cmd - j : yabai -m window --resize bottom:0:50; yabai -m window --resize top:0:50
        shift + cmd - k : yabai -m window --resize top:0:-50; yabai -m window --resize bottom:0:-50
        shift + cmd - l : yabai -m window --resize right:50:0; yabai -m window --resize left:50:0

        # Balance size of windows
        shift + alt - 0 : yabai -m space --balance

        # Rotate windows clockwise and anticlockwise
        alt - r         : yabai -m space --rotate 90
        shift + alt - r : yabai -m space --rotate 270

        # Flip along y-axis
        shift + alt - y : yabai -m space --mirror y-axis

        # Flip along x-axis
        shift + alt - x : yabai -m space --mirror x-axis

        # Mouse support
        # Left click + cmd - drag to move window
        cmd + ctrl - m : yabai -m config mouse_modifier cmd
        # Left click + alt - drag to resize window
        cmd + ctrl - r : yabai -m config mouse_modifier alt
        # Restore default
        cmd + ctrl - 0 : yabai -m config mouse_modifier ctrl

        # Focus window
        alt - h : yabai -m window --focus west
        alt - j : yabai -m window --focus south
        alt - k : yabai -m window --focus north
        alt - l : yabai -m window --focus east
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
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceSystemPolicyAllFiles" = {
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceAppleEvents" = {
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceScreenCapture" = {
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceListenEvent" = {
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServicePostEvent" = {
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceDeveloperTool" = {
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceSystemPolicyAdminFiles" = {
            "com.warp.Warp" = {
              allowed = 1;
              prompt-count = 1;
            };
          };
          "kTCCServiceSystemPolicySysAdminFiles" = {
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
        sudo sed -i "" "/pam_tid.so/d" /etc/pam.d/sudo
        sudo sed -i "" '1a\
auth       sufficient     pam_tid.so
' /etc/pam.d/sudo

        # Add Warp to admin group
        echo "Adding Warp to admin group..."
        sudo security authorizationdb write system.privilege.admin allow
        sudo security authorizationdb write system.preferences allow
        sudo security authorizationdb write com.apple.system-extensions.admin allow
      '';
    };
  };
  security = {
    pam = {
      enableSudoTouchIdAuth = true;
    };
  };
  
}
