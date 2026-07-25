{ config, lib, pkgs, ... }:

# Durability for the ~/.claude memory sync. Two jobs:
#
#  1. Keep the claude-sync hooks wired into ~/.claude/settings.json. That file is
#     CONTESTED -- `tokensave install`, `jcodemunch init` and similar installers rewrite
#     it to manage their own hooks, and one of them silently dropped the claude-sync
#     entries. Nothing errored; memories just stopped syncing. It went unnoticed for a
#     day, and the stripped file was then pushed to the sync repo, so a pull on the other
#     machine would have propagated the breakage instead of repairing it.
#
#  2. Push on memory CHANGE rather than session lifecycle. SessionEnd has no documented
#     guarantee under SIGKILL/crash/terminal-close, and a long session leaves everything
#     unsynced until it ends (observed: an 8h session whose 17:00 memories were still
#     unpushed an hour later). A PostToolUse hook flags a change instantly, and a timer
#     does the actual push -- so worst-case exposure is one interval, even if Claude dies.
#     Claude Code has no periodic hooks ("hooks fire at lifecycle points, not on timers"),
#     hence a launchd agent.
let
  syncBin = "${config.home.homeDirectory}/.claude-sync/bin/claude-sync";
  dirtyFlag = "${config.home.homeDirectory}/.claude-sync/.dirty";
  syncLog = "${config.home.homeDirectory}/.claude-sync/last-sync.log";

  # Timer body. Ordering matters: clear the flag BEFORE pushing, so a memory written
  # mid-push re-flags and is caught next tick instead of being swallowed; restore it on
  # failure so a transient network error retries rather than silently dropping the work.
  pushIfDirty = pkgs.writeShellScriptBin "claude-sync-push-if-dirty" ''
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/run/current-system/sw/bin:${config.home.homeDirectory}/.nix-profile/bin:$PATH"
    [ -f "${dirtyFlag}" ] || exit 0
    rm -f "${dirtyFlag}"
    if ! GIT_TERMINAL_PROMPT=0 "${syncBin}" push >>"${syncLog}" 2>&1; then
      : > "${dirtyFlag}"   # failed (offline?) — leave it flagged for the next tick
      exit 0               # never fail the agent; launchd would just respawn it
    fi
  '';

  ensureScript = pkgs.writeText "claude-sync-hooks-ensure.py" ''
    import json, os, sys

    SETTINGS = os.path.expanduser("~/.claude/settings.json")
    HOOKS = "$HOME/.claude/hooks"
    LOG = "$HOME/.claude-sync/last-sync.log"   # log, don't discard: silent failure is
                                               # how the previous breakage stayed hidden
    # event -> (matcher, command)
    WANT = {
        "SessionStart": ("", f'GIT_TERMINAL_PROMPT=0 "$HOME/.claude-sync/bin/claude-sync" pull >>{LOG} 2>&1 || true'),
        "SessionEnd":   ("", f'GIT_TERMINAL_PROMPT=0 "$HOME/.claude-sync/bin/claude-sync" push >>{LOG} 2>&1 || true'),
        # Flags a memory change instantly; the launchd timer performs the push.
        "PostToolUse":  ("Write|Edit", f'{HOOKS}/claude-sync-mark-dirty.sh'),
    }

    if not os.path.exists(SETTINGS):
        print("no settings.json; skipping"); sys.exit(0)
    try:
        with open(SETTINGS) as f:
            cfg = json.load(f)
    except Exception as e:
        print(f"settings.json unreadable ({e}); refusing to touch it"); sys.exit(1)

    hooks = cfg.setdefault("hooks", {})
    changed = []
    for event, (matcher, command) in WANT.items():
        entries = hooks.setdefault(event, [])
        # Present already (in any matcher group)? leave it exactly as the user has it.
        if any("claude-sync" in h.get("command", "")
               for grp in entries for h in grp.get("hooks", [])):
            continue
        entry = {"matcher": matcher,
                 "hooks": [{"type": "command", "command": command, "timeout": 45}]}
        entries.append(entry)
        changed.append(event)

    if not changed:
        print("claude-sync hooks already present"); sys.exit(0)

    tmp = SETTINGS + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    os.replace(tmp, SETTINGS)   # atomic: never leave a truncated settings.json
    print("re-added claude-sync hooks: " + ", ".join(changed))
  '';
in
{
  home.packages = [ pushIfDirty ];

  # The crash-proof half: fires on a timer regardless of what Claude is doing, so
  # memories survive a killed session. Cheap -- it exits immediately unless flagged.
  launchd.agents.claude-sync-push = {
    enable = true;
    config = {
      ProgramArguments = [ "${pushIfDirty}/bin/claude-sync-push-if-dirty" ];
      StartInterval = 300;        # 5 min: bounds worst-case loss without churn
      RunAtLoad = false;          # login already triggers a SessionStart pull
      StandardOutPath = syncLog;
      StandardErrorPath = syncLog;
    };
  };

  # Every switch, deliberately NOT sentinel-guarded: the point is to self-heal after
  # another installer clobbers settings.json. /usr/bin/python3 by absolute path -- the
  # activation PATH omits /usr/bin, which silently broke an earlier activation step.
  home.activation.ensureClaudeSyncHooks = lib.hm.dag.entryAfter [ "installPackages" ] ''
    if [ -x /usr/bin/python3 ]; then
      /usr/bin/python3 ${ensureScript} || echo "claude-sync hook check failed (non-fatal)"
    fi
  '';
}
