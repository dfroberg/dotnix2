{pkgs, ...}:
{
  programs.gpg = {
    enable = true;
    settings = {
      trust-model = "tofu+pgp";
    };
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentryPackage = pkgs.pinentry_mac;
    defaultCacheTtl = 3600;
    maxCacheTtl = 7200;
  };
} 