#!/usr/bin/env bash

function setup_yabai() {
         # Basic window settings
        yabai -m config layout bsp
        yabai -m config window_placement second_child
        yabai -m config split_ratio 0.50
        yabai -m config auto_balance off
        yabai -m config window_origin_display default

        # Window opacity settings
        yabai -m config active_window_opacity 1.0
        yabai -m config normal_window_opacity 0.9

        # Padding
        yabai -m config top_padding    5
        yabai -m config bottom_padding 5
        yabai -m config left_padding   5
        yabai -m config right_padding  5

        # Name displays using display ID (more stable than index)
        yabai -m display 1 --label main # Built-in/Main display
        yabai -m display 2 --label top  # External display

        # Create and label spaces
        yabai -m space 1 --label code
        yabai -m space 2 --label docs
        yabai -m space 3 --label chat
        yabai -m space 4 --label social
        yabai -m space 5 --label other

        # sub-layer normal
        yabai -m rule --add app=".*" sub-layer=normal

        # South display rules
        yabai -m rule --add app="^Spotify$" display=south space=chat
        yabai -m rule --add app="^Joplin$" display=south space=docs
        yabai -m rule --add app="^Obsidian$" display=south space=docs
        yabai -m rule --add app="^Raycast$" display=south space=other

        # Set default split type
        yabai -m config split_type auto

        # Rules for unmanaged apps
        yabai -m rule --add app="^System Settings$" manage=off
        yabai -m rule --add app="^Calculator$" manage=off
        yabai -m rule --add app="^Karabiner-Elements$" manage=off
        yabai -m rule --add app="^QuickTime Player$" manage=off
        yabai -m rule --add app="^Finder$" manage=off
        yabai -m rule --add app="^Digital Color Meter$" manage=off
        yabai -m rule --add app="^Activity Monitor$" manage=off
        yabai -m rule --add app="^Path Finder$" manage=off
        yabai -m rule --add app="^1Password$" manage=off
        yabai -m rule --add app="^Raycast$" manage=off
        yabai -m rule --add app="^zoom.us$" title="^Zoom Meeting$" manage=off
        yabai -m rule --add app="^zoom.us$" title="^$" manage=off  # Control window
        yabai -m rule --add app="^Zoom$" manage=off
        yabai -m rule --add app="^us.zoom.xos$" manage=off
        yabai -m rule --add title="^Zoom Meeting$" manage=off
        yabai -m rule --add title="^Zoom$" manage=off

        # Event handlers
        yabai -m signal --add event=window_created action="yabai -m query --windows --window &> /dev/null || reposition_windows"
        yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
        yabai -m signal --add event=window_moved action="reposition_windows"
        yabai -m signal --add event=window_resized action="reposition_windows"
        yabai -m signal --add event=space_changed action="reposition_windows"
        yabai -m signal --add event=display_changed action="reposition_windows"
        yabai -m signal --add event=display_added action="reposition_windows"
        yabai -m signal --add event=display_removed action="reposition_windows"
        yabai -m signal --add event=window_focused action="reposition_windows"
        yabai -m signal --add event=window_destroyed action="reposition_windows"
        # Mission control events
        yabai -m signal --add event=mission_control_exit action='
          yabai -m config active_window_opacity 1.0
          reposition_windows
        '
        yabai -m signal --add event=mission_control_enter action='
          yabai -m config normal_window_opacity 1.0
          reposition_windows
        '
        # Combined rules for fixed size windows and window management
        yabai -m rule --add app="^Signal$" manage=off space=4 sticky=off opacity=1.0
        yabai -m rule --add app="^Warp$" manage=off space=4 sticky=off opacity=1.0
        yabai -m rule --add app="^Cursor$" manage=off space=4 sticky=off opacity=1.0
        yabai -m rule --add app="^YouTube$" manage=off space=4 sticky=off opacity=1.0
}
        function reposition_windows() {
            # First ensure all windows are on the right display and space
            windows=$(yabai -m query --windows)
            
            # Get window IDs regardless of current space/display
            signal_id=$(echo "$windows" | jq '.[] | select(.app=="Signal") | .id')
            warp_id=$(echo "$windows" | jq '.[] | select(.app=="Warp") | .id')
            cursor_id=$(echo "$windows" | jq '.[] | select(.app=="Cursor") | .id')
            youtube_id=$(echo "$windows" | jq '.[] | select(.app=="YouTube") | .id')

            if [ -n "$signal_id" ] && [ -n "$warp_id" ] && [ -n "$cursor_id" ] && [ -n "$youtube_id" ]; then
                echo "Found all windows, preparing to move..."
                
                # First ensure all windows are unmanaged
                for id in $signal_id $warp_id $cursor_id $youtube_id; do
                    # Check if window is managed
                    is_managed=$(yabai -m query --windows --window $id | jq '."is-floating" | not')
                    if [ "$is_managed" = "true" ]; then
                        yabai -m window $id --toggle float
                    fi
                done

                # Then move windows to correct display/space
                for id in $signal_id $warp_id $cursor_id $youtube_id; do
                    # First move to display 2
                    current_display=$(yabai -m query --windows --window $id | jq '.display')
                    if [ "$current_display" != "2" ]; then
                        yabai -m window $id --display 2
                    fi
                    # Then move to space 4
                    current_space=$(yabai -m query --windows --window $id | jq '.space')
                    if [ "$current_space" != "4" ]; then
                        yabai -m window $id --space 4
                    fi
                done

                # Wait a moment for windows to settle
                sleep 0.5
                
                # Get display dimensions for positioning
                display_info=$(yabai -m query --displays | jq '.[] | select(.index == 2)')
                display_width=$(echo "$display_info" | jq '.frame.w | floor')
                display_height=$(echo "$display_info" | jq '.frame.h | floor')
                display_x=$(echo "$display_info" | jq '.frame.x | floor')
                display_y=$(echo "$display_info" | jq '.frame.y | floor')
                
                # Calculate window positions and sizes
                left_width=$(( display_width / 5 ))
                middle_width=$(( display_width * 3 / 5 ))
                right_width=$(( display_width / 5 ))
                half_height=$(( display_height / 2 ))
                
                # Position Signal at top-left
                yabai -m window $signal_id --move abs:$((display_x)):$((display_y))
                yabai -m window $signal_id --resize abs:$left_width:$half_height

                # Position Warp below Signal
                yabai -m window $warp_id --move abs:$((display_x)):$((display_y + half_height))
                yabai -m window $warp_id --resize abs:$left_width:$half_height

                # Position Cursor in middle (larger space)
                yabai -m window $cursor_id --move abs:$((display_x + left_width)):$((display_y))
                yabai -m window $cursor_id --resize abs:$middle_width:$display_height

                # Position YouTube on right
                right_x=$((display_x + left_width + middle_width))
                yabai -m window $youtube_id --move abs:$right_x:$((display_y))
                yabai -m window $youtube_id --resize abs:$right_width:$display_height

                echo "Windows positioned successfully"
            else
                echo "Not all required windows found"
            fi
        }

        function draw_window_positions() {
            # Get all windows in space 4 on display 2 that aren't hidden
            windows=$(yabai -m query --windows | jq '[.[] | select(.space == 4 and .display == 2 and ."is-hidden" == false)]')
            
            # Create grids for both actual and desired layouts
            rows=10
            cols=40
            
            # Initialize actual grid
            declare -A actual_grid
            for ((i=0; i<rows; i++)); do
                for ((j=0; j<cols; j++)); do
                    actual_grid[$i,$j]=" "
                done
            done

            # Initialize desired grid
            declare -A desired_grid
            for ((i=0; i<rows; i++)); do
                for ((j=0; j<cols; j++)); do
                    desired_grid[$i,$j]=" "
                done
            done
            
            # Draw actual window positions
            local window_count=$(echo "$windows" | jq '. | length')
            for ((idx=0; idx<window_count; idx++)); do
                local window=$(echo "$windows" | jq ".[$idx]")
                local app=$(echo "$window" | jq -r '.app')
                local x=$(echo "$window" | jq -r '.frame.x | floor')
                local y=$(echo "$window" | jq -r '.frame.y | floor')
                local w=$(echo "$window" | jq -r '.frame.w | floor')
                local h=$(echo "$window" | jq -r '.frame.h | floor')
                
                # Debug the raw values
                echo "Debug: Raw $app: x=$x y=$y w=$w h=$h"
                
                # Scale to grid coordinates
                # Total width is about 5000 (-1696 to 3097)
                # Total height is about 1415 (-1410 to 5)
                local grid_x=$(( (x + 1696) * cols / 5000 ))
                local grid_y=$(( (y + 1410) * rows / 1415 ))
                local grid_w=$(( w * cols / 5000 ))
                local grid_h=$(( h * rows / 1415 ))
                
                echo "Debug: Scaled $app: x=$grid_x y=$grid_y w=$grid_w h=$grid_h"
                
                # Draw in actual grid
                draw_window actual_grid "$app" $grid_x $grid_y $grid_w $grid_h
            done
            
            # Draw desired layout
            draw_window desired_grid "Signal" 0 0 8 4
            draw_window desired_grid "Warp" 0 5 8 4
            draw_window desired_grid "Cursor" 9 0 22 9
            draw_window desired_grid "YouTube" 32 0 7 9
            
            # Draw both grids side by side
            echo "Actual Layout                                 Desired Layout"
            echo "┌$(printf '%*s' $((cols)) | tr ' ' '─')┐  ┌$(printf '%*s' $((cols)) | tr ' ' '─')┐"
            for ((i=0; i<rows; i++)); do
                echo -n "│"
                for ((j=0; j<cols; j++)); do
                    echo -n "${actual_grid[$i,$j]}"
                done
                echo -n "│  │"
                for ((j=0; j<cols; j++)); do
                    echo -n "${desired_grid[$i,$j]}"
                done
                echo "│"
            done
            echo "└$(printf '%*s' $((cols)) | tr ' ' '─')┘  └$(printf '%*s' $((cols)) | tr ' ' '─')┘"
        }

        # Helper function to draw a window in the specified grid
        draw_window() {
            local -n grid=$1  # Use nameref for array
            local name=$2
            local x=$3
            local y=$4
            local w=$5
            local h=$6
            
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
                        grid[$i,$j]="-"
                    elif ((j == x || j == x+w-1)); then
                        grid[$i,$j]="|"
                    else
                        grid[$i,$j]="."
                    fi
                done
            done

            # Add name in center if there's room
            if ((w >= ${#name} + 2 && h >= 3)); then
                local name_y=$((y + h/2))
                local name_x=$((x + (w-${#name})/2))
                for ((i=0; i<${#name} && name_x+i<cols; i++)); do
                    grid[$name_y,$((name_x+i))]="${name:$i:1}"
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

        # Add this near the end of the file, after the existing function calls
        #echo "Running the reposition_windows function"
        #reposition_windows
        #echo "Running the draw_window_positions function"
        #draw_window_positions
        #yabai -m config split_type horizontal  # Reset split type first
        #yabai -m config split_ratio 0.5        # Reset split ratio
        #echo "Testing managed window positioning..."
        #reposition_windows_managed
        echo "Running the draw_window_positions function"
        draw_window_positions
