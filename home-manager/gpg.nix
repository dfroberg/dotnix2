{ config, pkgs, ... }:
{
  programs.gpg = {
    enable = true;
    settings = {
      trust-model = "tofu+pgp";
    };
    homedir = "~/.gnupg";
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry_mac;
    defaultCacheTtl = 3600;
    maxCacheTtl = 7200;
  };

  home.file.".gnupg" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.gnupg";
    recursive = true;
    mode = "0700";
  };
} 