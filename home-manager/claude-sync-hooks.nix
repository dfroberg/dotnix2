{ config, lib, pkgs, ... }:

# Keeps the claude-sync hooks wired into ~/.claude/settings.json.
#
# Why this exists: settings.json is a CONTESTED file. `tokensave install`,
# `jcodemunch init` and similar installers rewrite it to manage their own hooks, and
# one of them silently dropped the claude-sync SessionStart/SessionEnd entries that
# were appended by hand. The loss is invisible -- nothing errors, memories just stop
# syncing. It went unnoticed for a day, and the stripped copy was even pushed to the
# sync repo, so today's memories never reached the other machine.
#
# So this re-asserts the two entries on EVERY switch (no sentinel -- the whole point
# is to self-heal after another tool clobbers them). It is idempotent and additive:
# it only touches hooks.SessionStart / hooks.SessionEnd, matches existing entries by
# the "claude-sync" substring, and leaves every other hook and setting untouched.
# dotnix does not own settings.json (claude-sync does) -- it just guarantees these two.
let
  ensureScript = pkgs.writeText "claude-sync-hooks-ensure.py" ''
    import json, os, sys

    SETTINGS = os.path.expanduser("~/.claude/settings.json")
    # Log rather than discard: a hook that fails silently is how the previous
    # breakage stayed invisible. Not to stdout/stderr -- that would be UI noise.
    LOG = "$HOME/.claude-sync/last-sync.log"
    WANT = {
        "SessionStart": f'GIT_TERMINAL_PROMPT=0 "$HOME/.claude-sync/bin/claude-sync" pull >>{LOG} 2>&1 || true',
        "SessionEnd":   f'GIT_TERMINAL_PROMPT=0 "$HOME/.claude-sync/bin/claude-sync" push >>{LOG} 2>&1 || true',
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
    for event, command in WANT.items():
        entries = hooks.setdefault(event, [])
        # Already wired (in any matcher group)? then leave it exactly as-is.
        if any("claude-sync" in h.get("command", "")
               for grp in entries for h in grp.get("hooks", [])):
            continue
        entries.append({
            "matcher": "",
            "hooks": [{"type": "command", "command": command, "timeout": 45}],
        })
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
  # Every switch, not sentinel-guarded: this must repair the config after any other
  # installer rewrites it. /usr/bin/python3 by absolute path -- the activation PATH
  # omits /usr/bin, which is exactly what silently broke an earlier activation step.
  home.activation.ensureClaudeSyncHooks = lib.hm.dag.entryAfter [ "installPackages" ] ''
    if [ -x /usr/bin/python3 ]; then
      /usr/bin/python3 ${ensureScript} || echo "claude-sync hook check failed (non-fatal)"
    fi
  '';
}
