# dotnix

This is to describe the barebones development system I use. Supports NixOS on WSL, Intel and Silicon Macs.

Featuring:
- Wezterm
- Tmux
- Fish
- Neovim
- OSX
  - darwin-nix
  - Hammerspoon
  - homebrew mas
  - aerospace

## Install Nix

On OSX: [Determinate Systems Installer](https://github.com/DeterminateSystems/nix-installer).
On WSL2: [WSL2 Nix](https://github.com/nix-community/NixOS-WSL?tab=readme-ov-file)

~~~
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install
~~~

## Bootstrap

> [!WARNING]
> I haven't tested bootstrapping this yet, especially on an "unknown" host.

### NixOS (currently just WSL)

`sudo nixos-install --flake github:dfroberg/dotnix2#nixos`

### Darwin/Linux

1. First, backup your existing configuration files:
```bash
sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
```

2. Clone the repository:
```bash
git clone https://github.com/dfroberg/dotnix2.git ~/dotnix2
cd ~/dotnix2
```

3. For a new machine, check your hostname:
```bash
scutil --get LocalHostName
```

4. Add your machine to flake.nix if it's not already there:
```nix
darwinConfigurations."your-hostname" = darwinSystem {
  user = "your-username";
  arch = "aarch64-darwin"; # Use this for Apple Silicon, or "x86_64-darwin" for Intel
};
```

5. Apply the configuration:
```bash
nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .
```

## Troubleshooting

### Hash Mismatches

If you encounter hash mismatches when building, try these steps in order:

1. Update the flake inputs:
```bash
nix flake update
```

2. If that doesn't work, try cleaning the store:
```bash
nix store gc
nix-collect-garbage -d
```

3. If you still get hash mismatches, try forcing a re-fetch:
```bash
rm -rf ~/.cache/nix
nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake . --recreate-lock-file
```

4. As a last resort, you can try with the `--impure` flag:
```bash
nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake . --impure
```

## Update

### NixOS

`sudo nixos-rebuild switch --flake ~/src/github.com/dfroberg/dotnix2`

### Darwin

`darwin-rebuild switch --flake ~/src/github.com/dfroberg/dotnix2`

## Home Manager

You could use something like this to import my home-manager standalone.

```nix
{ config, pkgs, ... }: {
  home-manager.users.dfroberg = import ./home-manager/home.nix;
}
```
