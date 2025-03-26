{config, ...}:
{
  home.file = {
    ".cvsignore".source = ../.config/git/.cvsignore;
    ".gitconfig".source = ../.config/git/.gitconfig;
    ".gitconfig-tain".source = ../.config/git/.gitconfig-tain;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
  };
}
