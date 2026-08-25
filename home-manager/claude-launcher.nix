{ pkgs, ... }:

# `ccr <name> [args...]` resumes the Claude Code session named <name>, creating it under
# that name on first launch. Bare `ccr` just launches claude.
#
# A package (writeShellScriptBin), NOT a zsh function: it only execs `claude`, and it has
# to be callable from Warp's launch-config `exec:` and from any other shell, none of which
# source .zshrc functions. Used by .config/warp/launch_configurations/Eeze-sre.yaml.
#
# --dangerously-skip-permissions lives HERE rather than as
# `permissions.defaultMode = "bypassPermissions"` in ~/.claude/settings.json on purpose:
# settings.json applies the bypass to every `claude` on the machine, hand-launched ones
# included. Scoping it to `ccr` keeps the blast radius to the tabs deliberately opened
# that way. (settings.json is claude-sync's anyway -- see claude-mcp.nix.)
#
# Why the existence check instead of plain `--resume NAME || claude -n NAME`: verified on
# 2.1.245 that `claude --resume <unknown-name>` does NOT fail -- it opens the interactive
# picker with 'No sessions match "<name>"' and sits there, so the `||` never fires on a
# first launch. Session names are stored per project as a
# {"type":"custom-title","customTitle":"<name>",...} record inside
# ~/.claude/projects/<cwd with every non-alnum char -> '-'>/<session>.jsonl, so look
# for that before deciding. The `||` is kept only as a safety net for a missed match.
let
  ccr = pkgs.writeShellScriptBin "ccr" ''
    set -uo pipefail

    CLAUDE="''${CLAUDE_BIN:-$HOME/.local/bin/claude}"
    [ -x "$CLAUDE" ] || CLAUDE="$(command -v claude || true)"
    if [ -z "$CLAUDE" ]; then
      echo "ccr: no claude binary found" >&2
      exit 127
    fi

    FLAGS=(--dangerously-skip-permissions)

    if [ "$#" -eq 0 ]; then
      exec "$CLAUDE" "''${FLAGS[@]}"
    fi

    NAME="$1"; shift

    # Named session already exists for this cwd? Same project-dir encoding claude uses.
    ENC="$(printf '%s' "$PWD" | ${pkgs.gnused}/bin/sed 's#[^A-Za-z0-9]#-#g')"
    PROJ="''${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$ENC"
    if ${pkgs.gnugrep}/bin/grep -qsF -- "\"customTitle\":\"$NAME\"" "$PROJ"/*.jsonl; then
      "$CLAUDE" "''${FLAGS[@]}" --resume "$NAME" "$@" \
        || exec "$CLAUDE" "''${FLAGS[@]}" -n "$NAME" "$@"
    else
      exec "$CLAUDE" "''${FLAGS[@]}" -n "$NAME" "$@"
    fi
  '';
in
{
  home.packages = [ ccr ];
}
