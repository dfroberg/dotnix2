#!/usr/bin/env bash

set -e -o pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Function to check if Aerospace is running and restart if needed
check_aerospace() {
  if ! pgrep -q "AeroSpace"; then
    log "Aerospace is not running, attempting to restart..."
    open -a AeroSpace
    sleep 5  # Give it more time to start
    
    # Check again
    if ! pgrep -q "AeroSpace"; then
      log "Failed to restart Aerospace. Exiting."
      exit 1
    else
      log "Aerospace restarted successfully"
    fi
  fi
}

# Function to safely run aerospace commands
run_aerospace() {
  check_aerospace
  
  local cmd="$1"
  local args="${@:2}"
  
  log "Running: aerospace $cmd $args"
  if ! aerospace $cmd $args 2>/dev/null; then
    log "Command failed: aerospace $cmd $args"
    return 1
  fi
  return 0
}

# Function to get window ID by app name
get_window_id() {
  local app_name="$1"
  local workspace="$2"
  
  if [ -z "$workspace" ]; then
    workspace="0"  # Default to workspace 0
  fi
  
  # Get the list of windows in the workspace
  local windows=$(run_aerospace list-windows --workspace "$workspace" --json)
  if [ -z "$windows" ] || [ "$windows" = "null" ]; then
    return 1
  fi
  
  # Try exact match first
  local window_id=$(echo "$windows" | jq -r --arg app "$app_name" '.[] | select(.["app-name"] == $app) | .["window-id"]' | head -1)
  
  # If not found, try case-insensitive match
  if [ -z "$window_id" ]; then
    window_id=$(echo "$windows" | jq -r --arg app "$app_name" '.[] | select(.["app-name"] | ascii_downcase | contains($app | ascii_downcase)) | .["window-id"]' | head -1)
  fi
  
  # Special cases for browser tabs
  if [ -z "$window_id" ]; then
    case "$app_name" in
      "Gmail"|"YouTube"|"LinkedIn"|"Google Meet")
        # Look for Chrome windows with these titles
        window_id=$(echo "$windows" | jq -r --arg title "$app_name" '.[] | select(.["app-name"] == "Google Chrome" and (.title | contains($title))) | .["window-id"]' | head -1)
        ;;
      "Microsoft Teams"|"Microsoft Word"|"Word")
        # Try to match just "Microsoft" and then check the title
        window_id=$(echo "$windows" | jq -r '.[] | select(.["app-name"] | contains("Microsoft")) | .["window-id"]' | head -1)
        ;;
    esac
  fi
  
  echo "$window_id"
}

# Function to check if a workspace has windows
workspace_has_windows() {
  local workspace="$1"
  local windows=$(run_aerospace list-windows --workspace "$workspace" --json)
  if [ -z "$windows" ] || [ "$windows" = "null" ] || [ "$windows" = "[]" ]; then
    return 1
  fi
  return 0
}

# Function to display window information
display_window_info() {
  local workspace="$1"
  log "Windows in workspace $workspace:"
  
  local windows=$(run_aerospace list-windows --workspace "$workspace" --json)
  echo "$windows" | jq -r '.[] | "Window ID: \(.["window-id"]) | App: \(.["app-name"])"' | while read -r line; do
    log "$line"
  done
  
  # Also display the tree structure
  log "Tree structure for workspace $workspace:"
  run_aerospace debug-tree --workspace "$workspace" || log "Failed to get tree structure"
}

# Main script starts here
log "Starting window layout setup"

# Check if Aerospace is running
check_aerospace

# Check monitor count
MONITOR_COUNT=$(run_aerospace list-monitors --json | jq length)
log "Monitor count: $MONITOR_COUNT"

if [ "$MONITOR_COUNT" -le 1 ]; then
  log "Only one monitor detected. Using internal display layout."
  DISPLAY_TYPE="internal"
else
  log "Multiple monitors detected. Using external display layout."
  DISPLAY_TYPE="external"
fi

# Reload Aerospace configuration to ensure workspace assignments are applied
log "Reloading Aerospace configuration"
run_aerospace reload-config || log "Failed to reload configuration"
sleep 3  # Give more time for configuration to apply

# Get layout file
LAYOUT_FILE="/Users/dfroberg/.hammerspoon/workspace_layouts.json"
if [ -f "$LAYOUT_FILE" ]; then
  log "Using layout file: $LAYOUT_FILE"
  LAYOUT=$(cat "$LAYOUT_FILE")
else
  log "Layout file not found, using default layout"
  LAYOUT='{}'
fi

# First, focus on workspace 0
log "Focusing workspace 0"
run_aerospace workspace 0 || true
sleep 2

# Reset workspace 0 layout
log "Resetting workspace 0 layout"
run_aerospace flatten-workspace-tree --workspace 0 || true
sleep 1

# Move all windows to workspace 0 first
log "Moving all windows to workspace 0"
all_windows=$(run_aerospace list-windows --all --json 2>/dev/null || echo "[]")
for window_id in $(echo "$all_windows" | jq -r '.[].["window-id"]'); do
  app_name=$(echo "$all_windows" | jq -r --arg id "$window_id" '.[] | select(.["window-id"] == ($id | tonumber)) | .["app-name"]')
  log "Moving window $window_id ($app_name) to workspace 0"
  run_aerospace move-node-to-workspace --window-id "$window_id" 0 || true
  sleep 1
done

# Create all workspaces defined in the layout file
log "Creating workspaces from layout file"
workspaces=$(echo "$LAYOUT" | jq -r '.workspaces | keys[]')
for workspace in $workspaces; do
  log "Creating workspace $workspace"
  run_aerospace workspace "$workspace" || true
  sleep 1
done

# Process each workspace defined in the layout file
for workspace in $workspaces; do
  log "Processing workspace $workspace"
  
  # Get the monitor assignment for this workspace
  monitor=$(echo "$LAYOUT" | jq -r --arg ws "$workspace" '.workspaces[$ws].monitor')
  log "Workspace $workspace is assigned to monitor: $monitor"
  
  # Get the layout for this workspace
  ws_layout=$(echo "$LAYOUT" | jq -r --arg ws "$workspace" '.workspaces[$ws].layout')
  log "Workspace $workspace layout: $ws_layout"
  
  # Get the apps for this workspace - use jq to handle array properly
  ws_apps_json=$(echo "$LAYOUT" | jq -r --arg ws "$workspace" '.workspaces[$ws].apps')
  
  # Move apps to their assigned workspace
  for app in $(echo "$ws_apps_json" | jq -r '.[]'); do
    log "Looking for app: '$app' for workspace $workspace"
    app_window_id=$(get_window_id "$app" "0")
    
    if [ -n "$app_window_id" ]; then
      log "Moving $app to workspace $workspace"
      run_aerospace move-node-to-workspace --window-id "$app_window_id" "$workspace" || true
      sleep 1
    else
      log "App '$app' not found in workspace 0"
    fi
  done
  
  # Focus on the workspace
  log "Focusing workspace $workspace"
  run_aerospace workspace "$workspace" || true
  sleep 2
  
  # Only set layout if the workspace has windows
  if workspace_has_windows "$workspace"; then
    log "Running: aerospace list-windows --workspace $workspace --json"
    
    # Set the layout for the workspace
    log "Setting layout for workspace $workspace"
    case "$ws_layout" in
      "tiles horizontal vertical")
        run_aerospace layout tiles horizontal vertical || true
        sleep 1
        ;;
      "accordion horizontal vertical")
        run_aerospace layout accordion horizontal vertical || true
        sleep 1
        ;;
      "custom")
        # For workspace 2 with custom layout, we'll implement the specific structure
        if [ "$workspace" = "2" ]; then
          log "Implementing custom layout for workspace 2"
          
          # First, completely flatten the workspace tree to start fresh
          log "Flattening workspace 2 tree"
          run_aerospace flatten-workspace-tree --workspace 2 || true
          sleep 2
          
          # Get window IDs for each app in workspace 2
          cursor_id=$(get_window_id "Cursor" "$workspace")
          signal_id=$(get_window_id "Signal" "$workspace")
          wezterm_id=$(get_window_id "WezTerm" "$workspace")
          youtube_id=$(get_window_id "YouTube" "$workspace")
          zoom_id=$(get_window_id "zoom.us" "$workspace")
          meet_id=$(get_window_id "Google Meet" "$workspace")
          teams_id=$(get_window_id "Microsoft Teams" "$workspace")
          word_id=$(get_window_id "Microsoft Word" "$workspace")
          
          log "Found windows in workspace 2:"
          [ -n "$cursor_id" ] && log "- Cursor: $cursor_id"
          [ -n "$signal_id" ] && log "- Signal: $signal_id"
          [ -n "$wezterm_id" ] && log "- WezTerm: $wezterm_id"
          [ -n "$youtube_id" ] && log "- YouTube: $youtube_id"
          [ -n "$zoom_id" ] && log "- Zoom: $zoom_id"
          [ -n "$meet_id" ] && log "- Google Meet: $meet_id"
          [ -n "$teams_id" ] && log "- Microsoft Teams: $teams_id"
          [ -n "$word_id" ] && log "- Microsoft Word: $word_id"
          
          # Display initial tree structure
          display_window_info 2
          
          # Step 1: Set the root container to tiles horizontal
          log "Setting root container to tiles horizontal"
          run_aerospace layout tiles horizontal || true
          sleep 2
          
          # Step 2: Create the left container with communication apps
          # First, collect all communication app IDs
          comm_apps=()
          [ -n "$zoom_id" ] && comm_apps+=("$zoom_id")
          [ -n "$meet_id" ] && comm_apps+=("$meet_id")
          [ -n "$teams_id" ] && comm_apps+=("$teams_id")
          [ -n "$signal_id" ] && comm_apps+=("$signal_id")
          
          # If we have at least one communication app
          if [ ${#comm_apps[@]} -gt 0 ]; then
            # Focus on the first communication app
            log "Focusing first communication app: ${comm_apps[0]}"
            run_aerospace focus --window-id "${comm_apps[0]}" || true
            sleep 2
            
            # Join all other communication apps with the first one
            for ((i=1; i<${#comm_apps[@]}; i++)); do
              log "Joining communication app ${comm_apps[$i]} with ${comm_apps[0]}"
              run_aerospace focus --window-id "${comm_apps[$i]}" || true
              sleep 1
              run_aerospace join-with --window-id "${comm_apps[0]}" || true
              sleep 2
            done
            
            # Set the left container to accordion vertical
            if [ ${#comm_apps[@]} -gt 1 ]; then
              log "Setting accordion vertical layout for communication apps"
              run_aerospace focus --window-id "${comm_apps[0]}" || true
              sleep 1
              run_aerospace layout accordion vertical || true
              sleep 2
            fi
          fi
          
          # Step 3: Create the right container with YouTube and WezTerm
          if [ -n "$youtube_id" ] && [ -n "$wezterm_id" ]; then
            # Focus on YouTube
            log "Focusing YouTube"
            run_aerospace focus --window-id "$youtube_id" || true
            sleep 2
            
            # Join WezTerm with YouTube
            log "Joining WezTerm with YouTube"
            run_aerospace focus --window-id "$wezterm_id" || true
            sleep 1
            run_aerospace join-with --window-id "$youtube_id" || true
            sleep 2
            
            # Set the right container to tiles vertical
            log "Setting tiles vertical layout for YouTube and WezTerm"
            run_aerospace focus --window-id "$youtube_id" || true
            sleep 1
            run_aerospace layout tiles vertical || true
            sleep 2
          fi
          
          # Step 4: Focus on Cursor as the central window
          if [ -n "$cursor_id" ]; then
            log "Focusing Cursor as the central window"
            run_aerospace focus --window-id "$cursor_id" || true
            sleep 2
            
            # Resize Cursor to take more space
            log "Resizing Cursor to take more space"
            run_aerospace resize smart +100 || true
            sleep 1
            run_aerospace resize smart +100 || true
            sleep 2
          fi
          
          # Display final tree structure
          display_window_info 2
        fi
        ;;
      *)
        log "Unknown layout type: $ws_layout, using default tiles layout"
        run_aerospace layout tiles horizontal vertical || true
        ;;
    esac
  else
    log "Workspace $workspace is empty, skipping layout setting"
  fi
  
  sleep 2
done

# Return to workspace 2 (main development workspace)
log "Returning to workspace 2"
run_aerospace workspace 2 || true

log "Window layout setup completed"