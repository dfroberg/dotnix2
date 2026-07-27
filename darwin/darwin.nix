{ pkgs, ... }:

{
  imports = [ ./unattended.nix ];

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
  };

  homebrew = {
    enable = true;

    taps = [
      "aovestdipaperino/tap" # tokensave (jCodeMunch/TokenSave code-intel MCP)
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
      "openfortivpn" # SSL-VPN client used by vpn-connect/vpn-disconnect (deps: openssl@3, ca-certificates)
      "git-crypt" # transparent repo encryption for the ~/.claude-sync repo
      "glab" # GitLab CLI (MR/CI workflows)
      "helm" # Kubernetes package manager
      "markdownlint-cli" # provides `markdownlint` for the ~/.claude markdownlint hook
      "ruff" # fast Python linter used in workflows
      "aovestdipaperino/tap/tokensave" # code-intel MCP server (mcp__tokensave__*)
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

    # Tailscale/Slack/Bitwarden were in masApps (App Store) but aren't MAS-tracked,
    # so `mas install` failed on every switch. Declare them as casks with per-cask
    # `adopt` (nix-darwin's homebrew.casks.*.args submodule has no `adopt` option) via
    # raw Brewfile lines, so brew takes over the existing non-brew installs.
    extraConfig = ''
      cask "tailscale-app", args: { adopt: true }
      cask "slack", args: { adopt: true }
      cask "bitwarden", args: { adopt: true }
      cask "shottr", args: { adopt: true }
    '';
    # Docker Desktop is deliberately NOT adopted. Its adopt runs
    # `sudo -E -- chmod -R a+rX /Applications/Docker.app`, which macOS App Management
    # (TCC) refuses even for root -- Docker.app is owned by the user and carries no
    # restricted flags, yet the chmod still fails "Operation not permitted". No sudoers
    # rule can grant this. The failure took the whole `brew bundle` down, so every
    # switch failed; unattended it first hung 54 min waiting on that sudo password.
    # Docker Desktop stays installed and working, just not Homebrew-managed.
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

        # Determinate Nix owns /etc/nix/nix.conf, so nix-darwin's nix.settings are inert.
        # Append our custom settings to nix.custom.conf (idempotent; self-heals if
        # Determinate rewrites it). A fresh machine needs one nix-daemon restart/reboot.
        #  - @admin trusted-user: fixes devenv/direnv "you are not a trusted user".
        if ! grep -q 'extra-trusted-users' /etc/nix/nix.custom.conf 2>/dev/null; then
          echo 'extra-trusted-users = @admin' >> /etc/nix/nix.custom.conf
        fi
        #  - FlakeHub Cache substituter (its keys are already trusted in nix.conf). Needs a
        #    per-machine `determinate-nixd login`; without it nix just skips the cache (401).
        if ! grep -q 'cache.flakehub.com' /etc/nix/nix.custom.conf 2>/dev/null; then
          echo 'extra-substituters = https://cache.flakehub.com' >> /etc/nix/nix.custom.conf
        fi

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

        # Recover a hung unattended switch remotely (see darwin/unattended.nix).
        %admin ALL=(root) NOPASSWD: /run/current-system/sw/bin/nud-abort

        # System configuration commands
        %admin ALL=(root) NOPASSWD: /usr/bin/sed -i "" "/pam_tid.so/d" /etc/pam.d/sudo
        %admin ALL=(root) NOPASSWD: /usr/bin/sed -i "" "1a*" /etc/pam.d/sudo
        %admin ALL=(root) NOPASSWD: /usr/bin/security authorizationdb write system.privilege.admin allow
        %admin ALL=(root) NOPASSWD: /usr/bin/security authorizationdb write system.preferences allow
        %admin ALL=(root) NOPASSWD: /usr/bin/security authorizationdb write com.apple.system-extensions.admin allow

        # Homebrew and Application setup
        %admin ALL=(root) NOPASSWD: /opt/homebrew/bin/brew

        # openfortivpn VPN helpers (home-manager/vpn.nix). Args are pinned exactly so
        # these grant the two dial-ups and the DNS/teardown steps, nothing wider --
        # e.g. `pkill -f pppd` is allowed but `pkill -f .` is not.
        #
        # NOTE: /opt/homebrew/bin is admin-writable, so passwordless root on a binary
        # under it is only as strong as write access to that path. The `brew` line above
        # already concedes strictly more, so this adds no new exposure.
        %admin ALL=(root) NOPASSWD: /opt/homebrew/bin/openfortivpn v1-mtb.tain.com\:8443 --saml-login --trusted-cert b542a3b331b9723031cc69768e3c2bad1bfa73c1f42770d1480a03c4a4a8056e --pppd-accept-remote=0
        %admin ALL=(root) NOPASSWD: /opt/homebrew/bin/openfortivpn fg01.eeze.com\:10443 --saml-login --trusted-cert 2ddce84a1b014415f6ac5b3c0db1ac437b93785aca8520dbd64aa742e5c402db --pppd-accept-remote=0
        %admin ALL=(root) NOPASSWD: /usr/sbin/networksetup -setdnsservers Wi-Fi *
        %admin ALL=(root) NOPASSWD: /usr/bin/dscacheutil -flushcache
        %admin ALL=(root) NOPASSWD: /usr/bin/killall -HUP mDNSResponder
        %admin ALL=(root) NOPASSWD: /usr/bin/pkill -f openfortivpn
        %admin ALL=(root) NOPASSWD: /usr/bin/pkill -f pppd

      '';
    };
  };
  
}
