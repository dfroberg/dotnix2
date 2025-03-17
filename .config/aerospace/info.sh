#!/usr/bin/env bash

set -eu -o pipefail

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Aerospace Window Information"
echo "------------------------"

# Show monitor information
echo "MONITORS:"
aerospace list-monitors --json | jq -r '.[] | "ID: \(.id // "unknown"), Name: \(.name // "unknown"), Resolution: \(.frame.width // "unknown")x\(.frame.height // "unknown"), Focused: \(.focused // "unknown")"'
echo ""

# Show workspace information
echo "WORKSPACES:"
aerospace list-workspaces --all --json | jq -r '.[] | "Name: \(.name // "unknown"), Monitor: \(.monitor // "unknown"), Focused: \(.focused // "unknown")"'
echo ""

# Show window information
echo "WINDOWS:"
aerospace list-windows --all --json | jq -r '.[] | "ID: \(.["window-id"] // "unknown"), App: \(.["app-name"] // "unknown"), Title: \(.title // "unknown"), Workspace: \(.workspace // "unknown")"'
echo ""

# Show focused window
echo "FOCUSED WINDOW:"
focused_window=$(aerospace list-windows --focused --json)
if [ -n "$focused_window" ] && [ "$(echo "$focused_window" | jq 'length')" -gt 0 ]; then
  window_id=$(echo "$focused_window" | jq -r '.[0]["window-id"] // "unknown"')
  app_name=$(echo "$focused_window" | jq -r '.[0]["app-name"] // "unknown"')
  title=$(echo "$focused_window" | jq -r '.[0]["window-title"] // "unknown"')
  
  echo "ID: $window_id, App: $app_name, Title: $title"
else
  echo "No focused window"
fi 