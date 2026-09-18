{ config, lib, pkgs, ... }:

# `ccr <name> [args...]` resumes the Claude Code session named <name>, creating it under
# that name on first launch. Bare `ccr` just launches claude. `ccw` is the identical
# launcher pinned to the work profile.
#
# One launcher per account profile:
#   ccr -> ~/.claude       (personal, danny@froberg.org)
#   ccw -> ~/.claude-work  (eeze,     danny.froberg@eeze.com)
#
# Each PINS CLAUDE_CONFIG_DIR rather than inheriting it: the launcher IS the explicit
# account choice, so it must beat ambient env (e.g. a direnv-exported CLAUDE_CONFIG_DIR
# in ~/eeze) in either direction. Limits failover = exit, relaunch with the other
# launcher — the shared projects/ symlink below means either one resumes any named
# session. Never /login to switch accounts: that rebinds the profile silently and the
# ccw tabs then bill the wrong quota with nothing but /status to show for it.
#
# A package (writeShellScriptBin), NOT a zsh function: it only execs `claude`, and it has
# to be callable from Warp's launch-config `exec:` and from any other shell, none of which
# source .zshrc functions. Used by .config/warp/launch_configurations/Eeze-sre.yaml.
#
# --dangerously-skip-permissions lives HERE rather than as
# `permissions.defaultMode = "bypassPermissions"` in ~/.claude/settings.json on purpose:
# settings.json applies the bypass to every `claude` on the machine, hand-launched ones
# included. Scoping it to `ccr`/`ccw` keeps the blast radius to the tabs deliberately
# opened that way. (settings.json is claude-sync's anyway -- see claude-mcp.nix.)
#
# Why the existence check instead of plain `--resume NAME || claude -n NAME`: verified on
# 2.1.245 that `claude --resume <unknown-name>` does NOT fail -- it opens the interactive
# picker with 'No sessions match "<name>"' and sits there, so the `||` never fires on a
# first launch. Session names are stored per project as a
# {"type":"custom-title","customTitle":"<name>",...} record inside
# $CLAUDE_CONFIG_DIR/projects/<cwd with every non-alnum char -> '-'>/<session>.jsonl, so
# look for that before deciding. The `||` is kept only as a safety net for a missed match.
let
  homeDir = config.home.homeDirectory;

  mkLauncher = bin: cfgDir: pkgs.writeShellScriptBin bin ''
    set -uo pipefail

    export CLAUDE_CONFIG_DIR="${homeDir}/${cfgDir}"

    CLAUDE="''${CLAUDE_BIN:-$HOME/.local/bin/claude}"
    [ -x "$CLAUDE" ] || CLAUDE="$(command -v claude || true)"
    if [ -z "$CLAUDE" ]; then
      echo "${bin}: no claude binary found" >&2
      exit 127
    fi

    FLAGS=(--dangerously-skip-permissions)

    if [ "$#" -eq 0 ]; then
      exec "$CLAUDE" "''${FLAGS[@]}"
    fi

    NAME="$1"; shift

    # Named session already exists for this cwd? Same project-dir encoding claude uses.
    ENC="$(printf '%s' "$PWD" | ${pkgs.gnused}/bin/sed 's#[^A-Za-z0-9]#-#g')"
    PROJ="$CLAUDE_CONFIG_DIR/projects/$ENC"
    if ${pkgs.gnugrep}/bin/grep -qsF -- "\"customTitle\":\"$NAME\"" "$PROJ"/*.jsonl; then
      "$CLAUDE" "''${FLAGS[@]}" --resume "$NAME" "$@" \
        || exec "$CLAUDE" "''${FLAGS[@]}" -n "$NAME" "$@"
    else
      exec "$CLAUDE" "''${FLAGS[@]}" -n "$NAME" "$@"
    fi
  '';

  ccr = mkLauncher "ccr" ".claude";
  ccw = mkLauncher "ccw" ".claude-work";

  # The work profile is "personal minus credentials": everything claude-sync manages,
  # plus the sessions themselves, is a symlink into ~/.claude, so both accounts run one
  # set of settings/skills/sessions and claude-sync keeps syncing from work sessions
  # (the physical paths stay canon). keybindings.json does not exist yet -- the link
  # dangles harmlessly (ENOENT = no keybindings) and goes live if the file appears.
  #
  # Deliberately NOT symlinked, must stay per-profile:
  #   .credentials.json / Keychain entry  -- separate auth is the whole point
  #   .claude.json                        -- account state, trust decisions, user-scope
  #                                          MCP registrations (claude-mcp.nix registers
  #                                          those into each profile separately)
  shared = [
    "projects"
    "settings.json"
    "CLAUDE.md"
    "keybindings.json"
    "mcp_settings.json"
    "skills"
    "agents"
    "commands"
    "hooks"
  ];
in
{
  home.packages = [ ccr ccw ];

  home.file = lib.listToAttrs (map (p: {
    name = ".claude-work/${p}";
    value.source = config.lib.file.mkOutOfStoreSymlink "${homeDir}/.claude/${p}";
  }) shared);
}
