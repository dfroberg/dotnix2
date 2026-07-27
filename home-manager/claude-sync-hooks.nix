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

  syncRepo = "${config.home.homeDirectory}/.claude-sync";
  syncRemote = "git@github.com:dfroberg/claude-sync.git";

  # Timer body. Ordering matters: clear the flag BEFORE pushing, so a memory written
  # mid-push re-flags and is caught next tick instead of being swallowed; restore it on
  # failure so a transient network error retries rather than silently dropping the work.
  #
  # The flag is necessary but NOT sufficient as a trigger. It is only ever set by a
  # PostToolUse hook, so once it cleared there was nothing left to drive a retry, and a
  # commit stranded by a failed push sat there indefinitely (observed 2026-07-27: three
  # commits, the oldest 36h old, none on the remote). Being ahead of upstream is itself a
  # reason to run, independent of whether anything new was written.
  pushIfDirty = pkgs.writeShellScriptBin "claude-sync-push-if-dirty" ''
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/run/current-system/sw/bin:${config.home.homeDirectory}/.nix-profile/bin:$PATH"

    # Unpushed commits? Then run even with no flag. `|| echo 0` covers a missing repo or
    # an unset upstream, where rev-list fails and "ahead" is meaningless rather than zero.
    ahead=$(git -C "${syncRepo}" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)

    if [ ! -f "${dirtyFlag}" ] && [ "$ahead" -eq 0 ]; then
      exit 0
    fi

    rm -f "${dirtyFlag}"
    if ! GIT_TERMINAL_PROMPT=0 "${syncBin}" push >>"${syncLog}" 2>&1; then
      : > "${dirtyFlag}"   # failed (offline?) — leave it flagged for the next tick
      exit 0               # never fail the agent; launchd would just respawn it
    fi
  '';

  # Flags the sync repo dirty. Installed by activation rather than home.file: ~/.claude/
  # hooks is itself in the claude-sync allowlist (DIRS=(skills agents commands hooks)), so
  # a read-only store symlink here would break `claude-sync pull`, which writes the file
  # in place. A real file that every switch re-asserts is the same self-healing tactic
  # used for settings.json below.
  #
  # The match set mirrors the allowlist in bin/claude-sync exactly -- FILES, DIRS, and
  # per-project memories. It previously covered ONLY memories, so editing settings.json,
  # a skill or an agent never flagged anything and rode solely on SessionEnd, which is the
  # guarantee this whole module exists to stop depending on.
  markDirty = pkgs.writeText "claude-sync-mark-dirty.sh" ''
    #!/usr/bin/env bash
    # PostToolUse(Write|Edit) hook — flags the sync repo dirty when a synced file changes.
    #
    # Deliberately trivial: no git, no network. It only touches a flag file, so a write
    # never pays sync latency. The periodic LaunchAgent does the actual push, which is
    # what makes this crash-proof: SessionEnd has no guarantee on SIGKILL/crash/terminal
    # close, and a long session would otherwise leave hours of work unsynced (observed
    # 2026-07-25: an 8h session with memories written at 17:00 still unpushed at 18:00).
    set -u

    INPUT=$(cat)

    # Substring match on the raw payload rather than parsing JSON: this runs on EVERY
    # Write/Edit, and spawning python3 cost ~40ms a call versus ~5ms here. The trade is
    # deliberate -- a false positive (a project-level .claude/settings.json, or the path
    # merely appearing in file content) costs one redundant push, while a false negative
    # silently loses work. Keep in sync with FILES/DIRS in bin/claude-sync.
    case "$INPUT" in
      *"/.claude/projects/"*"/memory/"*) ;;
      *"/.claude/CLAUDE.md"*)            ;;
      *"/.claude/settings.json"*)        ;;
      *"/.claude/mcp_settings.json"*)    ;;
      *"/.claude/keybindings.json"*)     ;;
      *"/.claude/skills/"*)              ;;
      *"/.claude/agents/"*)              ;;
      *"/.claude/commands/"*)            ;;
      *"/.claude/hooks/"*)               ;;
      *) exit 0 ;;
    esac

    mkdir -p "$HOME/.claude-sync" 2>/dev/null
    : > "$HOME/.claude-sync/.dirty"
    exit 0
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
  # Clone the sync repo if it is missing. dotnix previously decrypted the git-crypt key and
  # wired the hooks but assumed the repo already existed, so a new machine got hooks that
  # fired and died on "No such file or directory" -- silently, because they end in `|| true`.
  # Observed 2026-07-27 on Dannys-MacBook-Pro: five such failures, a night's memories living
  # nowhere but that laptop, and nothing to indicate anything was wrong.
  #
  # Runs after decryptSecrets: the pull below needs ~/.config/git-crypt/claude-sync.key to
  # auto-unlock, and that is what writes it.
  home.activation.bootstrapClaudeSync = lib.hm.dag.entryAfter [ "decryptSecrets" ] ''
    export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/run/current-system/sw/bin:$PATH"

    # Bootstrapped means "has a commit", not "has a .git". An offline switch can leave an
    # initialised-but-empty repo, and keying off .git alone would never retry it.
    if ! git -C "${syncRepo}" rev-parse --verify HEAD >/dev/null 2>&1; then
      echo "claude-sync: no repo at ${syncRepo} — bootstrapping from ${syncRemote}"

      # init + fetch + reset rather than `git clone`: clone refuses a non-empty directory,
      # and a half-bootstrapped machine already has a stray last-sync.log sitting there
      # from the hooks that fired and died. Not shallow -- full history is what made the
      # revert possible when a bad push emptied the remote.
      mkdir -p "${syncRepo}"
      git -C "${syncRepo}" init -q -b main 2>/dev/null || true
      git -C "${syncRepo}" remote add origin "${syncRemote}" 2>/dev/null \
        || git -C "${syncRepo}" remote set-url origin "${syncRemote}"

      if GIT_TERMINAL_PROMPT=0 git -C "${syncRepo}" fetch -q origin main 2>/dev/null; then
        git -C "${syncRepo}" reset --hard -q origin/main
        git -C "${syncRepo}" branch -q --set-upstream-to=origin/main main 2>/dev/null || true

        # Pull IMMEDIATELY, on the bootstrap path only. This is the whole reason the clone
        # lives here rather than in a runbook: a cloned-but-unapplied repo is the exact
        # state in which a push deletes everything the other machine owns, and both the
        # SessionEnd hook and the 5-minute timer can fire into that window. Getting the
        # remote applied into ~/.claude first closes it. (bin/claude-sync also refuses such
        # a push now, but ordering is the fix; the tripwire is the backstop.)
        GIT_TERMINAL_PROMPT=0 "${syncRepo}/bin/claude-sync" pull >>"${syncLog}" 2>&1 \
          && echo "claude-sync: bootstrapped and applied" \
          || echo "claude-sync: cloned but pull failed (see ${syncLog})"
      else
        echo "claude-sync: fetch failed (offline?) — will retry next switch"
      fi
    fi
  '';

  home.activation.ensureClaudeSyncHooks = lib.hm.dag.entryAfter [ "installPackages" ] ''
    # Re-assert the mark-dirty script itself. Copied, not symlinked -- see markDirty above.
    $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.claude/hooks"
    $DRY_RUN_CMD install -m 0755 ${markDirty} \
      "${config.home.homeDirectory}/.claude/hooks/claude-sync-mark-dirty.sh"

    if [ -x /usr/bin/python3 ]; then
      /usr/bin/python3 ${ensureScript} || echo "claude-sync hook check failed (non-fatal)"
    fi
  '';
}
