#!/usr/bin/env bash

set -eu -o pipefail

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Resetting Aerospace window layout to tiled mode"

# Get all workspaces
workspaces=$(aerospace list-workspaces --json | jq -r '.[].name')

# Process each workspace
for workspace in $workspaces; do
  log "Processing workspace: $workspace"
  
  # Focus the workspace
  aerospace workspace "$workspace"
  
  # Flatten the workspace tree
  aerospace flatten-workspace-tree --workspace "$workspace"
  
  # Set layout to tiles
  aerospace layout tiles horizontal vertical
  
  # Balance window sizes
  aerospace balance-sizes
  
  log "Reset workspace $workspace to tiled layout"
done

# Return to workspace 1
aerospace workspace 1

log "Window layout reset completed" 