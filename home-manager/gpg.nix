{ config, pkgs, lib, ... }:
{
  programs.gpg = {
    enable = true;
    settings = {
      trust-model = "tofu+pgp";
    };
    homedir = "${config.home.homeDirectory}/.gnupg";
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry_mac;
    defaultCacheTtl = 3600;
    maxCacheTtl = 7200;
  };

  home.activation.setupGpg = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [[ ! -d "$HOME/.gnupg" ]]; then
      $DRY_RUN_CMD mkdir -p "$HOME/.gnupg"
    fi
    $DRY_RUN_CMD chmod 700 "$HOME/.gnupg"
  '';
} 