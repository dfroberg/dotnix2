#!/usr/bin/env bash

set -eu -o pipefail

# script accepts a workspace name to move windows to, defaults to "zoom"
# assumption is this target workspace is empty or doesn't exist yet
TARGET_WORKSPACE_NAME="${1:-zoom}"

# Get window ID for an app and open it if not running
get_window_id() {
    local app_name="$1"

    # look for existing window
    local windows=$(aerospace list-windows --all --json)
    local window_id=$(echo -e "$windows" | jq -r --arg app "$app_name" '.[] | select(.["app-name"] == $app) | .["window-id"]')
    
    # open app if not running
    if [ -z "$window_id" ]; then
        open -a "$app_name"
        if [ $? -ne 0 ]; then
            echo "Failed to open $app_name" >&2
            exit 1
        fi
        while [ -z "$window_id" ]; do
            windows=$(aerospace list-windows --all --json)
            window_id=$(echo -e "$windows" | jq -r --arg app "$app_name" '.[] | select(.["app-name"] == $app) | .["window-id"]')
            sleep 0.1
        done
    fi
    
    echo "$window_id"
}

aerospace workspace $TARGET_WORKSPACE_NAME

# Get zoom window ID and move it to target workspace
zoom_window_id=$(get_window_id "zoom.us")
aerospace move-node-to-workspace --window-id $zoom_window_id $TARGET_WORKSPACE_NAME

# Get the obsidian window ID and move it to target workspace
obsidian_window_id=$(get_window_id "Obsidian")
aerospace move-node-to-workspace --window-id $obsidian_window_id $TARGET_WORKSPACE_NAME

# Get the arc window ID and move it to target workspace
arc_window_id=$(get_window_id "Arc")
aerospace move-node-to-workspace --window-id $arc_window_id $TARGET_WORKSPACE_NAME

aerospace flatten-workspace-tree --workspace $TARGET_WORKSPACE_NAME

# Try to ensure arc is on the right side of the screen
aerospace move --window-id $arc_window_id right
aerospace move --window-id $arc_window_id right

# Try to ensure obsidian is on the left side of the screen
aerospace move --window-id $zoom_window_id left
aerospace move --window-id $obsidian_window_id left
aerospace move --window-id $obsidian_window_id left

# Join the zoom window with obsidian on the left side of the screen
aerospace join-with --window-id $zoom_window_id left

# Try to ensure zoom is on the top of the screen
aerospace move --window-id $zoom_window_id up