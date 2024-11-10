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
  - yabai

## Install Nix

On OSX: [Determinate Systems Installer](https://github.com/DeterminateSystems/nix-installer).
On WSL2: [WSL2 Nix](https://github.com/nix-community/NixOS-WSL?tab=readme-ov-file)

~~~
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install --determinate
~~~

~~~
info: downloading installer https://install.determinate.systems/nix/tag/v0.27.1/nix-installer-aarch64-darwin
 INFO nix-installer v0.27.1
`nix-installer` needs to run as `root`, attempting to escalate now via `sudo`...
 INFO nix-installer v0.27.1
Bad request.
Could not find service "systems.determinate.nix-store" in domain for system
Nix install plan (v0.27.1)
Planner: macos

Configured settings:
* determinate_nix: true

Planned actions:
* Install Determinate Nixd
* Create an encrypted APFS volume `Nix Store` for Nix on `disk3` and add it to `/etc/fstab` mounting on `/nix`
* Extract the bundled Nix (originally from /nix/store/m6z13hyfngsxklxr0bzkk0as8ns1p6ma-nix-binary-tarball-2.24.10/nix-2.24.10-aarch64-darwin.tar.xz)
* Create a directory tree in `/nix`
* Move the downloaded Nix into `/nix`
* Create build users (UID 351-382) and group (GID 350)
* Configure Time Machine exclusions
* Setup the default Nix profile
* Place the Nix configuration in `/etc/nix/nix.conf`
* Configure the shell profiles
* Configuring zsh to support using Nix in non-interactive shells
* Create a `launchctl` plist to put Nix into your PATH
* Configure the Determinate Nix daemon
* Remove directory `/nix/temp-install-dir`


Proceed? ([Y]es/[n]o/[e]xplain): Y
 INFO Step: Install Determinate Nixd
 INFO Step: Create an encrypted APFS volume `Nix Store` for Nix on `disk3` and add it to `/etc/fstab` mounting on `/nix`
 INFO Step: Provision Nix
 INFO Step: Create build users (UID 351-382) and group (GID 350)
 INFO Step: Configure Time Machine exclusions
 INFO Step: Configure Nix
 INFO Step: Configuring zsh to support using Nix in non-interactive shells
 INFO Step: Create a `launchctl` plist to put Nix into your PATH
 INFO Step: Configure the Determinate Nix daemon
 INFO Step: Remove directory `/nix/temp-install-dir`
Nix was installed successfully!
To get started using Nix, open a new shell or run `. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`
~~~

## Bootstrap

> [!WARNING]
> I haven't tested bootstrapping this yet, especially on an "unknown" host.

### NixOS (currently just WSL)

`sudo nixos-install --flake github:dfroberg/dotnix2#nixos`

### Darwin/Linux
`sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin`
`sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin`
`sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin`
`nix run nix-darwin --extra-experimental-features nix-command --extra-experimental-features flakes -- switch --flake github:dfroberg/dotnix2`

## Update

### NixOS

`sudo nixos-rebuild switch --flake ~/src/github.com/dfroberg/dotnix2`

### Darwin

`darwin-rebuild switch --flake ~/src/github.com/dfroberg/dotnix2`

## Home Manager

You could use something like this to import my home-manager standalone.

```nix
{ config, pkgs, ... }: {
  home-manager.users.evan = import ./home-manager/home.nix;
}
```
