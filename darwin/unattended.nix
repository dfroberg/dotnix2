{ pkgs, ... }:

# Makes `nud` safe to run unattended — e.g. from the Claude mobile client, where
# there is no TTY and no Touch ID. Two failure modes this addresses:
#
#  1. `brew bundle` during activation can block FOREVER. When a cask needs a
#     privileged install, Homebrew shells out to `sudo` and waits on a TTY that
#     isn't there (observed: 19 min elapsed, 0.01s CPU — blocked, not working).
#     Homebrew switches to `sudo -A` (askpass) whenever SUDO_ASKPASS is set:
#       Library/Homebrew/system_command.rb:298
#       askpass_flags = ENV.key?("SUDO_ASKPASS") ? ["-A"] : []
#     Pointing that at a deny-helper converts an unbounded hang into an immediate,
#     visible failure — which the next switch simply retries.
#
#  2. Recovering from a stuck switch requires root, which the sudoers allowlist did
#     not grant, so a hung run could not be cleared remotely. `nud-abort` fixes that.
let
  # Supplies no password and fails, so `sudo -A` gives up at once instead of blocking.
  brew-askpass-deny = pkgs.writeShellScriptBin "brew-askpass-deny" ''
    echo "brew: refusing interactive sudo during unattended activation; run 'nud' at the laptop for casks needing a privileged install" >&2
    exit 1
  '';

  # Clears a stuck `nud`: kills the activation tree, then the locks it left behind.
  nud-abort = pkgs.writeShellScriptBin "nud-abort" ''
    set -uo pipefail
    echo "[nud-abort] clearing a stuck activation…"
    pkill -f 'darwin-rebuild switch' 2>/dev/null && echo "  killed darwin-rebuild" || echo "  no darwin-rebuild running"
    pkill -f 'brew bundle --file='  2>/dev/null && echo "  killed brew bundle"    || echo "  no brew bundle running"
    # Homebrew leaves lock files behind when killed; stale ones block the next run.
    if [ -d /opt/homebrew/var/homebrew/locks ]; then
      find /opt/homebrew/var/homebrew/locks -type f -delete 2>/dev/null || true
      echo "  cleared homebrew locks"
    fi
    echo "[nud-abort] done — safe to run nud again"
  '';
in
{
  environment.systemPackages = [ nud-abort brew-askpass-deny ];

  # Read by brew on every invocation, however activation calls it — activation uses
  # `sudo --preserve-env=PATH`, which drops all other env vars, so this file is the
  # only reliable channel. brew only honours HOMEBREW_*, SUDO_ASKPASS and *_proxy here
  # (see the filter in /opt/homebrew/bin/brew: export_homebrew_env_file).
  environment.etc."homebrew/brew.env".text = ''
    SUDO_ASKPASS=${brew-askpass-deny}/bin/brew-askpass-deny
    HOMEBREW_NO_ASK=1
    HOMEBREW_NO_ENV_HINTS=1
  '';
}
