{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.aerospace;
in {
  options.programs.aerospace = {
    enable = mkEnableOption "Aerospace window manager";
    
    package = mkOption {
      type = types.package;
      default = pkgs.aerospace;
      description = "The Aerospace package to use.";
    };
    
    settings = mkOption {
      type = types.attrs;
      default = {};
      description = "Aerospace configuration settings.";
    };
    
    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a static aerospace.toml configuration file.";
    };
  };
  
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      aerospace
      jankyborders
      sketchybar
    ];
    
    # Create an activation script to symlink the aerospace.toml file
    home.activation.linkAerospaceConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      echo "Creating symlink for aerospace.toml..."
      mkdir -p ${config.home.homeDirectory}/.config/aerospace
      rm -f ${config.home.homeDirectory}/.config/aerospace/aerospace.toml
      ln -sf ${config.home.homeDirectory}/dotnix/.config/aerospace/aerospace.toml ${config.home.homeDirectory}/.config/aerospace/aerospace.toml
      echo "Symlink created."
    '';
    
    # Create a launchd service for Aerospace
    launchd.agents.aerospace = {
      enable = true;
      config = {
        ProgramArguments = [ "${cfg.package}/bin/aerospace" ];
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/aerospace.log";
        StandardErrorPath = "/tmp/aerospace.error.log";
      };
    };
  };
} 