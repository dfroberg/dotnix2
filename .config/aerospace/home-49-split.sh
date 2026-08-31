#!/usr/bin/env bash
# Overlay Left / Center / Right virtual screens as thirds on the 49" (LC49G95T).
#
# Each virtual is created with the slice's exact aspect: a third of 5120x1440 is
# 1706.67x1440 = 32:27, so the PIP maps 1:1 with freeAspect OFF (16:9 virtuals
# squeezed content ~33% horizontally). BetterDisplay snaps -resolution=1706x1440
# to its nearest generated mode, 1696x1431 (still 32:27, ~1:1.006 on glass).
#
# Verified quirks (BetterDisplay CLI 3.x, 2026-08):
# - `create` leaves the device DISCONNECTED; follow with -connected=on.
# - PIP needs two calls: `-pip=on` creates the overlay window, then `-pip` as
#   selector alters its props.
# - The CLI CANNOT choose which display hosts the PIP window: -target* params
#   are device selectors (alias of -name), not placement. Place the window via
#   System Events using GLOBAL coordinates.
# - The LC49's arrangement origin DRIFTS when displays reconnect (e.g. a
#   BetterDisplay restart), so never hardcode it: read it from displayplacer
#   each run and place the thirds relative to it.
# - PIP streaming requires Screen Recording permission for BetterDisplay;
#   without it the overlays render as transparent/black shells.
# - Ops print "Failed." on error but may still exit 0; check output.
#
# The physical panel stays connected as the PIP canvas; aerospace parks
# workspace 10 on it (aerospace.toml) so no window gets buried behind overlays.
set -euo pipefail

BD="$(command -v betterdisplaycli || true)"
[[ -n "$BD" ]] || BD="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
[[ -x "$BD" ]] || { echo "BetterDisplay not installed" >&2; exit 1; }
command -v displayplacer >/dev/null || { echo "displayplacer missing (brew install displayplacer)" >&2; exit 1; }

ensure() {
  local name="$1"
  if ! "$BD" get -name="$name" -connected >/dev/null 2>&1; then
    "$BD" create -type=VirtualScreen -virtualScreenName="$name" \
      -aspectWidth=32 -aspectHeight=27 -sizeInch=21
    sleep 2
  fi
  "$BD" set -name="$name" -connected=on
  sleep 1
  "$BD" set -name="$name" -resolution=1706x1440
}

for n in Left Center Right; do ensure "$n"; done

# LC49 top-left in global (CG) coordinates, e.g. "Origin: (-1613,1169)".
read -r GX GY < <(displayplacer list | awk '/49 inch/{f=1} f && /^Origin/ {gsub(/[()]/,""); sub(/^Origin: /,""); split($0,a,","); print a[1], a[2]; exit}')
[[ -n "${GX:-}" && -n "${GY:-}" ]] || { echo "could not locate 49\" display origin" >&2; exit 1; }

pip() {
  local name="$1" off="$2" w="$3"
  "$BD" set -name="$name" -pip=on -freeAspect=off
  sleep 1
  "$BD" set -name="$name" -pip -alpha=1 -priority=absolute \
    -showTitlebar=off -cursorShown=on -unmovable=off
  osascript -e "tell application \"System Events\" to tell process \"BetterDisplay\"
    repeat with w in windows
      if name of w = \"$name\" then
        set position of w to {$((GX + off)), $GY}
        set size of w to {$w, 1440}
      end if
    end repeat
  end tell"
  "$BD" set -name="$name" -pip -unmovable=on
}

pip Left 0 1707
pip Center 1707 1706
pip Right 3413 1707
echo "49\" split at (${GX},${GY}): Left | Center | Right"
