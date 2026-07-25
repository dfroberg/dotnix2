{ config, lib, pkgs, ... }:

# Ensures the jCodeMunch -> TokenSave -> GitNexus code-intel MCP stack is set up
# per machine. The RUNTIMES are declarative elsewhere (uv, nodejs in home.packages;
# tokensave in homebrew.brews). This module does the machine-specific bits that can't
# be a plain package: installs the jCodeMunch uv tool + its watch LaunchAgent, and
# registers the three MCP servers at USER scope in ~/.claude.json. It only touches
# ~/.claude.json (NOT claude-synced) + machine-local state; it never edits the
# claude-synced CLAUDE.md / settings.json (those carry the hooks/policy via claude-sync).
let
  claude-mcp-setup = pkgs.writeShellScriptBin "claude-mcp-setup" ''
    set -uo pipefail   # NOT -e: best-effort, never abort a switch
    export PATH="$HOME/.local/bin:${pkgs.uv}/bin:${pkgs.nodejs}/bin:/opt/homebrew/bin:$PATH"
    log(){ printf '[claude-mcp-setup] %s\n' "$*"; }

    # True if a server is already registered. Uses claude's own source of truth:
    # `mcp get` exits 0 when present, non-zero when missing, and (unlike `mcp list`)
    # does not health-check/spawn every configured server. Deliberately NOT a python3
    # read of ~/.claude.json -- that depended on python3 being on the activation PATH,
    # silently returned "missing" when it wasn't, and made every run re-attempt an
    # `mcp add` that then failed with "already exists in user config".
    mcp_has(){ claude mcp get "$1" >/dev/null 2>&1; }

    log "context: user=$(id -un) HOME=$HOME claude=$(command -v claude || echo MISSING)"

    reg(){ # <name> <command> [args...]
      local n="$1"; shift
      if mcp_has "$n"; then log "$n already registered"; return 0; fi
      if ! command -v claude >/dev/null 2>&1; then log "$n: claude CLI not on PATH"; return 1; fi
      # Keep the error: silently discarding it made an activation-context failure
      # impossible to diagnose from the switch output.
      local out
      if out=$(claude mcp add --scope user "$n" -- "$@" 2>&1); then
        log "registered $n"
      else
        log "$n registration failed: $out"
      fi
    }

    # jCodeMunch (precision): uv tool + background watch LaunchAgent
    # The [watch] extra is REQUIRED, not optional: it pulls in watchfiles, and without
    # it every watch task dies at startup with "watchfiles is required for the watch
    # subcommand", is restarted, re-runs a full initial index, and dies again -- forever.
    # Observed on a plain `uv tool install jcodemunch-mcp`: 2.6 cores burned continuously
    # and a 2.5 GB watch.err. --force so an existing extras-less install gets corrected.
    if command -v uv >/dev/null 2>&1; then
      uv tool install --force 'jcodemunch-mcp[watch]' >/dev/null 2>&1 && log "jcodemunch uv tool present (with watch extra)" \
        || log "jcodemunch uv tool install skipped (offline?)"
    fi
    command -v jcodemunch-mcp >/dev/null 2>&1 \
      && { jcodemunch-mcp watch-install >/dev/null 2>&1 && log "jcodemunch watch agent ensured" || true; }

    # TokenSave (semantic) comes from brew: needs `brew trust aovestdipaperino/tap` (Homebrew 6.x).
    command -v tokensave >/dev/null 2>&1 || log "tokensave missing — 'brew trust aovestdipaperino/tap' then nud"

    # Register the three MCP servers at user scope (idempotent).
    reg jcodemunch uvx jcodemunch-mcp
    reg tokensave  /opt/homebrew/bin/tokensave serve
    reg gitnexus   npx -y gitnexus mcp

    if mcp_has jcodemunch && mcp_has tokensave && mcp_has gitnexus; then
      log "code-intel MCP stack ready"; exit 0
    else
      log "incomplete (retry next switch)"; exit 1
    fi
  '';
in
{
  home.packages = [ claude-mcp-setup ];

  # Run once per machine (sentinel-guarded). Retries next switch if it failed (e.g.
  # offline / tap not trusted). Bump the .vN suffix to force a re-run after edits.
  home.activation.setupCodeIntelMcp = lib.hm.dag.entryAfter [ "installPackages" ] ''
    SENTINEL="${config.home.homeDirectory}/.claude/.code-intel-setup.v1"
    if [ ! -f "$SENTINEL" ]; then
      echo "Setting up code-intel MCP stack (jcodemunch/tokensave/gitnexus)…"
      # Runs as the user (verified: the script logs user/HOME/claude on every run),
      # so ~/.claude.json and ~/.local/bin/claude resolve correctly without sudo.
      if ${claude-mcp-setup}/bin/claude-mcp-setup; then
        mkdir -p "${config.home.homeDirectory}/.claude" && touch "$SENTINEL"
      else
        echo "code-intel MCP setup incomplete (offline / trust tap?) — will retry next switch"
      fi
    fi
  '';
}
