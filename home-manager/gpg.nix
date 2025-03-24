{ config, pkgs, lib, ... }:
{
  programs.gpg = {
    enable = false;
  };

  services.gpg-agent = {
    enable = false;
  };

  home.activation.setupGpg = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [[ ! -d "$HOME/.gnupg" ]]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.gnupg"
    fi
    $DRY_RUN_CMD chmod 700 "$HOME/.gnupg"
  '';
} 