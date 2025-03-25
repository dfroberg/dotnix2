{ config, pkgs, lib, ... }:
{
  home.file = {
    ".ssh/config".source = ../.config/.ssh/config;
  };
  home.activation.setupSsh = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [[ ! -d "$HOME/.ssh" ]]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
    fi
    $DRY_RUN_CMD chmod 700 "$HOME/.ssh"
  '';
} 