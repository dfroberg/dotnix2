#!/usr/bin/env bash

# Set strict error handling!
set -euo pipefail
IFS=$'\n\t'
# Wait for yabai to be fully started
# rather than sleep 5 i'll use a while loop to check if yabai is running
while ! yabai -m query --windows &>/dev/null; do
  sleep 0.1
done
# Add logging with file output
yabai_log() {
  local message="[$(date '+%Y-%m-%d %H:%M:%S')] [YABAI] $1"
  echo "${message}"
  # Append to log file without reading from it
  printf '%s\n' "${message}" >> "/tmp/yabai_window_manager.log"
}
# Lets reset the logfile
echo "yabaisetup.sh started" > "/tmp/yabai_window_manager.log"
# Initialize variables
layout_content=""
layout_file=""

# Find the layout file
for user_home in /Users/Shared /Users/*; do
  if [ -d "${user_home}" ]; then
    config_dir="${user_home}/.hammerspoon"
    layout_file="${config_dir}/window_layouts.json"
    
    if [ -f "${layout_file}" ]; then
      yabai_log "Found layout file at ${layout_file}"
      layout_content=$(cat "${layout_file}")
      yabai_log "Layout content loaded:"
      yabai_log "$(echo "${layout_content}" | jq '.')"
      break
    fi
  fi
done

if [ -z "${layout_content}" ]; then
  yabai_log "Error: Could not find window_layouts.json"
  exit 1
fi

# Add debug logging for windows
yabai_log "Current windows:"
yabai_log "$(yabai -m query --windows | jq '.')"

yabai_log "Current displays:"
yabai_log "$(yabai -m query --displays | jq '.')"

# Source helper functions if they exist
if [[ -f "${HOME}/.bashrc" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.bashrc"
fi

# Add error handling for yabai commands
yabai_cmd() {
  yabai -m "$@" || yabai_log "Error: yabai command failed: $*"
}

# Function to check if window exists
window_exists() {
  yabai -m query --windows --window "$1" &>/dev/null
}

# Function to set up yabai window manager
setup_yabai() {
  yabai_log "Starting yabai setup..."

  # Basic window management
  yabai_log "Configuring basic window management..."
  yabai -m config layout float
  yabai -m config window_placement second_child
  
  # Mouse support
  yabai_log "Configuring mouse settings..."
  yabai -m config mouse_follows_focus off
  yabai -m config focus_follows_mouse off
  
  # Padding
  yabai_log "Configuring padding..."
  yabai -m config top_padding 0
  yabai -m config bottom_padding 0
  yabai -m config left_padding 0
  yabai -m config right_padding 0
  yabai -m config window_gap 0
  
  # Rules for specific applications
  yabai_log "Setting up application rules..."
  yabai -m rule --add app="^System Settings$" manage=off
  yabai -m rule --add app="^Calculator$" manage=off
  yabai -m rule --add app="^Karabiner-Elements$" manage=off
  yabai -m rule --add app="^QuickTime Player$" manage=off
  yabai -m rule --add app="^Disk Utility$" manage=off
  yabai -m rule --add app="^Activity Monitor$" manage=off
  yabai -m rule --add app="^Path Finder$" manage=off
  yabai -m rule --add app="^TeamViewer$" manage=off
  yabai -m rule --add app="^Finder$" manage=off
  yabai -m rule --add app="^Hammerspoon$" manage=off
  yabai -m rule --add app="^App Store$" manage=off
  yabai -m rule --add app="^System Information$" manage=off
  yabai -m rule --add app="^OBSBOT Center$" manage=off
  
  yabai_log "Yabai setup completed"
}

# New function that tries multiple positioning methods in sequence
position_window_with_fallbacks() {
  local window_id="$1"
  local app="$2"
  local x="$3"
  local y="$4"
  local w="$5"
  local h="$6"
  local window_title
  
  # Get window title for AppleScript methods
  window_title=$(yabai -m query --windows --window "${window_id}" | jq -r '.title')
  # Function to check if position was successfully applied
  check_position_success() {
    sleep 0.4
    local current_frame
    current_frame=$(yabai -m query --windows --window "${window_id}" | jq -r '.frame')
    
    # Check if we got valid frame data
    if [ -z "${current_frame}" ] || [ "${current_frame}" = "null" ]; then
      yabai_log "Error: Could not retrieve frame data for window ${window_id}"
      return 1
    fi
    
    local current_x=$(echo "${current_frame}" | jq -r '.x')
    local current_y=$(echo "${current_frame}" | jq -r '.y')
    local current_w=$(echo "${current_frame}" | jq -r '.w')
    local current_h=$(echo "${current_frame}" | jq -r '.h')
    
    # Verify all coordinates are valid (not empty or null)
    if [ -z "${current_x}" ] || [ "${current_x}" = "null" ] || 
       [ -z "${current_y}" ] || [ "${current_y}" = "null" ] || 
       [ -z "${current_w}" ] || [ "${current_w}" = "null" ] || 
       [ -z "${current_h}" ] || [ "${current_h}" = "null" ]; then
      yabai_log "Error: Invalid coordinates in frame data: x=${current_x}, y=${current_y}, w=${current_w}, h=${current_h}"
      return 1
    fi
    
    # Allow for small differences (within 5 pixels) due to rounding or window manager adjustments
    # Use bc for floating point arithmetic
    local x_diff=$(echo "${current_x} - ${x}" | bc -l | awk '{print ($1 < 0) ? -$1 : $1}')
    local y_diff=$(echo "${current_y} - ${y}" | bc -l | awk '{print ($1 < 0) ? -$1 : $1}')
    local w_diff=$(echo "${current_w} - ${w}" | bc -l | awk '{print ($1 < 0) ? -$1 : $1}')
    local h_diff=$(echo "${current_h} - ${h}" | bc -l | awk '{print ($1 < 0) ? -$1 : $1}')
    
    # Convert to integers for comparison
    local x_diff_int=$(echo "${x_diff}" | awk '{printf "%.0f", $1}')
    local y_diff_int=$(echo "${y_diff}" | awk '{printf "%.0f", $1}')
    local w_diff_int=$(echo "${w_diff}" | awk '{printf "%.0f", $1}')
    local h_diff_int=$(echo "${h_diff}" | awk '{printf "%.0f", $1}')
    
    if [ "${x_diff_int}" -le 5 ] && [ "${y_diff_int}" -le 5 ] && 
        [ "${w_diff_int}" -le 5 ] && [ "${h_diff_int}" -le 5 ]; then
      yabai_log "Position successfully applied: x=${current_x}, y=${current_y}, w=${current_w}, h=${current_h}"
      return 0
    else
      yabai_log "Position not applied correctly. Current: x=${current_x}, y=${current_y}, w=${current_w}, h=${current_h}"
      return 1
    fi
  }
  # Method 1: Basic yabai move and resize
  yabai_log "Trying positioning method 1 for window"
  yabai -m window "${window_id}" --focus
  yabai -m window "${window_id}" --move "abs:${x}:${y}"
  local move_exit=$?
  yabai_log "yabai move exit code: ${move_exit}"
  
  yabai -m window "${window_id}" --resize "abs:${w}:${h}"
  local resize_exit=$?
  yabai_log "yabai resize exit code: ${resize_exit}"
  
  # Add a small delay to give the application time to process
  sleep 0.2
  
  # Check if method 1 worked
  if check_position_success; then
    yabai_log "Method 1 succeeded, no need for fallbacks"
    return 0
  fi
  
  # Method 2: AppleScript move with title
  yabai_log "Trying positioning method 2 for window"
  osascript -e "
    tell application \"System Events\"
      tell process \"${app}\"
        set frontmost to true
        if \"${window_title}\" is not equal to \"\" then
          set targetWindow to window \"${window_title}\"
        else
          set targetWindow to window 1
        end if
        set position of targetWindow to {${x}, ${y}}
      end tell
    end tell
  " 2>/dev/null
  local move_script_exit=$?
  yabai_log "osascript move with title exit code: ${move_script_exit}"
  
  # Add a small delay to give the application time to process
  sleep 0.2
  
  # Check if method 2 worked
  if check_position_success; then
    yabai_log "Method 2 succeeded, no need for further fallbacks"
    return 0
  fi
  
  # Method 3: AppleScript bounds with title
  yabai_log "Trying positioning method 3 for window"
  osascript -e "
    tell application \"System Events\"
      tell process \"${app}\"
        set frontmost to true
        if \"${window_title}\" is not equal to \"\" then
          set targetWindow to window \"${window_title}\"
        else
          set targetWindow to window 1
        end if
        set bounds of targetWindow to {${x}, ${y}, $((x + w)), $((y + h))}
      end tell
    end tell
  " 2>/dev/null
  local bounds_script_exit=$?
  yabai_log "osascript bounds with title exit code: ${bounds_script_exit}"
  
  # Add a small delay to give the application time to process
  sleep 0.2
  
  # Check if method 3 worked
  if check_position_success; then
    yabai_log "Method 3 succeeded, no need for further fallbacks"
    return 0
  fi
  
  # Method 4: AppleScript direct with title (alternative approach)
  yabai_log "Trying positioning method 4 for window"
  osascript -e "
    tell application \"${app}\"
      activate
      if \"${window_title}\" is not equal to \"\" then
        set bounds of window \"${window_title}\" to {${x}, ${y}, $((x + w)), $((y + h))}
      else
        set bounds of window 1 to {${x}, ${y}, $((x + w)), $((y + h))}
      end if
    end tell
  " 2>/dev/null
  local direct_script_exit=$?
  yabai_log "osascript direct with title exit code: ${direct_script_exit}"
  
  # Add a small delay to give the application time to process
  sleep 0.2
  
  # Check if method 4 worked
  if check_position_success; then
    yabai_log "Method 4 succeeded, no need for further fallbacks"
    return 0
  fi
  
  # Method 5: yabai grid approach
  yabai_log "Trying positioning method 5 for window"
  # First reset to a known grid
  yabai -m window "${window_id}" --grid 1:1:0:0:1:1
  local grid_exit=$?
  yabai_log "yabai grid exit code: ${grid_exit}"
  
  # Add a small delay to give the application time to process
  sleep 0.2
  
  # Then try move and resize again
  yabai -m window "${window_id}" --move "abs:${x}:${y}"
  local move_exit2=$?
  yabai_log "yabai move exit code: ${move_exit2}"
  
  yabai -m window "${window_id}" --resize "abs:${w}:${h}"
  local resize_exit2=$?
  yabai_log "yabai resize exit code: ${resize_exit2}"
  
  # Add a small delay to give the application time to process
  sleep 0.2
  
  # Final check
  if check_position_success; then
    yabai_log "Method 5 succeeded"
    return 0
  else
    yabai_log "All positioning methods failed"
    return 1
  fi
}

# Function to position a window
position_window() {
  local window_id="$1"
  local app="$2"
  local x="$3"
  local y="$4"
  local w="$5"
  local h="$6"
  local retry_count=0
  local max_retries=3
  
  yabai_log "Positioning window ${window_id} (${app}) to x=${x}, y=${y}, w=${w}, h=${h}"
  
  # Retry loop for windows that temporarily disappear
  while [ $retry_count -le $max_retries ]; do
    # Verify window still exists before proceeding
    local window_info
    window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
    if [ -z "${window_info}" ]; then
      if [ $retry_count -lt $max_retries ]; then
        retry_count=$((retry_count + 1))
        yabai_log "Window ${window_id} temporarily unavailable, retrying (attempt ${retry_count}/${max_retries})..."
        sleep 0.5
        continue
      else
        yabai_log "Error: Window ${window_id} no longer exists after ${max_retries} retries, skipping positioning"
        return 1
      fi
    fi
    
    # Check if window is visible
    local is_visible
    is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
    if [ "${is_visible}" = "false" ]; then
      yabai_log "Window ${window_id} exists but is not visible, attempting to make it visible"
      # Try to make the window visible
      if yabai -m window "${window_id}" --focus 2>/dev/null; then
        yabai_log "Successfully focused window ${window_id}"
      else
        yabai_log "Failed to focus window ${window_id}, it may be in a state where it can't be interacted with"
      fi
      # Wait a moment for the window to become visible
      sleep 0.5
      
      # Check again if window is visible after focusing
      window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
      if [ -n "${window_info}" ]; then
        is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
        if [ "${is_visible}" = "false" ]; then
          yabai_log "Window ${window_id} still not visible after focusing, will try to position anyway"
        else
          yabai_log "Successfully made window ${window_id} visible"
        fi
      fi
    fi
    
    # Get current frame
    local current_frame
    current_frame=$(echo "${window_info}" | jq -r '.frame')
    
    # Make sure window is floating for precise positioning
    if [ "$(echo "${window_info}" | jq -r '.["is-floating"]')" = "false" ]; then
      yabai_log "Making window ${window_id} floating for positioning"
      yabai -m window "${window_id}" --toggle float
      
      # Check if window still exists after toggling float
      if ! yabai -m query --windows --window "${window_id}" &>/dev/null; then
        if [ $retry_count -lt $max_retries ]; then
          retry_count=$((retry_count + 1))
          yabai_log "Window ${window_id} disappeared after toggling float, retrying (attempt ${retry_count}/${max_retries})..."
          sleep 0.5
          continue
        else
          yabai_log "Error: Window ${window_id} no longer exists after ${max_retries} retries, skipping positioning"
          return 1
        fi
      fi
    fi
    
    # Unminimize window if it's minimized
    if [ "$(yabai -m query --windows --window "${window_id}" | jq -r '.["is-minimized"]')" = "true" ]; then
      yabai -m window "${window_id}" --deminimize
      
      # Check if window still exists after deminimizing
      if ! yabai -m query --windows --window "${window_id}" &>/dev/null; then
        if [ $retry_count -lt $max_retries ]; then
          retry_count=$((retry_count + 1))
          yabai_log "Window ${window_id} disappeared after deminimizing, retrying (attempt ${retry_count}/${max_retries})..."
          sleep 0.5
          continue
        else
          yabai_log "Error: Window ${window_id} no longer exists after ${max_retries} retries, skipping positioning"
          return 1
        fi
      fi
    fi
    
    # Use the new function with multiple fallback methods
    local positioning_result=0
    position_window_with_fallbacks "${window_id}" "${app}" "${x}" "${y}" "${w}" "${h}"
    positioning_result=$?
    
    # Check if positioning failed due to window disappearing
    if [ $positioning_result -ne 0 ]; then
      if ! yabai -m query --windows --window "${window_id}" &>/dev/null; then
        if [ $retry_count -lt $max_retries ]; then
          retry_count=$((retry_count + 1))
          yabai_log "Window ${window_id} disappeared during positioning, retrying (attempt ${retry_count}/${max_retries})..."
          sleep 0.5
          continue
        else
          yabai_log "Error: Window ${window_id} no longer exists after ${max_retries} retries, skipping positioning"
          return 1
        fi
      fi
    fi
    
    # Verify window still exists before checking new position
    if ! yabai -m query --windows --window "${window_id}" &>/dev/null; then
      if [ $retry_count -lt $max_retries ]; then
        retry_count=$((retry_count + 1))
        yabai_log "Window ${window_id} disappeared after positioning attempt, retrying (attempt ${retry_count}/${max_retries})..."
        sleep 0.5
        continue
      else
        yabai_log "Warning: Window ${window_id} no longer exists after ${max_retries} retries"
        return 1
      fi
    fi
    
    # Get new frame
    local new_frame
    new_frame=$(yabai -m query --windows --window "${window_id}" | jq -r '.frame')
    
    # Extract coordinates
    local new_x
    new_x=$(echo "${new_frame}" | jq -r '.x')
    local new_y
    new_y=$(echo "${new_frame}" | jq -r '.y')
    local new_w
    new_w=$(echo "${new_frame}" | jq -r '.w')
    local new_h
    new_h=$(echo "${new_frame}" | jq -r '.h')
    
    # Check if coordinates are valid (not empty or null)
    if [ -z "${new_x}" ] || [ "${new_x}" = "null" ] || 
       [ -z "${new_y}" ] || [ "${new_y}" = "null" ] || 
       [ -z "${new_w}" ] || [ "${new_w}" = "null" ] || 
       [ -z "${new_h}" ] || [ "${new_h}" = "null" ]; then
      if [ $retry_count -lt $max_retries ]; then
        retry_count=$((retry_count + 1))
        yabai_log "Invalid coordinates received for window ${window_id}, retrying (attempt ${retry_count}/${max_retries})..."
        sleep 0.5
        continue
      else
        yabai_log "Warning: Invalid coordinates received for window ${window_id} after ${max_retries} retries. Frame data: ${new_frame}"
        return 1
      fi
    fi
    
    # Check if position changed
    if [ "${new_x}" != "$(echo "${current_frame}" | jq -r '.x')" ] || 
       [ "${new_y}" != "$(echo "${current_frame}" | jq -r '.y')" ] || 
       [ "${new_w}" != "$(echo "${current_frame}" | jq -r '.w')" ] || 
       [ "${new_h}" != "$(echo "${current_frame}" | jq -r '.h')" ]; then
      yabai_log "Successfully positioned ${app} window, new frame: ${new_frame}"
      return 0
    else
      if [ $retry_count -lt $max_retries ]; then
        retry_count=$((retry_count + 1))
        yabai_log "Failed to change position of window ${window_id}, retrying (attempt ${retry_count}/${max_retries})..."
        sleep 0.5
        continue
      else
        yabai_log "Warning: Failed to position ${app} window after ${max_retries} retries. Current frame: ${new_frame}"
        return 1
      fi
    fi
  done
}

# Process a window according to its configuration
process_window() {
  local window_id="$1"
  local app="$2"
  local window_title="$3"
  local display_type="$4"
  local layout_content="$5"
  local display_info="$6"
  local retry_count=0
  local max_retries=3
  
  yabai_log "Processing window ${window_id} (${app}) with title \"${window_title}\""
  
  # Retry loop for windows that temporarily disappear
  while [ $retry_count -le $max_retries ]; do
    # Skip very small windows (likely UI controls, not main windows)
    local window_info
    window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
    if [ -z "${window_info}" ]; then
      if [ $retry_count -lt $max_retries ]; then
        retry_count=$((retry_count + 1))
        yabai_log "Window ${window_id} temporarily unavailable, retrying (attempt ${retry_count}/${max_retries})..."
        sleep 0.5
        continue
      else
        yabai_log "Window ${window_id} no longer exists after ${max_retries} retries, skipping"
        return 1
      fi
    fi
    
    # Check if window is visible
    local is_visible
    is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
    if [ "${is_visible}" = "false" ]; then
      yabai_log "Window ${window_id} exists but is not visible, attempting to make it visible"
      # Try to make the window visible
      if yabai -m window "${window_id}" --focus 2>/dev/null; then
        yabai_log "Successfully focused window ${window_id}"
      else
        yabai_log "Failed to focus window ${window_id}, it may be in a state where it can't be interacted with"
      fi
      # Wait a moment for the window to become visible
      sleep 0.5
      
      # Check again if window is visible after focusing
      window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
      if [ -n "${window_info}" ]; then
        is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
        if [ "${is_visible}" = "false" ]; then
          yabai_log "Window ${window_id} still not visible after focusing, will try to position anyway"
        else
          yabai_log "Successfully made window ${window_id} visible"
        fi
      fi
    fi
    
    # Window exists, proceed with processing
    local window_w=$(echo "${window_info}" | jq -r '.frame.w')
    local window_h=$(echo "${window_info}" | jq -r '.frame.h')
    
    if [ "$(echo "${window_w} < 100 || ${window_h} < 100" | bc -l)" -eq 1 ]; then
      yabai_log "Skipping small window ${window_id} (${window_w}x${window_h}) - likely a UI control element"
      return 0
    fi
    
    # Always try to focus the window first, regardless of visibility
    yabai_log "Focusing window ${window_id} before positioning"
    if ! yabai -m window --focus "${window_id}" 2>/dev/null; then
      yabai_log "Failed to focus window ${window_id}, will try to position anyway"
      # If focus fails, check if window still exists before continuing
      if ! yabai -m query --windows --window "${window_id}" &>/dev/null; then
        yabai_log "Window ${window_id} no longer exists, skipping positioning (attempt ${retry_count}/${max_retries})"
        return 1
      fi
    fi
    sleep 0.2  # Give time for focus to take effect
    
    # Ensure window is floating for precise positioning
    local is_floating=$(yabai -m query --windows --window "${window_id}" | jq -r '.["is-floating"]')
    if [ "${is_floating}" = "false" ]; then
      yabai_log "Making window ${window_id} floating for positioning"
      if ! yabai -m window "${window_id}" --toggle float 2>/dev/null; then
        yabai_log "Failed to make window ${window_id} floating, trying alternative approach"
        sleep 0.2
        
        # Check if window still exists before retry
        if ! yabai -m query --windows --window "${window_id}" &>/dev/null; then
          if [ $retry_count -lt $max_retries ]; then
            retry_count=$((retry_count + 1))
            yabai_log "Window ${window_id} disappeared during float toggle, retrying (attempt ${retry_count}/${max_retries})..."
            sleep 0.5
            continue
          else
            yabai_log "Window ${window_id} no longer exists after ${max_retries} retries, skipping"
            return 1
          fi
        fi
        
        if ! yabai -m window "${window_id}" --toggle float 2>/dev/null; then
          yabai_log "All attempts to make window ${window_id} floating failed, will try to position anyway"
        fi
      fi
      sleep 0.2  # Give yabai time to process the change
    fi
    
    # Check if window still exists after making it floating
    if ! yabai -m query --windows --window "${window_id}" &>/dev/null; then
      if [ $retry_count -lt $max_retries ]; then
        retry_count=$((retry_count + 1))
        yabai_log "Window ${window_id} disappeared after making it floating, retrying (attempt ${retry_count}/${max_retries})..."
        sleep 0.5
        continue
      else
        yabai_log "Window ${window_id} no longer exists after ${max_retries} retries, skipping"
        return 1
      fi
    fi
    
    local matched_position=""
    
    # Get window configs for this app
    local window_configs
    window_configs=$(echo "${layout_content}" | jq -r --arg app "${app}" --arg display "${display_type}" '.displays[$display].apps[$app].windows')
    local default_position
    default_position=$(echo "${layout_content}" | jq -r --arg app "${app}" --arg display "${display_type}" '.displays[$display].apps[$app].default_position')
    
    # First pass: Process configs with title patterns
    if [ "${window_configs}" != "null" ]; then
      local config_count
      config_count=$(echo "${window_configs}" | jq -r 'length')
      
      for i in $(seq 0 $((config_count - 1))); do
        local config
        config=$(echo "${window_configs}" | jq -c ".[$i]")
        
        if [ -n "${config}" ] && [ "${config}" != "null" ]; then
          local title_pattern
          title_pattern=$(echo "${config}" | jq -r '.title_pattern')
          local position_name
          position_name=$(echo "${config}" | jq -r '.position')
          
          # Skip empty title patterns in first pass
          if [ "${title_pattern}" != "" ]; then
            yabai_log "Checking config #$((i+1)): title_pattern=\"${title_pattern}\", position=\"${position_name}\""
            
            # Debug title pattern matching
            yabai_log "Checking if window title \"${window_title}\" matches pattern \"${title_pattern}\""
            
            # Check if window title contains the pattern (case-insensitive)
            if [[ "${window_title}" == *"${title_pattern}"* ]] || [[ "${window_title,,}" == *"${title_pattern,,}"* ]]; then
              yabai_log "Window title matches pattern ${title_pattern}, using position: ${position_name}"
              matched_position="${position_name}"
              
              # Position the window using the matched position
              position_window_by_name "${window_id}" "${app}" "${position_name}" "${display_type}" "${layout_content}" "${display_info}"
              return $?
            else
              yabai_log "Window title does not match pattern ${title_pattern}"
            fi
          fi
        fi
      done
      
      # Second pass: Process configs with empty title patterns
      for i in $(seq 0 $((config_count - 1))); do
        local config
        config=$(echo "${window_configs}" | jq -c ".[$i]")
        
        if [ -n "${config}" ] && [ "${config}" != "null" ]; then
          local title_pattern
          title_pattern=$(echo "${config}" | jq -r '.title_pattern')
          local position_name
          position_name=$(echo "${config}" | jq -r '.position')
          
          # Only process empty title patterns in second pass
          if [ "${title_pattern}" = "" ]; then
            yabai_log "Checking config #$((i+1)): empty title_pattern, position=\"${position_name}\""
            
            # Debug title pattern matching
            yabai_log "Checking if window title \"${window_title}\" is empty"
            
            # Special case for empty title pattern - match only empty titles
            if [ "${window_title}" = "" ]; then
              yabai_log "Window has empty title, matching empty title pattern, using position: ${position_name}"
              matched_position="${position_name}"
              
              # Position the window using the matched position
              position_window_by_name "${window_id}" "${app}" "${position_name}" "${display_type}" "${layout_content}" "${display_info}"
              return $?
            fi
          fi
        fi
      done
    fi
    
    # If no specific window config matched, use default position if available
    if [ -z "${matched_position}" ] && [ "${default_position}" != "null" ]; then
      yabai_log "Using default position for window: ${default_position}"
      position_window_by_name "${window_id}" "${app}" "${default_position}" "${display_type}" "${layout_content}" "${display_info}"
      return $?
    fi
    
    # If no default position, use app-level position if available
    if [ -z "${matched_position}" ]; then
      local app_position
      app_position=$(echo "${layout_content}" | jq -r --arg app "${app}" --arg display "${display_type}" '.displays[$display].apps[$app].position')
      
      if [ -n "${app_position}" ] && [ "${app_position}" != "null" ]; then
        yabai_log "Using app-level position: ${app_position}"
        position_window_by_name "${window_id}" "${app}" "${app_position}" "${display_type}" "${layout_content}" "${display_info}"
        return $?
      fi
    fi
    
    yabai_log "No position found for window ${window_id} (${app})"
    return 1
  done
}

# Helper function to position a window by position name
position_window_by_name() {
  local window_id="$1"
  local app="$2"
  local position_name="$3"
  local display_type="$4"
  local layout_content="$5"
  local display_info="$6"
  local retry_count=0
  local max_retries=3
  
  yabai_log "Positioning window by name: ${position_name}"
  
  # Retry loop for windows that temporarily disappear
  while [ $retry_count -le $max_retries ]; do
    # Verify window still exists before proceeding
    local window_info
    window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
    if [ -z "${window_info}" ]; then
      if [ $retry_count -lt $max_retries ]; then
        retry_count=$((retry_count + 1))
        yabai_log "Window ${window_id} temporarily unavailable during positioning, retrying (attempt ${retry_count}/${max_retries})..."
        sleep 0.5
        continue
      else
        yabai_log "Window ${window_id} no longer exists after ${max_retries} retries, skipping positioning"
        return 1
      fi
    fi
    
    # Check if window is visible
    local is_visible
    is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
    if [ "${is_visible}" = "false" ]; then
      yabai_log "Window ${window_id} exists but is not visible, attempting to make it visible"
      # Try to make the window visible
      if yabai -m window "${window_id}" --focus 2>/dev/null; then
        yabai_log "Successfully focused window ${window_id}"
      else
        yabai_log "Failed to focus window ${window_id}, it may be in a state where it can't be interacted with"
      fi
      # Wait a moment for the window to become visible
      sleep 0.2
    fi
    
    # Get position data from layout
    local position_data
    position_data=$(echo "${layout_content}" | jq -r --arg pos "${position_name}" --arg display "${display_type}" '.displays[$display].positions[$pos]')
    yabai_log "Position data for ${position_name}: ${position_data}"
    
    if [ "${position_data}" = "null" ]; then
      yabai_log "Position ${position_name} not found in layout"
      return 1
    fi
    
    # Extract position values
    local rel_x=$(echo "${position_data}" | jq -r '.x')
    local rel_y=$(echo "${position_data}" | jq -r '.y')
    local rel_w=$(echo "${position_data}" | jq -r '.w')
    local rel_h=$(echo "${position_data}" | jq -r '.h')
    
    # Get display dimensions
    local display_x=$(echo "${display_info}" | jq -r '.frame.x')
    local display_y=$(echo "${display_info}" | jq -r '.frame.y')
    local display_width=$(echo "${display_info}" | jq -r '.frame.w')
    local display_height=$(echo "${display_info}" | jq -r '.frame.h')
    
    # Calculate absolute position with proper floating-point arithmetic and rounding
    local abs_x
    abs_x=$(echo "${display_x} + (${rel_x} * ${display_width})" | bc -l | awk '{printf "%.0f", $1}')
    local abs_y
    abs_y=$(echo "${display_y} + (${rel_y} * ${display_height})" | bc -l | awk '{printf "%.0f", $1}')
    local abs_w
    abs_w=$(echo "${rel_w} * ${display_width}" | bc -l | awk '{printf "%.0f", $1}')
    local abs_h
    abs_h=$(echo "${rel_h} * ${display_height}" | bc -l | awk '{printf "%.0f", $1}')
    
    yabai_log "Absolute position: x=${abs_x}, y=${abs_y}, w=${abs_w}, h=${abs_h}"
    
    # Position the window
    local result=0
    position_window "${window_id}" "${app}" "${abs_x}" "${abs_y}" "${abs_w}" "${abs_h}"
    result=$?
    
    # Check if positioning failed due to window disappearing
    if [ $result -ne 0 ]; then
      if ! yabai -m query --windows --window "${window_id}" &>/dev/null; then
        if [ $retry_count -lt $max_retries ]; then
          retry_count=$((retry_count + 1))
          yabai_log "Window ${window_id} disappeared during positioning, retrying (attempt ${retry_count}/${max_retries})..."
          sleep 0.5
          continue
        else
          yabai_log "Window ${window_id} no longer exists after ${max_retries} retries, giving up"
          return 1
        fi
      fi
    fi
    
    # If we got here, either positioning succeeded or failed for reasons other than window disappearing
    return $result
  done
}

# Function to check if a window requires position update
requires_position_update() {
  local window_id="$1"
  local app="$2"
  local window_title="$3"
  local display_type="$4"
  local layout_content="$5"
  local display_info="$6"
  local tolerance="${7:-26}"  # Default tolerance of 26 pixels to account for macOS title bar
  
  yabai_log "Checking if window ${window_id} (${app}) requires position update"
  
  # Verify window exists
  local window_info
  window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
  if [ -z "${window_info}" ]; then
    # Try to find the window in the global list
    yabai_log "Direct query failed, checking global window list..."
    window_info=$(yabai -m query --windows | jq ".[] | select(.id == ${window_id})" 2>/dev/null)
    
    if [ -z "${window_info}" ]; then
      yabai_log "Window ${window_id} does not exist, cannot check position"
      return 1  # Cannot update a non-existent window
    else
      yabai_log "Window ${window_id} exists in global list but can't be queried directly"
      # We'll try to update it anyway
      return 0
    fi
  fi
  
  # Check if window is visible
  local is_visible
  is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
  if [ "${is_visible}" = "false" ]; then
    yabai_log "Window ${window_id} exists but is not visible, will attempt to make it visible"
    # We'll still try to update it, as we might be able to make it visible
    return 0
  fi
  
  # Get current window position
  local current_frame
  current_frame=$(echo "${window_info}" | jq -r '.frame')
  
  if [ -z "${current_frame}" ] || [ "${current_frame}" = "null" ]; then
    yabai_log "Could not get current frame for window ${window_id}"
    return 0  # Assume update needed if we can't get current position
  fi
  
  local current_x=$(echo "${current_frame}" | jq -r '.x')
  local current_y=$(echo "${current_frame}" | jq -r '.y')
  local current_w=$(echo "${current_frame}" | jq -r '.w')
  local current_h=$(echo "${current_frame}" | jq -r '.h')
  
  # Find the target position for this window
  local position_name=""
  local matched_position=""
  
  # Check for window-specific configs
  local window_configs=$(echo "${layout_content}" | jq -r --arg app "${app}" --arg display "${display_type}" '.displays[$display].apps[$app].windows')
  
  if [ "${window_configs}" != "null" ]; then
    local config_count=$(echo "${window_configs}" | jq -r 'length')
    
    # First pass: Check for title pattern matches
    for i in $(seq 0 $((config_count - 1))); do
      local config=$(echo "${window_configs}" | jq -c ".[$i]")
      
      if [ -n "${config}" ] && [ "${config}" != "null" ]; then
        local title_pattern=$(echo "${config}" | jq -r '.title_pattern')
        local pos=$(echo "${config}" | jq -r '.position')
        
        # Skip empty title patterns in first pass
        if [ -n "${title_pattern}" ]; then
          # Check if window title contains the pattern (case-insensitive)
          if [[ "${window_title}" == *"${title_pattern}"* ]] || [[ "${window_title,,}" == *"${title_pattern,,}"* ]]; then
            position_name="${pos}"
            break
          fi
        fi
      fi
    done
    
    # Second pass: Check for empty title patterns
    if [ -z "${position_name}" ]; then
      for i in $(seq 0 $((config_count - 1))); do
        local config=$(echo "${window_configs}" | jq -c ".[$i]")
        
        if [ -n "${config}" ] && [ "${config}" != "null" ]; then
          local title_pattern=$(echo "${config}" | jq -r '.title_pattern')
          local pos=$(echo "${config}" | jq -r '.position')
          
          # Only process empty title patterns in second pass
          if [ -z "${title_pattern}" ] && [ -z "${window_title}" ]; then
            position_name="${pos}"
            break
          fi
        fi
      done
    fi
  fi
  
  # If no specific window config matched, use default position
  if [ -z "${position_name}" ]; then
    local default_position=$(echo "${layout_content}" | jq -r --arg app "${app}" --arg display "${display_type}" '.displays[$display].apps[$app].default_position')
    
    if [ -n "${default_position}" ] && [ "${default_position}" != "null" ]; then
      position_name="${default_position}"
    fi
  fi
  
  # If no default position, use app-level position
  if [ -z "${position_name}" ]; then
    local app_position=$(echo "${layout_content}" | jq -r --arg app "${app}" --arg display "${display_type}" '.displays[$display].apps[$app].position')
    
    if [ -n "${app_position}" ] && [ "${app_position}" != "null" ]; then
      position_name="${app_position}"
    fi
  fi
  
  # If no position found, we can't determine if update is needed
  if [ -z "${position_name}" ]; then
    yabai_log "No position configuration found for window ${window_id} (${app})"
    return 1  # No update needed if we don't know where it should be
  fi
  
  # Get position data from layout
  local position_data
  position_data=$(echo "${layout_content}" | jq -r --arg pos "${position_name}" --arg display "${display_type}" '.displays[$display].positions[$pos]')
  
  if [ "${position_data}" = "null" ]; then
    yabai_log "Position ${position_name} not found in layout"
    return 1  # No update needed if position doesn't exist
  fi
  
  # Extract position values
  local rel_x=$(echo "${position_data}" | jq -r '.x')
  local rel_y=$(echo "${position_data}" | jq -r '.y')
  local rel_w=$(echo "${position_data}" | jq -r '.w')
  local rel_h=$(echo "${position_data}" | jq -r '.h')
  
  # Get display dimensions
  local display_x=$(echo "${display_info}" | jq -r '.frame.x')
  local display_y=$(echo "${display_info}" | jq -r '.frame.y')
  local display_width=$(echo "${display_info}" | jq -r '.frame.w')
  local display_height=$(echo "${display_info}" | jq -r '.frame.h')
  
  # Calculate absolute position with proper floating-point arithmetic and rounding
  local target_x=$(echo "${display_x} + (${rel_x} * ${display_width})" | bc -l | awk '{printf "%.0f", $1}')
  local target_y=$(echo "${display_y} + (${rel_y} * ${display_height})" | bc -l | awk '{printf "%.0f", $1}')
  local target_w=$(echo "${rel_w} * ${display_width}" | bc -l | awk '{printf "%.0f", $1}')
  local target_h=$(echo "${rel_h} * ${display_height}" | bc -l | awk '{printf "%.0f", $1}')
  
  # Calculate differences
  local x_diff=$(echo "${current_x} - ${target_x}" | bc -l | awk '{print ($1 < 0) ? -$1 : $1}')
  local y_diff=$(echo "${current_y} - ${target_y}" | bc -l | awk '{print ($1 < 0) ? -$1 : $1}')
  local w_diff=$(echo "${current_w} - ${target_w}" | bc -l | awk '{print ($1 < 0) ? -$1 : $1}')
  local h_diff=$(echo "${current_h} - ${target_h}" | bc -l | awk '{print ($1 < 0) ? -$1 : $1}')
  
  # Convert to integers for comparison
  local x_diff_int=$(echo "${x_diff}" | awk '{printf "%.0f", $1}')
  local y_diff_int=$(echo "${y_diff}" | awk '{printf "%.0f", $1}')
  local w_diff_int=$(echo "${w_diff}" | awk '{printf "%.0f", $1}')
  local h_diff_int=$(echo "${h_diff}" | awk '{printf "%.0f", $1}')
  
  # Check if any dimension is out of tolerance
  if [ "${x_diff_int}" -gt "${tolerance}" ] || 
     [ "${y_diff_int}" -gt "${tolerance}" ] || 
     [ "${w_diff_int}" -gt "${tolerance}" ] || 
     [ "${h_diff_int}" -gt "${tolerance}" ]; then
    yabai_log "Window ${window_id} (${app}) requires position update:"
    yabai_log "  Current: x=${current_x}, y=${current_y}, w=${current_w}, h=${current_h}"
    yabai_log "  Target:  x=${target_x}, y=${target_y}, w=${target_w}, h=${target_h}"
    yabai_log "  Diff:    x=${x_diff_int}, y=${y_diff_int}, w=${w_diff_int}, h=${h_diff_int}"
    return 0  # Update needed
  else
    yabai_log "Window ${window_id} (${app}) is already in correct position (within tolerance of ${tolerance}px)"
    return 1  # No update needed
  fi
}

# Function to reposition windows based on Hammerspoon layout
reposition_windows() {
  yabai_log "Starting window repositioning..."
  
  # Get display information
  local displays
  displays=$(yabai -m query --displays)
  yabai_log "Display info: ${displays}"
  
  # Find main and external displays
  local main_display
  main_display=$(echo "${displays}" | jq -r '.[] | select(.index == 1) | @json')
  local external_display
  external_display=$(echo "${displays}" | jq -r '.[] | select(.index == 2) | @json')
  
  # Check if external display is available
  if [ -n "${external_display}" ]; then
    # Try to hide OBSBOT Center without blocking
    local obsbot_window_id
    obsbot_window_id=$(yabai -m query --windows | jq -r '.[] | select(.app | test("(?i)obsbot[ _]center")) | .id' | head -1)
    if [ -n "${obsbot_window_id}" ]; then
      yabai_log "Found OBSBOT Center window: ${obsbot_window_id}"
      yabai_log "Attempting to hide OBSBOT Center"
      yabai -m window "${obsbot_window_id}" --minimize &>/dev/null || true
    fi
  fi
  
  # Extract app layouts for main and external displays
  local main_apps
  main_apps=$(echo "${layout_content}" | jq -r '.displays.main.apps | keys[]' 2>/dev/null || echo "")
  local external_apps
  external_apps=$(echo "${layout_content}" | jq -r '.displays.external.apps | keys[]' 2>/dev/null || echo "")
  
  yabai_log "Apps in main display layout: ${main_apps}"
  yabai_log "Apps in external display layout: ${external_apps}"
  
  # Get all windows
  local all_windows=$(yabai -m query --windows)
  local windows_updated=0
  local windows_skipped=0
  
  # Process external display apps
  if [ -n "${external_display}" ]; then
    yabai_log "Processing external display apps"
    
    # Process each app in the external display layout
    for app in ${external_apps}; do
      yabai_log "Processing app in external layout: ${app}"
      
      # Check if this app has a configuration
      local app_config=$(echo "${layout_content}" | jq -r --arg app "${app}" '.displays.external.apps[$app]')
      if [ "${app_config}" = "null" ]; then
        yabai_log "No configuration found for app ${app} in external layout, skipping"
        continue
      fi
      
      # Get all windows for this app
      local app_windows=$(echo "${all_windows}" | jq -c --arg app "${app}" '.[] | select(.app | ascii_downcase == ($app | ascii_downcase))')
      
      if [ -z "${app_windows}" ]; then
        yabai_log "No windows found for app ${app}"
        continue
      fi
      
      # Process each window for this app - avoid pipe to while loop to prevent subshell issues
      local window_count=$(echo "${app_windows}" | jq -s 'length')
      yabai_log "Found ${window_count} windows for app ${app}"
      
      for ((i=0; i<window_count; i++)); do
        # Use a subshell to prevent errors from affecting the main loop
        (
          local window_json=$(echo "${app_windows}" | jq -s ".[$i]")
          
          if [ -n "${window_json}" ] && [ "${window_json}" != "null" ]; then
            local window_id=$(echo "${window_json}" | jq -r '.id')
            local window_title=$(echo "${window_json}" | jq -r '.title')
            
            yabai_log "Processing window ${i+1}/${window_count} for app ${app}: ID ${window_id}, Title \"${window_title}\""
            
            # Check if this window has a specific configuration based on title
            local has_config=false
            
            # Check for window-specific configs
            local window_configs=$(echo "${layout_content}" | jq -r --arg app "${app}" '.displays.external.apps[$app].windows')
            if [ "${window_configs}" != "null" ]; then
              local config_count=$(echo "${window_configs}" | jq -r 'length')
              
              # Check if any title pattern matches
              for j in $(seq 0 $((config_count - 1))); do
                local title_pattern=$(echo "${window_configs}" | jq -r ".[$j].title_pattern")
                
                if [ -z "${title_pattern}" ] && [ -z "${window_title}" ]; then
                  # Empty title pattern matches empty window title
                  has_config=true
                  break
                elif [ -n "${title_pattern}" ] && [[ "${window_title}" == *"${title_pattern}"* ]]; then
                  # Title pattern matches window title
                  has_config=true
                  break
                fi
              done
            fi
            
            # Check for default position
            local default_position=$(echo "${layout_content}" | jq -r --arg app "${app}" '.displays.external.apps[$app].default_position')
            if [ "${default_position}" != "null" ]; then
              has_config=true
            fi
            
            # Check for app-level position
            local app_position=$(echo "${layout_content}" | jq -r --arg app "${app}" '.displays.external.apps[$app].position')
            if [ "${app_position}" != "null" ]; then
              has_config=true
            fi
            
            # Only process window if it has a configuration
            if [ "${has_config}" = "true" ]; then
              yabai_log "Found configuration for window ${window_id} (${app}) with title \"${window_title}\""
              
              # Check if window exists
              local window_info
              yabai_log "Checking if window ${window_id} (${app}) exists..."
              # First try direct query
              window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
              
              # If direct query fails, try to find the window in the global list
              if [ -z "${window_info}" ]; then
                yabai_log "Direct query failed, checking global window list..."
                window_info=$(yabai -m query --windows | jq ".[] | select(.id == ${window_id})" 2>/dev/null)
                
                if [ -z "${window_info}" ]; then
                  yabai_log "Skipping window ${window_id} (${app}) - window no longer exists in global list"
                  return 0
                else
                  yabai_log "Window ${window_id} (${app}) exists in global list but can't be queried directly"
                  
                  # Try to focus the window to make it accessible
                  yabai_log "Window ${window_id} (${app}) exists but is not visible, attempting to make it visible"
                  if yabai -m window --focus "${window_id}" 2>/dev/null; then
                    yabai_log "Successfully focused window ${window_id}"
                    sleep 0.5
                    
                    # Check if window is now visible
                    local is_visible
                    is_visible=$(echo "${window_info}" | jq -r '."is-visible"')
                    
                    if [ "${is_visible}" = "true" ]; then
                      yabai_log "Window ${window_id} is now visible after focusing"
                      # Try direct query again now that window is focused
                      window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
                      if [ -z "${window_info}" ]; then
                        yabai_log "Window ${window_id} still can't be queried directly even after focusing"
                      fi
                    else
                      yabai_log "Window ${window_id} still not visible after focusing, will try to position anyway"
                    fi
                  else
                    yabai_log "Failed to focus window ${window_id}, it may be in a state where it can't be interacted with"
                  fi
                fi
              else
                yabai_log "Window ${window_id} (${app}) exists, window_info: ${window_info}"
              fi
              
              # Check if window is visible
              local is_visible
              is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
              if [ "${is_visible}" = "false" ]; then
                yabai_log "Window ${window_id} (${app}) exists but is not visible, attempting to make it visible"
                # Try to make the window visible
                if yabai -m window "${window_id}" --focus 2>/dev/null; then
                  yabai_log "Successfully focused window ${window_id}"
                else
                  yabai_log "Failed to focus window ${window_id}, it may be in a state where it can't be interacted with"
                fi
                # Wait a moment for the window to become visible
                sleep 0.5
                
                # Check again if window is visible after focusing
                window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
                if [ -n "${window_info}" ]; then
                  is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
                  if [ "${is_visible}" = "false" ]; then
                    yabai_log "Window ${window_id} still not visible after focusing, will try to position anyway"
                  else
                    yabai_log "Successfully made window ${window_id} visible"
                  fi
                fi
              fi
              
              # Check if window requires position update
              if requires_position_update "${window_id}" "${app}" "${window_title}" "external" "${layout_content}" "${external_display}"; then
                yabai_log "Repositioning window ${window_id} (${app})"
                process_window "${window_id}" "${app}" "${window_title}" "external" "${layout_content}" "${external_display}" || true
                windows_updated=$((windows_updated + 1))
              else
                yabai_log "Skipping window ${window_id} (${app}) - already in correct position"
                windows_skipped=$((windows_skipped + 1))
              fi
            else
              yabai_log "No configuration found for window ${window_id} (${app}) with title \"${window_title}\", skipping"
            fi
          fi
        ) || {
          yabai_log "Error processing window for app ${app}, continuing with next window"
        }
      done
      yabai_log "Finished processing all windows for app ${app}"
    done
    yabai_log "Finished processing all external display apps"
  fi
  
  # Process main display apps
  if [ -n "${main_display}" ]; then
    yabai_log "Processing main display apps"
    
    # Process each app in the main display layout
    for app in ${main_apps}; do
      yabai_log "Processing app in main layout: ${app}"
      
      # Check if this app has a configuration
      local app_config=$(echo "${layout_content}" | jq -r --arg app "${app}" '.displays.main.apps[$app]')
      if [ "${app_config}" = "null" ]; then
        yabai_log "No configuration found for app ${app} in main layout, skipping"
        continue
      fi
      
      # Get all windows for this app
      local app_windows=$(echo "${all_windows}" | jq -c --arg app "${app}" '.[] | select(.app | ascii_downcase == ($app | ascii_downcase))')
      
      if [ -z "${app_windows}" ]; then
        yabai_log "No windows found for app ${app}"
        continue
      fi
      
      # Process each window for this app - avoid pipe to while loop to prevent subshell issues
      local window_count=$(echo "${app_windows}" | jq -s 'length')
      yabai_log "Found ${window_count} windows for app ${app}"
      
      for ((j=0; j<window_count; j++)); do
        # Use a subshell to prevent errors from affecting the main loop
        (
          local window_json=$(echo "${app_windows}" | jq -s ".[$j]")
          
          if [ -n "${window_json}" ] && [ "${window_json}" != "null" ]; then
            local window_id=$(echo "${window_json}" | jq -r '.id')
            local window_title=$(echo "${window_json}" | jq -r '.title')
            
            yabai_log "Processing window ${j+1}/${window_count} for app ${app}: ID ${window_id}, Title \"${window_title}\""
            
            # Check if this window has a specific configuration based on title
            local has_config=false
            
            # Check for window-specific configs
            local window_configs=$(echo "${layout_content}" | jq -r --arg app "${app}" '.displays.main.apps[$app].windows')
            if [ "${window_configs}" != "null" ]; then
              local config_count=$(echo "${window_configs}" | jq -r 'length')
              
              # Check if any title pattern matches
              for k in $(seq 0 $((config_count - 1))); do
                local title_pattern=$(echo "${window_configs}" | jq -r ".[$k].title_pattern")
                
                if [ -z "${title_pattern}" ] && [ -z "${window_title}" ]; then
                  # Empty title pattern matches empty window title
                  has_config=true
                  break
                elif [ -n "${title_pattern}" ] && [[ "${window_title}" == *"${title_pattern}"* ]]; then
                  # Title pattern matches window title
                  has_config=true
                  break
                fi
              done
            fi
            
            # Check for default position
            local default_position=$(echo "${layout_content}" | jq -r --arg app "${app}" '.displays.main.apps[$app].default_position')
            if [ "${default_position}" != "null" ]; then
              has_config=true
            fi
            
            # Check for app-level position
            local app_position=$(echo "${layout_content}" | jq -r --arg app "${app}" '.displays.main.apps[$app].position')
            if [ "${app_position}" != "null" ]; then
              has_config=true
            fi
            
            # Only process window if it has a configuration
            if [ "${has_config}" = "true" ]; then
              yabai_log "Found configuration for window ${window_id} (${app}) with title \"${window_title}\""
              
              # Check if window exists
              local window_info
              yabai_log "Checking if window ${window_id} (${app}) exists..."
              # First try direct query
              window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
              
              # If direct query fails, try to find the window in the global list
              if [ -z "${window_info}" ]; then
                yabai_log "Direct query failed, checking global window list..."
                window_info=$(yabai -m query --windows | jq ".[] | select(.id == ${window_id})" 2>/dev/null)
                
                if [ -z "${window_info}" ]; then
                  yabai_log "Skipping window ${window_id} (${app}) - window no longer exists in global list"
                  return 0
                else
                  yabai_log "Window ${window_id} (${app}) exists in global list but can't be queried directly"
                fi
              else
                yabai_log "Window ${window_id} (${app}) exists, window_info: ${window_info}"
              fi
              
              # Check if window is visible
              local is_visible
              is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
              if [ "${is_visible}" = "false" ]; then
                yabai_log "Window ${window_id} (${app}) exists but is not visible, attempting to make it visible"
                # Try to make the window visible
                if yabai -m window "${window_id}" --focus 2>/dev/null; then
                  yabai_log "Successfully focused window ${window_id}"
                else
                  yabai_log "Failed to focus window ${window_id}, it may be in a state where it can't be interacted with"
                fi
                # Wait a moment for the window to become visible
                sleep 0.5
                
                # Check again if window is visible after focusing
                window_info=$(yabai -m query --windows --window "${window_id}" 2>/dev/null)
                if [ -n "${window_info}" ]; then
                  is_visible=$(echo "${window_info}" | jq -r '.["is-visible"]')
                  if [ "${is_visible}" = "false" ]; then
                    yabai_log "Window ${window_id} still not visible after focusing, will try to position anyway"
                  else
                    yabai_log "Successfully made window ${window_id} visible"
                  fi
                fi
              fi
              
              # Check if window requires position update
              if requires_position_update "${window_id}" "${app}" "${window_title}" "main" "${layout_content}" "${main_display}"; then
                yabai_log "Repositioning window ${window_id} (${app})"
                process_window "${window_id}" "${app}" "${window_title}" "main" "${layout_content}" "${main_display}" || true
                windows_updated=$((windows_updated + 1))
              else
                yabai_log "Skipping window ${window_id} (${app}) - already in correct position"
                windows_skipped=$((windows_skipped + 1))
              fi
            else
              yabai_log "No configuration found for window ${window_id} (${app}) with title \"${window_title}\", skipping"
            fi
          fi
        ) || {
          yabai_log "Error processing window for app ${app}, continuing with next window"
        }
      done
      yabai_log "Finished processing all windows for app ${app}"
    done
    yabai_log "Finished processing all main display apps"
  fi
  
  yabai_log "Window repositioning completed: ${windows_updated} windows updated, ${windows_skipped} windows skipped (already in position)"
  return 0
}

# Function to draw window positions
draw_window_positions() {
    yabai_log "Drawing window positions..."
    
    # Get display information
    local displays
    displays=$(yabai -m query --displays)
    yabai_log "Display info: ${displays}"
    
    # Get all windows
    local windows
    windows=$(yabai -m query --windows)
    
    # Initialize grid
    declare -A grid
    local rows=24
    local cols=80
    
    # Initialize empty grid
    for ((i=0; i<rows; i++)); do
        for ((j=0; j<cols; j++)); do
            grid[$i,$j]=" "
        done
    done
    
    # Process each window
    echo "${windows}" | jq -c '.[]' | while read -r window; do
        local window_id
        window_id=$(echo "${window}" | jq -r '.id')
        local app
        app=$(echo "${window}" | jq -r '.app')
        local title
        title=$(echo "${window}" | jq -r '.title')
        local frame
        frame=$(echo "${window}" | jq -r '.frame')
        local display
        display=$(echo "${window}" | jq -r '.display')
        local space
        space=$(echo "${window}" | jq -r '.space')
        local floating
        floating=$(echo "${window}" | jq -r '."is-floating"')
        
        yabai_log "Window ${window_id} (${app})"
        yabai_log "  Title: ${title}"
        yabai_log "  Frame: ${frame}"
        yabai_log "  Display: ${display}"
        yabai_log "  Space: ${space}"
        yabai_log "  Floating: ${floating}"
        
        # Extract coordinates using bc for floating point math
        local x
        x=$(echo "${frame}" | jq -r '.x' | xargs printf "%.0f")
        local y
        y=$(echo "${frame}" | jq -r '.y' | xargs printf "%.0f")
        local w
        w=$(echo "${frame}" | jq -r '.w' | xargs printf "%.0f")
        local h
        h=$(echo "${frame}" | jq -r '.h' | xargs printf "%.0f")
        
        yabai_log "  Position: (${x},${y}) ${w}x${h}"
        
        # Scale coordinates to fit in terminal using bc
        local scaled_x
        scaled_x=$(echo "scale=0; ${x}/100" | bc)
        local scaled_y
        scaled_y=$(echo "scale=0; ${y}/100" | bc)
        local scaled_w
        scaled_w=$(echo "scale=0; ${w}/100" | bc)
        local scaled_h
        scaled_h=$(echo "scale=0; ${h}/100" | bc)
        
        # Convert to integers and ensure they're within bounds
        scaled_x=${scaled_x%.*}
        scaled_y=${scaled_y%.*}
        scaled_w=${scaled_w%.*}
        scaled_h=${scaled_h%.*}
        
        # Draw the window in the grid
        draw_window grid "${app}" "${scaled_x}" "${scaled_y}" "${scaled_w}" "${scaled_h}"
    done
    
    # Display the grid
    for ((i=0; i<rows; i++)); do
        for ((j=0; j<cols; j++)); do
            printf "%s" "${grid[$i,$j]}"
        done
        printf "\n"
    done
}

# Helper function to draw a window in the specified grid
draw_window() {
    local grid_name=$1  # Name of the grid array
    local name=$2
    local x=$3
    local y=$4
    local w=$5
    local h=$6
    local rows=24
    local cols=80
    
    # Ensure minimum size and bounds
    w=$((w > 0 ? w : 1))
    h=$((h > 0 ? h : 1))
    [[ $x -lt 0 ]] && x=0
    [[ $y -lt 0 ]] && y=0
    [[ $x -ge cols ]] && x=$((cols-w))
    [[ $y -ge rows ]] && y=$((rows-h))
    [[ $((x + w)) -gt cols ]] && w=$((cols - x))
    [[ $((y + h)) -gt rows ]] && h=$((rows - y))

    # Draw borders and fill
    for ((i=y; i<y+h && i<rows; i++)); do
        for ((j=x; j<x+w && j<cols; j++)); do
            if ((i == y || i == y+h-1)); then
                eval "${grid_name}[\$i,\$j]='-'"
            elif ((j == x || j == x+w-1)); then
                eval "${grid_name}[\$i,\$j]='|'"
            else
                eval "${grid_name}[\$i,\$j]='.'"
            fi
        done
    done

    # Add name in center if there's room
    if ((w >= ${#name} + 2 && h >= 3)); then
        local name_y=$((y + h/2))
        local name_x=$((x + (w-${#name})/2))
        for ((i=0; i<${#name} && name_x+i<cols; i++)); do
            eval "${grid_name}[\$name_y,\$((name_x+i))]=\${name:\$i:1}"
        done
    fi
}

function reposition_windows_managed() {
    windows=$(yabai -m query --windows)
    
    signal_id=$(echo "$windows" | jq '.[] | select(.app=="Signal") | .id')
    warp_id=$(echo "$windows" | jq '.[] | select(.app=="Warp") | .id')
    cursor_id=$(echo "$windows" | jq '.[] | select(.app=="Cursor") | .id')
    youtube_id=$(echo "$windows" | jq '.[] | select(.app=="YouTube") | .id')

    if [ -n "$signal_id" ] && [ -n "$warp_id" ] && [ -n "$cursor_id" ] && [ -n "$youtube_id" ]; then
        echo "Found all windows, preparing to move (managed mode)..."

        # Reset the layout
        yabai -m config layout bsp
        yabai -m config auto_balance off
        yabai -m config window_placement second_child

        # Move all windows to space 4 on display 2
        for id in $signal_id $warp_id $cursor_id $youtube_id; do
            yabai -m window $id --space 4
            yabai -m window $id --display 2
        done

        sleep 0.5

        # Ensure all windows are managed
        for id in $signal_id $warp_id $cursor_id $youtube_id; do
            is_floating=$(yabai -m query --windows --window $id | jq -r '.["is-floating"]')
            if [[ "$is_floating" == "true" ]]; then
                yabai -m window $id --toggle float
            fi
        done

        # 1. Set up initial Signal/Warp stack
        yabai -m window $signal_id --focus
        yabai -m config split_type vertical
        yabai -m window $warp_id --focus
        yabai -m window $warp_id --move rel:0:700  # Move Warp down
        yabai -m config split_ratio 0.5  # Equal split between Signal and Warp

        # 2. Add Cursor to the right
        yabai -m window $signal_id --focus
        yabai -m config split_type horizontal
        yabai -m window $cursor_id --focus
        yabai -m window $cursor_id --move rel:700:0  # Move Cursor right
        yabai -m config split_ratio 0.2  # Signal/Warp stack gets 20%

        # 3. Add YouTube to the right of Cursor
        yabai -m window $cursor_id --focus
        yabai -m window $youtube_id --focus
        yabai -m window $youtube_id --move rel:700:0  # Move YouTube right
        yabai -m config split_ratio 0.75  # Cursor gets 75% of remaining space

        # 4. Final adjustments
        yabai -m window $signal_id --focus
        yabai -m config split_type vertical

        yabai -m window $cursor_id --focus
        yabai -m config split_type horizontal

        echo "Windows positioned successfully (managed mode)"
    else
        echo "Not all required windows found"
    fi
}

# Update the create_app_rules function with better escaping for problematic apps
create_app_rules() {
  local layout_content="$1"
  
  yabai_log "Creating yabai rules for all apps in layout configuration..."
  
  # Get all apps from main display and external display as JSON arrays
  local main_apps_json=$(echo "${layout_content}" | jq -r '.displays.main.apps | keys')
  local external_apps_json=$(echo "${layout_content}" | jq -r '.displays.external.apps | keys')
  
  # Combine all apps and remove duplicates
  local all_apps_json=$(echo "${main_apps_json}" "${external_apps_json}" | jq -s 'add | unique')
  
  # Process each app using jq to handle spaces in names
  echo "${all_apps_json}" | jq -r '.[]' | while read -r app; do
    if [ -n "${app}" ]; then
      yabai_log "Creating rule for app: \"${app}\""
      
      # Create rule with exact match, properly escaped
      app_escaped=$(echo "${app}" | sed 's/[\/&]/\\&/g')
      yabai -m rule --add app="^${app_escaped}$" manage=off sticky=on
      
      # Apply rule to existing windows
      app_windows=$(yabai -m query --windows | jq -r --arg app "${app}" '.[] | select(.app == $app) | .id')
      
      for window_id in ${app_windows}; do
        if [ -n "${window_id}" ]; then
          yabai_log "Applying rule to existing window ${window_id} (${app})"
          
          # Make sure window is floating
          if [ "$(yabai -m query --windows --window "${window_id}" | jq -r '.["is-floating"]')" = "false" ]; then
            yabai -m window "${window_id}" --toggle float
            yabai_log "Set window ${window_id} (${app}) to floating mode"
          fi
        fi
      done
    fi
  done

  yabai_log "Finished creating app rules"
}

# Main execution
yabai_log "Starting main execution..."

# Run setup
yabai_log "Running setup_yabai..."
setup_yabai
yabai_log "Setup completed"

# Reposition windows
yabai_log "Running reposition_windows..."
reposition_windows
yabai_log "Repositioning completed"

# Draw window positions
yabai_log "Running draw_window_positions..."
draw_window_positions
yabai_log "Drawing completed"
yabai_log "Script execution completed"
