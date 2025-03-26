{config, ...}:
{
  home.file = {
    ".cvsignore".source = ../.config/git/.cvsignore;
    ".gitconfig".source = ../.config/git/.gitconfig;
    ".gitconfig-tain".source = ../.config/git/.gitconfig-tain;
    ".gitconfig-custom".text = ''
      [includeIf "gitdir:${config.home.homeDirectory}/eeze/**/.git"]
        path = ~/.gitconfig-tain
    '';
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
  };
}
