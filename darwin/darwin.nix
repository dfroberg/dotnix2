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
      };
      extraConfig = ''
        yabai -m space 1 --label code
        yabai -m space 2 --label docs
        yabai -m space 3 --label chat
        yabai -m signal --add event=display_added action="yabai -m rule --remove label=calendar && yabai -m rule --add app='Fantastical' label='calendar' display=south" active=yes
        yabai -m signal --add event=display_removed action="yabai -m rule --remove label=calendar && yabai -m rule --add app='Fantastical' label='calendar' native-fullscreen=on" active=yes
        yabai -m rule --add app='OBS' display=south --space=chat
        yabai -m rule --add app='Spotify' display=north --space=chat
        yabai -m rule --add app='Cursor' display=north --space=code
        yabai -m rule --add app='Warp' display=south --space=code
        yabai -m rule --add app='Joplin' display=south --space=docs
      '';
    };
    jankyborders = {
      enable = true;
      blur_radius = 5.0;
      hidpi = true;
      active_color = "0xAAB279A7";
      inactive_color = "0x33867A74";
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
      # "Drafts" = 1435957248;
      Tailscale = 1475387142; # App Store URL id
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
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
        TrackpadThreeFingerDrag = true;
      };
    };
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToControl = false;
    };
    activationScripts = {
      postActivation.text = ''
        # Load PAM module for sudo Touch ID authentication
        # Remove any existing Touch ID configuration
        sudo sed -i "" "/pam_tid.so/d" /etc/pam.d/sudo
        # Insert Touch ID authentication at the beginning of the auth section
        sudo sed -i "" '1a\
auth       sufficient     pam_tid.so
' /etc/pam.d/sudo
      '';
    };
  };
  security = {
    pam = {
      enableSudoTouchIdAuth = true;
    };
  };
  
}
