#!/usr/bin/env bash

# Enable command tracing for debugging
set -x
set -e -o pipefail

# Log function - redirect to stderr so it doesn't interfere with command substitution
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

log "Starting Aerospace window layout setup"

# Load layout file
LAYOUT_FILE="$HOME/.hammerspoon/window_layouts.json"
if [ ! -f "$LAYOUT_FILE" ]; then
  log "Error: Layout file not found at $LAYOUT_FILE"
  exit 1
fi

log "Using layout file: $LAYOUT_FILE"
LAYOUT=$(cat "$LAYOUT_FILE")

# Function to get window ID for an app and open it if not running
get_window_id() {
  local app_name="$1"
  local title_pattern="${2:-}"
  
  log "Looking for window of app: $app_name (title pattern: ${title_pattern:-any})"
  
  # Look for existing window
  local windows=$(aerospace list-windows --all --json)
  local window_id
  
  if [ -n "$title_pattern" ]; then
    window_id=$(echo -e "$windows" | jq -r --arg app "$app_name" --arg title "$title_pattern" \
      '.[] | select(.["app-name"] == $app and (.title | contains($title))) | .["window-id"]' | head -1 | tr -d '\n')
  else
    window_id=$(echo -e "$windows" | jq -r --arg app "$app_name" \
      '.[] | select(.["app-name"] == $app) | .["window-id"]' | head -1 | tr -d '\n')
  fi
  
  # Open app if not running
  if [ -z "$window_id" ]; then
    log "App $app_name not found, attempting to open it"
    open -a "$app_name" || true
    
    # Wait for the app to open (up to 10 seconds)
    local attempts=0
    while [ -z "$window_id" ] && [ $attempts -lt 20 ]; do
      sleep 0.5
      windows=$(aerospace list-windows --all --json)
      
      if [ -n "$title_pattern" ]; then
        window_id=$(echo -e "$windows" | jq -r --arg app "$app_name" --arg title "$title_pattern" \
          '.[] | select(.["app-name"] == $app and (.title | contains($title))) | .["window-id"]' | head -1 | tr -d '\n')
      else
        window_id=$(echo -e "$windows" | jq -r --arg app "$app_name" \
          '.[] | select(.["app-name"] == $app) | .["window-id"]' | head -1 | tr -d '\n')
      fi
      
      attempts=$((attempts + 1))
    done
    
    if [ -z "$window_id" ]; then
      log "Failed to get window ID for $app_name after opening"
      return 1
    fi
  fi
  
  log "Found window ID for $app_name: $window_id"
  # Only output the window ID, nothing else
  echo "$window_id"
}

# Function to position a window based on the layout
position_window() {
  local app_name="$1"
  local display="$2"
  local window_id="$3"
  local title_pattern="$4"
  local position=""
  local x y w h

  # If title pattern is provided, try to find a specific position for it
  if [ -n "$title_pattern" ]; then
    position=$(echo "$LAYOUT" | jq -r --arg app "$app_name" --arg title "$title_pattern" --arg display "$display" \
      '.displays[$display].apps[$app].windows[] | select(.title_pattern == $title) | .position')
  fi

  # If no specific position found or no title pattern provided, use default position
  if [ -z "$position" ]; then
    position=$(echo "$LAYOUT" | jq -r --arg app "$app_name" --arg display "$display" \
      '.displays[$display].apps[$app].default_position // .displays[$display].apps[$app].position')
  fi

  # If still no position found, skip this window
  if [ -z "$position" ]; then
    log "No position defined for $app_name, skipping"
    return
  fi

  # Get position coordinates
  x=$(echo "$LAYOUT" | jq -r --arg display "$display" --arg pos "$position" '.displays[$display].positions[$pos].x')
  y=$(echo "$LAYOUT" | jq -r --arg display "$display" --arg pos "$position" '.displays[$display].positions[$pos].y')
  w=$(echo "$LAYOUT" | jq -r --arg display "$display" --arg pos "$position" '.displays[$display].positions[$pos].w')
  h=$(echo "$LAYOUT" | jq -r --arg display "$display" --arg pos "$position" '.displays[$display].positions[$pos].h')

  log "Positioning $app_name to $position ($x,$y,$w,$h) on $display display"

  # Determine workspace based on display
  local workspace
  if [ "$display" = "main" ]; then
    workspace=1
  else
    workspace=2
  fi

  # Move window to correct workspace
  log "Moving window $window_id to workspace $workspace"
  aerospace workspace $workspace || log "Failed to switch to workspace $workspace"
  aerospace move-node-to-workspace --window-id "$window_id" "$workspace" || log "Failed to move window to workspace $workspace"
  
  # Set window to floating layout
  log "Setting window $window_id to floating layout"
  aerospace layout --window-id "$window_id" floating || log "Failed to set window to floating layout"
  
  # Position the window
  log "Positioning window $window_id to coordinates ($x,$y,$w,$h)"
  aerospace set-window-frame --window-id "$window_id" --relative "$x" "$y" "$w" "$h" || log "Failed to position window"
}

# Function to organize windows in a workspace
organize_workspace() {
  local workspace="$1"
  
  # Focus the workspace
  aerospace workspace "$workspace"
  
  # Flatten the workspace tree to start with a clean slate
  aerospace flatten-workspace-tree --workspace "$workspace"
  
  # Balance window sizes
  aerospace balance-sizes
  
  log "Organized workspace $workspace"
}

# Get list of all apps from the layout
main_apps=$(echo "$LAYOUT" | jq -r '.displays.main.apps | keys[]')
external_apps=$(echo "$LAYOUT" | jq -r '.displays.external.apps | keys[]')

# Determine which display to use (main or external)
DISPLAY_COUNT=$(aerospace list-monitors --json | jq 'length')
CURRENT_DISPLAY="main"
if [ "$DISPLAY_COUNT" -gt 1 ]; then
  CURRENT_DISPLAY="external"
  log "Multiple displays detected, using external display layout"
else
  log "Single display detected, using main display layout"
fi

# Process apps for the current display
if [ "$CURRENT_DISPLAY" = "main" ]; then
  APPS="$main_apps"
else
  APPS="$external_apps"
fi

# Create workspaces if they don't exist
aerospace workspace 1
aerospace workspace 2

# Process each app
for app in $APPS; do
  log "Processing app: $app"
  
  # Check if app has specific window configurations
  has_windows=$(echo "$LAYOUT" | jq -r --arg app "$app" --arg display "$CURRENT_DISPLAY" \
    '.displays[$display].apps[$app].windows != null')
  
  if [ "$has_windows" = "true" ]; then
    # Get all window configurations for this app
    window_configs=$(echo "$LAYOUT" | jq -r --arg app "$app" --arg display "$CURRENT_DISPLAY" \
      '.displays[$display].apps[$app].windows[] | .title_pattern')
    
    for title_pattern in $window_configs; do
      log "Processing window with title pattern: $title_pattern for app: $app"
      window_id=$(get_window_id "$app" "$title_pattern") || continue
      position_window "$app" "$CURRENT_DISPLAY" "$window_id" "$title_pattern"
    done
  else
    # Process app without specific window configurations
    window_id=$(get_window_id "$app") || continue
    position_window "$app" "$CURRENT_DISPLAY" "$window_id"
  fi
done

# Organize workspaces after all windows are positioned
organize_workspace 1
if [ "$DISPLAY_COUNT" -gt 1 ]; then
  organize_workspace 2
fi

# Return to workspace 1
aerospace workspace 1

log "Window layout setup completed" 