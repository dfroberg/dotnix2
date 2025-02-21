-- Function to safely load Spoons
local function loadSpoon(spoonName, startAfterLoad)
    local status, spoon = pcall(function()
        return hs.loadSpoon(spoonName)
    end)
    
    if status and spoon then
        print(string.format("Successfully loaded Spoon: %s", spoonName))
        if startAfterLoad and spoon.start then
            spoon:start()
            print(string.format("Started Spoon: %s", spoonName))
        end
        return spoon
    else
        print(string.format("Failed to load Spoon: %s", spoonName))
        return nil
    end
end

-- Load required Spoons
Hyper = loadSpoon('Hyper')
if not Hyper then
    hs.alert.show("Critical: Hyper Spoon not available")
    return  -- Exit initialization if Hyper is not available
end

-- Load optional Spoons
loadSpoon('Headspace', true)
HyperModal = loadSpoon('HyperModal')
loadSpoon('Teamz', true)

-- Configure HyperModal
if HyperModal then
    HyperModal:start()
    -- Bind space as the activation key when Hyper is held
    Hyper:bind({}, 'space', function() HyperModal:toggle() end)
end

-- Load required extensions
local spaces = require("hs.spaces")
local window = require("hs.window")
local screen = require("hs.screen")
local brave = require('brave')
local fnutils = require("hs.fnutils")
local json = require("hs.json")
local task = require("hs.task")
local timer = require("hs.timer")
local notify = require("hs.notify")
local chooser = require("hs.chooser")
local urlevent = require("hs.urlevent")
local shortcuts = require("hs.shortcuts")
local fs = require("hs.fs")
local inspect = require("hs.inspect")
local alert = require("hs.alert")
local application = require("hs.application")
local audiodevice = require("hs.audiodevice")
local settings = require("hs.settings")
local window_filter = require("hs.window.filter")

-- Print startup message
print("\n=== Starting Hammerspoon configuration ===")

-- Enable Spotlight support for better app name matching
hs.application.enableSpotlightForNameSearches(true)

-- Check system permissions and requirements
if not hs.accessibilityState() then
    hs.alert.show("Please enable Accessibility for Hammerspoon")
    hs.open("/System/Library/PreferencePanes/Security.prefPane")
end

-- Check if Hammerspoon has screen recording permissions
if not hs.screen.primaryScreen() then
    hs.alert.show("Please enable Screen Recording for Hammerspoon")
    hs.open("/System/Library/PreferencePanes/Security.prefPane")
end

-- Check if yabai is installed and accessible
local yabai_check = hs.execute("/run/current-system/sw/bin/yabai -v")
if not yabai_check or yabai_check == "" then
    hs.alert.show("Yabai is not installed or not accessible")
end

-- Check if jq is installed (required for JSON parsing)
local jq_check = hs.execute("/run/current-system/sw/bin/jq --version")
if not jq_check or jq_check == "" then
    hs.alert.show("jq is not installed or not accessible")
end

-- Check if required Spoons are available
local required_spoons = {'Hyper', 'Headspace', 'HyperModal', 'Teamz'}
for _, spoon in ipairs(required_spoons) do
    if not hs.spoons.isLoaded(spoon) then
        hs.alert.show(string.format("Required Spoon '%s' is not available", spoon))
    end
end

-- Check number of displays and set global configuration
local screens = hs.screen.allScreens()
numScreens = #screens  -- Global variable for screen count
print("Number of screens detected:", numScreens)

-- Function to update standardPositions based on number of screens
local function updateStandardPositions()
    standardPositions = {
        -- External display (display 2) positions when in dual screen mode
        center = {x = 0.2, y = 0, w = 0.6, h = 1, display = numScreens > 1 and 2 or 1},
        center_left = {x = 0.2, y = 0, w = 0.3, h = 1, display = numScreens > 1 and 2 or 1},
        center_right = {x = 0.5, y = 0, w = 0.3, h = 1, display = numScreens > 1 and 2 or 1},
        top_right = {x = 0.8, y = 0, w = 0.2, h = 0.495, display = numScreens > 1 and 2 or 1},
        top_left = {x = 0, y = 0, w = 0.2, h = 0.495, display = numScreens > 1 and 2 or 1},
        bottom_right = {x = 0.8, y = 0.5, w = 0.2, h = 0.495, display = numScreens > 1 and 2 or 1},
        bottom_left = {x = 0, y = 0.5, w = 0.2, h = 0.495, display = numScreens > 1 and 2 or 1},
        
        -- Built-in display (display 1) positions
        main_center = {x = 0, y = 0, w = 1, h = 1, display = 1},
        main_left = {x = 0, y = 0, w = 0.5, h = 1, display = 1},
        main_right = {x = 0.5, y = 0, w = 0.5, h = 1, display = 1}
    }
    
    -- Print current screen configuration
    print("=== Screen Configuration Updated ===")
    print("Number of screens:", numScreens)
    print("Standard positions reconfigured for " .. (numScreens > 1 and "dual" or "single") .. " screen mode")
    print("================================")
end

-- Initialize standardPositions
updateStandardPositions()

-- Function to safely execute yabai command and get JSON output
function yabaiQuery(args)
    local cmd = "/run/current-system/sw/bin/yabai -m " .. table.concat(args, " ")
    print("Debug - Executing yabai command:", cmd)
    local output = hs.execute(cmd)
    
    if output and output ~= "" then
        local status, result = pcall(function() return hs.json.decode(output) end)
        if status then
            return result
        else
            print("Debug - Failed to parse JSON:", output)
            return nil
        end
    else
        print("Debug - No output from yabai command")
        return nil
    end
end

-- Function to execute yabai command and wait for completion
function yabaiSync(args)
    -- Build the command string
    local cmd = "/run/current-system/sw/bin/yabai -m " .. table.concat(args, " ")
    print("Debug - Executing yabai command:", cmd)
    
    -- Execute the command
    local output = hs.execute(cmd)
    local success = output ~= nil
    
    -- For query commands, try to parse JSON
    if success and args[1] == "query" then
        local status, result = pcall(function() return hs.json.decode(output) end)
        if status then
            return true, result
        else
            print("Debug - Failed to parse JSON:", output)
            return false, output
        end
    end
    
    return success, output
end

-- Function to focus a window by app name
local function focusWindowByApp(app_name)
  -- For Zoom, specifically target the main window
  if app_name == "zoom.us" then
      local cmd = "/run/current-system/sw/bin/yabai -m query --windows | " ..
                 "jq '.[] | select(.app==\"zoom.us\" and .title==\"Zoom Meeting\") | .id'"
      local window_id = hs.execute(cmd):gsub("%s+", "")
      print(string.format("%s window ID for focus:", app_name), window_id)
      if window_id and window_id ~= "" then
          yabaiSync({"window", window_id, "--focus"})
      end
      return
  end

  -- For PWAs and other apps, use the same logic as buildWindowQuery
  local cmd = string.format(
      "/run/current-system/sw/bin/yabai -m query --windows | " ..
      "jq '.[] | select(" ..
      "(.app==\"%s\") or " ..  -- Direct app name match
      "(.app==\"app_mode_loader\" and (.title | ascii_downcase | contains(\"%s\" | ascii_downcase))) or " ..
      "(.app==\"Google Chrome\" and (.title | ascii_downcase | contains(\"%s\" | ascii_downcase))) or " ..
      "(.app==\"Brave Browser\" and (.title | ascii_downcase | contains(\"%s\" | ascii_downcase)))" ..
      ") | .id'",
      app_name, app_name, app_name, app_name
  )
  local window_id = hs.execute(cmd):gsub("%s+", "")
  print(string.format("%s window ID for focus:", app_name), window_id)
  if window_id and window_id ~= "" then
      yabaiSync({"window", window_id, "--focus"})
  end
end

-- Screen watcher to handle display changes
local screenWatcher = hs.screen.watcher.new(function()
    local screens = hs.screen.allScreens()
    local newScreenCount = #screens
    
    if newScreenCount ~= numScreens then
        -- Store old screen count for comparison
        local oldScreenCount = numScreens
        numScreens = newScreenCount
        
        -- Update window management configuration
        updateStandardPositions()
        
        -- Get detailed screen information
        local screenInfo = {}
        for i, screen in ipairs(screens) do
            table.insert(screenInfo, string.format(
                "Display %d: %s (%dx%d)", 
                i,
                screen:name(),
                screen:frame().w,
                screen:frame().h
            ))
        end
        
        -- Print detailed debug information
        print("\n=== Display Configuration Change ===")
        print(string.format("Screens changed: %d -> %d", oldScreenCount, newScreenCount))
        print("Current displays:")
        for _, info in ipairs(screenInfo) do
            print("  " .. info)
        end
        print("===================================\n")
        
        -- Show user notification with more detail
        hs.alert.show(string.format(
            "Display %s: %d screen%s\n%s",
            newScreenCount > oldScreenCount and "connected" or "disconnected",
            newScreenCount,
            newScreenCount > 1 and "s" or "",
            table.concat(screenInfo, "\n")
        ))
        
        -- Wait a moment for displays to settle
        hs.timer.doAfter(0.5, function()
            -- Get yabai display configuration
            local displays = yabaiQuery({"query", "--displays"})
            if displays then
                print("Yabai display configuration:", hs.inspect(displays))
                
                -- Focus the appropriate display based on connection/disconnection
                local targetDisplay = newScreenCount
                if newScreenCount < oldScreenCount then
                    -- On disconnect, focus the primary display
                    targetDisplay = 1
                end
                
                -- Force a yabai display update
                local yabai_cmd = "/run/current-system/sw/bin/yabai -m display --focus " .. targetDisplay
                hs.execute(yabai_cmd)
                
                -- Update spaces configuration
                for _, display in ipairs(displays) do
                    -- Print spaces info for each display
                    print(string.format("Display %d spaces: %s", 
                        display.index, 
                        hs.inspect(display.spaces)
                    ))
                    
                    -- If this is the target display, focus its first space
                    if display.index == targetDisplay then
                        local firstSpace = display.spaces[1]
                        if firstSpace then
                            print(string.format("Focusing space %d on display %d", 
                                firstSpace, targetDisplay))
                            hs.timer.doAfter(0.2, function()
                                yabaiSync({"space", "--focus", tostring(firstSpace)})
                            end)
                        end
                    end
                end
                
                -- Reflow windows if needed
                if newScreenCount > oldScreenCount then
                    -- When connecting a display, reflow windows after a delay
                    hs.timer.doAfter(1, function()
                        yabaiSync({"space", "--balance"})
                    end)
                end
            end
        end)
    end
end)
screenWatcher:start()

-- Print initial screen configuration
print("\n=== Initial Screen Configuration ===")
local screens = hs.screen.allScreens()
print("Number of screens:", #screens)
for i, screen in ipairs(screens) do
    print(string.format(
        "Display %d: %s (%dx%d)", 
        i,
        screen:name(),
        screen:frame().w,
        screen:frame().h
    ))
end
print("\n==================================\n")

-- Check if we can access required directories
local config_dir = ".config/hammerspoon"
if not hs.fs.attributes(config_dir) then
    hs.alert.show(string.format("Cannot access configuration directory: %s", config_dir))
end

-- Test yabai communication
local yabai_test = hs.execute("/run/current-system/sw/bin/yabai -m query --displays")
if not yabai_test or yabai_test == "" then
    hs.alert.show("Cannot communicate with yabai service")
end

-- Print system information for debugging
print("\n=== System Information ===")
print("Hammerspoon Version:", hs.processInfo.version)
print("macOS Version:", hs.host.operatingSystemVersion())
print("Displays:", #screens)
print("Primary Display:", hs.screen.primaryScreen():name())
print("\n=========================\n")

-- Init Hyper
Hyper:bindHotKeys({hyperKey = {{}, 'F19'}})

-- Load configuration files
package.path = os.getenv("HOME") .. "/.config/hammerspoon/?.lua;" .. package.path
Config = {}
Config.applications = require('apps')
Config.tags = require('tags')
Config.positions = require('positions')

local apps = Config.applications
local tags = Config.tags
local positionTransitions = Config.positions

-- Debug function to print spaces info
local function printSpacesInfo()
    local allSpaces = hs.spaces.allSpaces()
    print("All spaces:", hs.inspect(allSpaces))
    local mainScreen = hs.screen.mainScreen()
    if mainScreen then
        print("Main screen ID:", mainScreen:getUUID())
        local screenSpaces = allSpaces[mainScreen:getUUID()]
        if screenSpaces then
            print("Spaces on main screen:", hs.inspect(screenSpaces))
        else
            print("No spaces found for main screen")
        end
    else
        print("No main screen found")
    end
end

-- Print spaces info on startup
printSpacesInfo()

-- provide the ability to override config per computer
if (hs.fs.displayName('./localConfig.lua')) then
  require('localConfig')
end

-- https://github.com/dmitriiminaev/Hammerspoon-HyperModal/blob/master/.hammerspoon/yabai.lua
local yabai = function(args, completion)
  local yabai_output = ""
  local yabai_error  = ""
  -- Runs in background very fast
  local yabai_task = hs.task.new("/run/current-system/sw/bin/yabai", function(err, stdout, stderr)
    print()
  end, function(task, stdout, stderr)
      -- print("stdout:"..stdout, "stderr:"..stderr)
      if stdout ~= nil then
        yabai_output = yabai_output .. stdout
      end
      if stderr ~= nil then
        yabai_error = yabai_error .. stderr
      end
      return true
    end, args)
  if type(completion) == "function" then
    yabai_task:setCallback(function()
      completion(yabai_output, yabai_error/run/current-system/sw/bin/yabai)
    end)
  end
  yabai_task:start()
end

-- Function to get space ID from index
local function getSpaceIDForIndex(screenSpaces, index)
    -- Get all spaces from yabai
    local output, status = hs.execute("/run/current-system/sw/bin/yabai -m query --spaces")
    if status and output then
        local spaces = hs.json.decode(output)
        -- Find space with matching index
        for _, space in ipairs(spaces) do
            if space.index == index then
                return space.index
            end
        end
    end
    return nil
end

-- Function to get window ID for Chrome PWAs and regular apps
local function getWindowID(appName)
    -- Get all windows from yabai
    local output, status = hs.execute("/run/current-system/sw/bin/yabai -m query --windows")
    if status and output then
        local windows = hs.json.decode(output)
        for _, window in ipairs(windows) do
            -- Check both app name and title for matches
            if window.app == appName or window.title:match(appName) then
                return window.id
            end
        end
    end
    return nil
end

-- Function to build window query for an app
local function buildWindowQuery(app_config)
    local app_name = app_config.app
    
    -- Handle Zoom's special case
    if app_name == "zoom.us" then
        return "/run/current-system/sw/bin/yabai -m query --windows | " ..
               "jq '.[] | select(.app==\"zoom.us\" and .title==\"Zoom Meeting\") | .id'"
    end
    
    -- Handle PWAs
    if app_config.isPWA then
        -- For PWAs, we need to check both:
        -- 1. Direct app name match (for PWA windows)
        -- 2. Title contains for Chrome/Brave windows (fallback)
        local query = string.format(
            "/run/current-system/sw/bin/yabai -m query --windows | " ..
            "jq '.[] | select(" ..
            "(.app==\"%s\") or " ..  -- Direct app name match
            "(.app==\"app_mode_loader\" and (.title | ascii_downcase | contains(\"%s\" | ascii_downcase))) or " ..
            "(.app==\"Google Chrome\" and (.title | ascii_downcase | contains(\"%s\" | ascii_downcase))) or " ..
            "(.app==\"Brave Browser\" and (.title | ascii_downcase | contains(\"%s\" | ascii_downcase)))" ..
            ") | .id'",
            app_name, app_name, app_name, app_name
        )
        print("Debug - Full PWA query:", query)
        -- Also print all windows for debugging
        local all_windows = hs.execute("/run/current-system/sw/bin/yabai -m query --windows")
        print("Debug - All windows:", all_windows)
        return query
    elseif app_config.title then
        -- Special case for windows with specific titles
        return string.format(
            "/run/current-system/sw/bin/yabai -m query --windows | " ..
            "jq '.[] | select(.app==\"%s\" and (.title | contains(\"%s\"))) | .id'",
            app_config.app, app_config.title
        )
    else
        -- Regular apps
        local query = string.format(
            "/run/current-system/sw/bin/yabai -m query --windows | " ..
            "jq '.[] | select(.app==\"%s\") | .id'",
            app_config.app
        )
        print("Debug - Full query:", query)
        return query
    end
end

-- Function to focus window using multiple methods
local function focusWindow(window_id, app_config, abs_x, abs_y, abs_w, abs_h)
  print("Attempting to focus window...")
  
  -- Method 1: Try yabai focus
  hs.execute(string.format("/run/current-system/sw/bin/yabai -m window %s --focus", window_id))
  hs.timer.usleep(100000)  -- Wait 100ms
  
  -- Method 2: Try to find the window in Hammerspoon using the app and frame
  local all_windows = hs.window.allWindows()
  local target_window = nil
  
  -- First try exact title match
  for _, win in ipairs(all_windows) do
      if win:application():name() == app_config.app and
         (not app_config.title or win:title():match(app_config.title)) then
          target_window = win
          break
      end
  end
  
  -- If no exact match, try frame-based matching
  if not target_window then
      for _, win in ipairs(all_windows) do
          if win:application():name() == app_config.app then
              local win_frame = win:frame()
              -- Use approximate matching with larger tolerance
              if math.abs(win_frame.x - abs_x) < 20 and
                 math.abs(win_frame.y - abs_y) < 20 and
                 math.abs(win_frame.w - abs_w) < 20 and
                 math.abs(win_frame.h - abs_h) < 20 then
                  target_window = win
                  break
              end
          end
      end
  end
  
  if target_window then
      print("Found matching window in Hammerspoon, focusing...")
      target_window:focus()
      -- Ensure window is at front
      target_window:raise()
  else
      print("Could not find exact window match, trying app activation...")
      -- Method 3: Fallback to app activation
      local app = hs.application.find(app_config.app)
      if app then
          app:activate()
          -- Try to bring window to front with delay
          hs.timer.doAfter(0.2, function()
              local front_window = app:focusedWindow()
              if front_window then
                  front_window:focus()
                  front_window:raise()
              end
          end)
      end
  end
end

-- Function to move window using both Hammerspoon and yabai
local function moveWindowToSpace(win, targetSpace)
    -- Get window ID using the new helper function
    local winID = win:id()
    local appName = win:application():name()
    local yabaiID = getWindowID(appName)
    
    if yabaiID then
        -- Move window with yabai using space index
        yabaiSync({"window", tostring(yabaiID), "--space", tostring(targetSpace)})
        
        -- Then move with Hammerspoon
        hs.spaces.moveWindowToSpace(winID, targetSpace)
        
        -- Finally, focus the space
        hs.spaces.gotoSpace(targetSpace)
    end
end

-- Function to focus space using both Hammerspoon and yabai
local function focusSpace(targetSpace)
    -- Focus with yabai using space index
    yabaiSync({"space", "--focus", tostring(targetSpace)})
    
    -- Then focus with Hammerspoon
    hs.spaces.gotoSpace(targetSpace)
end

-- Function to move and resize a window using yabai with Hammerspoon fallback
local function moveAndResizeWindow(app_config, x, y, w, h, display_num)
  -- Ensure we have a valid display number
  display_num = display_num or 2  -- Default to external display if not specified
  print(string.format("Moving window for app '%s' to display %d", app_config.app, display_num))

  -- Try to launch the app if it's not running
  local app = hs.application.find(app_config.app)
  if not app then
      print("App not running, attempting to launch:", app_config.app)
      app = hs.application.open(app_config.app)
      
      -- For PWAs, we need to wait longer and ensure the window is floating
      if app_config.isPWA then
          print("Launching PWA, waiting for window initialization...")
          -- Wait for app to launch and create its window
          if app then
              local max_attempts = 30  -- Increased attempts for PWAs
              local attempts = 0
              while attempts < max_attempts do
                  local win = app:mainWindow()
                  if win then break end
                  hs.timer.usleep(500000)  -- Wait 0.5 seconds
                  attempts = attempts + 1
              end
              hs.timer.usleep(1500000)  -- Wait 1.5 seconds for PWA window to fully initialize
              
              -- Force the window to float immediately after creation
              local query_cmd = buildWindowQuery(app_config)
              local window_id = hs.execute(query_cmd):gsub("%s+", "")
              if window_id and window_id ~= "" then
                  print("Making PWA window floating...")
                  yabaiSync({"window", window_id, "--toggle", "float"})
                  hs.timer.usleep(200000)  -- Wait for float operation
              end
          end
      else
          -- For regular apps, use standard wait times
          if app then
              local max_attempts = 20
              local attempts = 0
              while attempts < max_attempts do
                  local win = app:mainWindow()
                  if win then break end
                  hs.timer.usleep(500000)  -- Wait 0.5 seconds
                  attempts = attempts + 1
              end
              hs.timer.usleep(1000000)  -- Wait 1 second
          end
      end
  end

  -- Print app info if found
  if app then
      print(string.format("Found app: name='%s', bundleID='%s'", app:name(), app:bundleID()))
  end

  local query_cmd = buildWindowQuery(app_config)
  print("Query command:", query_cmd)
  local window_id = hs.execute(query_cmd):gsub("%s+", "")
  print("Window ID:", window_id)
  
  -- Try yabai first
  if window_id and window_id ~= "" then
      -- First get all windows to find our target window
      local windows = yabaiQuery({"query", "--windows"})
      if not windows then
          print("Failed to get windows list from yabai")
          return
      end
      
      -- Find our window in the list
      local window_info = nil
      for _, win in ipairs(windows) do
          if tostring(win.id) == window_id then
              window_info = win
              break
          end
      end
      
      if window_info then
          print("Debug - Found window info:", hs.inspect(window_info))
          
          -- For PWAs, always ensure the window is floating
          if app_config.isPWA and not window_info["is-floating"] then
              print("PWA window is not floating, making it float")
              yabaiSync({"window", window_id, "--toggle", "float"})
              hs.timer.usleep(200000)  -- Wait for float operation
          -- For non-PWAs, check if we need to make it floating
          elseif not window_info["is-floating"] and (not window_info["can-move"] or not window_info["can-resize"]) then
              print("Window is managed but can't move/resize - forcing float")
              yabaiSync({"window", window_id, "--toggle", "float"})
              hs.timer.usleep(200000)  -- Wait for float operation
          end

          -- Check if window is already on the target display
          if window_info.display == display_num then
              print(string.format("Window already on display %d, skipping move", display_num))
          else
              -- Move to target display
              print("Moving to display:", display_num)
              yabaiSync({"window", window_id, "--display", tostring(display_num)})
              hs.timer.usleep(300000)  -- Wait for move operation
          end
          
          -- Get display dimensions
          local displays = yabaiQuery({"query", "--displays"})
          if displays then
              local target_display = nil
              for _, d in ipairs(displays) do
                  if d.index == display_num then
                      target_display = d
                      break
                  end
              end
              
              if target_display then
                  -- Calculate absolute positions based on display frame
                  local frame = target_display.frame
                  local abs_x = math.floor(frame.x + (frame.w * x))
                  local abs_y = math.floor(frame.y + (frame.h * y))
                  local abs_w = math.floor(frame.w * w)
                  local abs_h = math.floor(frame.h * h)
                  
                  print(string.format("Resizing window to: x=%d, y=%d, w=%d, h=%d", 
                      abs_x, abs_y, abs_w, abs_h))
                  
                  -- Move and resize with increased delays for PWAs
                  yabaiSync({"window", window_id, "--move", string.format("abs:%d:%d", abs_x, abs_y)})
                  hs.timer.usleep(app_config.isPWA and 100000 or 50000)  -- Longer wait for PWAs
                  yabaiSync({"window", window_id, "--resize", string.format("abs:%d:%d", abs_w, abs_h)})
                  
                  -- Focus the window
                  focusWindow(window_id, app_config, abs_x, abs_y, abs_w, abs_h)
              end
          end
      else
          print("Failed to find window info in windows list")
      end
  else
      print("No window ID found for app:", app_config.app)
  end
end

-- Function to ensure window is unmanaged and floating
local function ensureWindowUnmanagedAndFloating(win)
  if not win then return end
  local app = win:application()
  if not app then return end
  
  -- Get window ID from yabai
  local cmd = string.format(
      "/run/current-system/sw/bin/yabai -m query --windows | " ..
      "jq '.[] | select(.app==\"%s\" and .title==\"%s\") | .id'",
      app:name(), win:title():gsub('"', '\\"')
  )
  local window_id = hs.execute(cmd):gsub("%s+", "")
  
  if window_id and window_id ~= "" then
      -- Check if window is already floating
      local check_cmd = string.format("/run/current-system/sw/bin/yabai -m query --windows | jq '.[] | select(.id==%s) | .\"is-floating\"'", window_id)
      local is_floating = hs.execute(check_cmd):gsub("%s+", "")
      
      if is_floating == "false" then
          print("Window is not floating, making it float")
          -- Make the window float (not toggle)
          yabaiSync({"window", window_id, "--toggle", "float"})
          -- Wait for the operation to complete
          hs.timer.usleep(200000)
          
          -- Verify floating state
          local verify_cmd = string.format("/run/current-system/sw/bin/yabai -m query --windows | jq '.[] | select(.id==%s) | .\"is-floating\"'", window_id)
          local verify_floating = hs.execute(verify_cmd):gsub("%s+", "")
          if verify_floating == "false" then
              print("Warning: Failed to make window float, trying alternative method")
              -- Try alternative method
              win:setFullScreen(false)
              hs.timer.usleep(100000)
              yabaiSync({"window", window_id, "--toggle", "float"})
              hs.timer.usleep(100000)
          end
      else
          print("Window is already floating")
      end
  end
end

-- Function to get current window position
local function getCurrentPosition(win)
  local frame = win:frame()
  local screen = win:screen()
  local screenFrame = screen:frame()
  
  -- Determine screen index by comparing with all screens
  local screenIndex = 1  -- Default to main display
  local allScreens = hs.screen.allScreens()
  for i, s in ipairs(allScreens) do
      if screen:id() == s:id() then
          screenIndex = i
          break
      end
  end
  
  -- Get window info from yabai for more accurate state
  local app = win:application()
  if app then
      local cmd = string.format(
          "/run/current-system/sw/bin/yabai -m query --windows | " ..
          "jq '.[] | select(.app==\"%s\" and .title==\"%s\")'",
          app:name(), win:title():gsub('"', '\\"')
      )
      local output = hs.execute(cmd)
      if output and output ~= "" then
          local status, window_info = pcall(function() return hs.json.decode(output) end)
          if status and window_info then
              -- Use yabai's frame information
              frame = window_info.frame
              screenFrame = {
                  x = 0,
                  y = 0,
                  w = screen:frame().w,
                  h = screen:frame().h
              }
          else
              print("Failed to parse window info JSON:", output)
          end
      end
  end
  
  -- Convert absolute coordinates to relative
  local relX = (frame.x - screenFrame.x) / screenFrame.w
  local relY = (frame.y - screenFrame.y) / screenFrame.h
  local relW = frame.w / screenFrame.w
  local relH = frame.h / screenFrame.h
  
  -- Add debug output
  print(string.format("Window position - x: %.3f, y: %.3f, w: %.3f, h: %.3f, screen: %d", 
      relX, relY, relW, relH, screenIndex))
  
  -- Find matching standard position with increased tolerance
  for pos_name, pos in pairs(standardPositions) do
      -- Check if position matches current display
      if pos.display == screenIndex then
          -- Use larger tolerance for position matching
          if math.abs(pos.x - relX) < 0.1 and
             math.abs(pos.y - relY) < 0.1 and
             math.abs(pos.w - relW) < 0.1 and
             math.abs(pos.h - relH) < 0.1 then
              print("Matched position:", pos_name)
              return pos_name
          end
      end
  end
  
  -- If no match found, return default based on current display
  if screenIndex == 1 then
      return "main_center"
  else
      return "center"
  end
end

-- Function to move window in specified direction
local function moveWindowInDirection(direction)
  print("moveWindowInDirection called with direction:", direction)
  local win = hs.window.focusedWindow()
  if win then
      print("Found focused window:", win:title())
      -- Ensure window is unmanaged and floating before moving
      ensureWindowUnmanagedAndFloating(win)
      
      local currentPos = getCurrentPosition(win)
      print("Current position:", currentPos)
      local nextPos = positionTransitions[direction] and positionTransitions[direction][currentPos]
      print("Next position:", nextPos)
      
      if nextPos then
          local pos = standardPositions[nextPos]
          if pos then
              print(string.format("Moving from %s to %s on display %d", 
                  currentPos, nextPos, pos.display))
              
              local app_config = {
                  app = win:application():name(),
                  title = win:title()
              }
              moveAndResizeWindow(app_config, pos.x, pos.y, pos.w, pos.h, pos.display)
          end
      end
  else
      print("No focused window found")
  end
end

-- Function to position currently focused window in a standard position
local function positionCurrentWindow(position)
  local win = hs.window.focusedWindow()
  if win then
    -- Ensure window is unmanaged and floating before positioning
    ensureWindowUnmanagedAndFloating(win)
    
    local app_config = {
      app = win:application():name(),
      title = win:title()
    }
    local pos = standardPositions[position]
    moveAndResizeWindow(app_config, pos.x, pos.y, pos.w, pos.h, pos.display)
  end
end

-- Space Navigation
for i = 1, 6 do
    -- Focus space
    Hyper:bind({}, tostring(i), function()
        if not hs.accessibilityState() then
            hs.alert.show("Please enable Accessibility for Hammerspoon")
            return
        end
        local spaces = hs.spaces.allSpaces()
        local screen = hs.screen.mainScreen()
        print("Focusing space " .. i)
        print("All spaces:", hs.inspect(spaces))
        if not screen then 
            print("No screen found")
            return 
        end
        print("Screen ID:", screen:getUUID())
        local screenSpaces = spaces[screen:getUUID()]
        if not screenSpaces then 
            print("No spaces found for screen")
            return 
        end
        print("Screen spaces:", hs.inspect(screenSpaces))
        local targetSpace = getSpaceIDForIndex(screenSpaces, i)
        if targetSpace then
            print("Moving to space " .. targetSpace)
            focusSpace(targetSpace)
        else
            print("No space found at index " .. i)
        end
    end)
    
    -- Move window to space and follow
    Hyper:bind({"shift"}, tostring(i), function()
        local win = hs.window.focusedWindow()
        print("Moving window to space " .. i)
        if not win then
            print("No focused window")
            return
        end
        local spaces = hs.spaces.allSpaces()
        local screen = hs.screen.mainScreen()
        if not screen then 
            print("No screen found")
            return 
        end
        local screenSpaces = spaces[screen:getUUID()]
        if not screenSpaces then 
            print("No spaces found for screen")
            return 
        end
        local targetSpace = getSpaceIDForIndex(screenSpaces, i)
        if targetSpace then
            print("Moving window " .. win:id() .. " to space " .. targetSpace)
            moveWindowToSpace(win, targetSpace)
        else
            print("No space found at index " .. i)
        end
    end)
end

-- Quick space navigation
-- Focus recent space: Hyper + tab
Hyper:bind({}, "tab", function() 
    local spaces = hs.spaces.allSpaces()
    local screen = hs.screen.mainScreen()
    if not screen then return end
    local screenSpaces = spaces[screen:getUUID()]
    if not screenSpaces then return end
    -- Get current space index
    local currentSpace = hs.spaces.focusedSpace()
    local currentIndex = hs.fnutils.indexOf(screenSpaces, currentSpace)
    -- Go to previous space if available
    if currentIndex and currentIndex > 1 then
        hs.spaces.gotoSpace(screenSpaces[currentIndex - 1])
    end
end)

-- Focus previous space: Hyper + [
Hyper:bind({}, "[", function()
    local spaces = hs.spaces.allSpaces()
    local screen = hs.screen.mainScreen()
    if not screen then return end
    local screenSpaces = spaces[screen:getUUID()]
    if not screenSpaces then return end
    local currentSpace = hs.spaces.focusedSpace()
    local currentIndex = hs.fnutils.indexOf(screenSpaces, currentSpace)
    if currentIndex and currentIndex > 1 then
        hs.spaces.gotoSpace(screenSpaces[currentIndex - 1])
    end
end)

-- Focus next space: Hyper + ]
Hyper:bind({}, "]", function()
    local spaces = hs.spaces.allSpaces()
    local screen = hs.screen.mainScreen()
    if not screen then return end
    local screenSpaces = spaces[screen:getUUID()]
    if not screenSpaces then return end
    local currentSpace = hs.spaces.focusedSpace()
    local currentIndex = hs.fnutils.indexOf(screenSpaces, currentSpace)
    if currentIndex and currentIndex < #screenSpaces then
        hs.spaces.gotoSpace(screenSpaces[currentIndex + 1])
    end
end)

-- Space management
-- Create space: Hyper + Shift + n
Hyper:bind({"shift"}, "n", function() yabai({"-m", "space", "--create"}) end)
-- Destroy space: Hyper + Shift + d
Hyper:bind({"shift"}, "d", function() yabai({"-m", "space", "--destroy"}) end)

-- Add reload config binding
-- Reload hammerspoon config: Hyper + R
Hyper:bind({"shift"}, "r", function()
  hs.reload()
end)

-- Random bindings
local chooseFromGroup = function(choice)
  if not choice then return end
  
  -- Check if the bundleID is actually a URL
  -- More precise URL detection: must contain a dot and not be a known bundle ID pattern
  local isUrl = choice.isUrl
  if isUrl then
    -- It's a URL, use jumpOrOpen
    print(string.format("Debug - Opening URL: %s", choice.bundleID))
    jumpOrOpen(choice.bundleID)
    return
  end
  
  -- Find the corresponding app configuration
  local app_config = nil
  for _, app in ipairs(apps) do
      if app.bundleID == choice.bundleID or app.app == choice.bundleID then
          app_config = app
          break
      end
  end
  
  -- if isPWA we don't use a bundle id but launch the app
  local isPWA = choice.isPWA
  if isPWA and app_config then
    -- It's a PWA
    print(string.format("Hyper triggered for PWA: %s", app_config.app))
    local pos = standardPositions[choice.position]
    moveAndResizeWindow(app_config, pos.x, pos.y, pos.w, pos.h, pos.display)
    focusWindowByApp(app_config.app)
    
    -- Save the choice
    hs.settings.set("hyperGroup." .. choice.group_name .. "." .. choice.key, choice.bundleID)
    return
  end
  
  -- Handle regular bundle IDs
  local name = hs.application.nameForBundleID(choice.bundleID)
  print(string.format("Debug - Bundle ID: %s, Name: %s", choice.bundleID, name or "nil"))
  
  -- Use bundleID as fallback name if nameForBundleID returns nil
  name = name or choice.bundleID
  
  -- Get position from app_config or choice
  local position = app_config and app_config.position or choice.position
  if position then
    -- Create app config for positioning
    local app_config_for_move = {
      app = name,
      bundleID = choice.bundleID,
      position = position
    }
    
    -- Launch/focus the app and position it
    local app = hs.application.launchOrFocusByBundleID(choice.bundleID)
    if app then
      -- Wait briefly for the window to be available
      hs.timer.doAfter(0.5, function()
        local pos = standardPositions[position]
        print(string.format("Moving %s to position %s", name, position))
        moveAndResizeWindow(app_config_for_move, pos.x, pos.y, pos.w, pos.h, pos.display)
      end)
    end
  else
    -- Just launch/focus without positioning
    hs.application.launchOrFocusByBundleID(choice.bundleID)
  end

  hs.notify.new(nil)
  :title("Switching " .. choice.group_name .. "-" .. choice.key .. " to " .. name)
  :contentImage(hs.image.imageFromAppBundle(choice.bundleID))
  :send()

  hs.settings.set("hyperGroup." .. choice.group_name .. "." .. choice.key, choice.bundleID)
end

local hyperGroup = function(key, group, options)
    options = options or {}
    local group_name = options.name or "✦"
    local trigger_mods = options.trigger_mods or {}
    local trigger_key = options.trigger_key
    local position = options.position
    local modal = nil
    
    if trigger_key then
        -- Create a modal mode
        modal = hs.hotkey.modal.new()
        
        -- Show which mode we're in
        modal.entered = function()
            hs.alert.show(group_name .. " mode active", 1)
            
            -- Show choices immediately when entering modal mode
            print("Setting options for " .. group_name .. "...")
            local choices = {}
            hs.fnutils.each(group, function(identifier)
                -- Find the corresponding app configuration
                local app_config = nil
                for _, app in ipairs(apps) do
                    if app.bundleID == identifier or app.app == identifier then
                        app_config = app
                        break
                    end
                end
                
                -- Skip if no app config found
                if not app_config then
                    print(string.format("Warning: No app configuration found for identifier: %s", identifier))
                    return
                end
                
                -- Determine if this is a PWA or URL
                local isPWA = app_config.isPWA
                local isUrl = app_config.isUrl
                
                local name, image
                if isPWA then
                    -- For PWAs, use the app name directly
                    name = app_config.app
                    -- No image for PWAs currently
                    image = nil
                elseif isUrl then
                    -- For URLs, use the URL as the name
                    name = identifier
                    image = nil
                else
                    -- For regular apps, try to get name from bundle ID
                    name = app_config.bundleID and hs.application.nameForBundleID(app_config.bundleID)
                    if not name then
                        -- Fallback to app name from config
                        name = app_config.app
                    end
                    -- Try to get app icon
                    image = app_config.bundleID and hs.image.imageFromAppBundle(app_config.bundleID)
                end
                
                print(string.format("Debug - Processing %s: %s, Name: %s", 
                    isPWA and "PWA" or isUrl and "URL" or "Bundle ID",
                    identifier, 
                    name or "nil"))
                
                -- Use app name as fallback if name is still nil
                name = name or app_config.app
                
                -- Create the choice entry
                local choice = {
                    text = name,
                    subText = isPWA and app_config.app or identifier,  -- Show app name for PWAs, identifier for others
                    image = image,
                    bundleID = identifier,  -- Keep original identifier
                    key = key,
                    group_name = group_name,
                    position = position or app_config.position,  -- Use group position or app-specific position
                    hotkey = name:sub(1,1):lower(),  -- Use first letter as hotkey
                    isPWA = isPWA,  -- Include PWA status
                    app = app_config.app  -- Include app name for PWAs
                }
                
                -- Add hotkey to subText
                choice.subText = string.format("[%s] %s%s", 
                    choice.hotkey, 
                    choice.subText,
                    isPWA and " (PWA)" or ""
                )
                
                table.insert(choices, choice)
            end)

            if #choices == 1 then
                chooseFromGroup(choices[1])
                modal:exit()
            else
                local chooser = hs.chooser.new(function(choice)
                    if choice then
                        chooseFromGroup(choice)
                    end
                    modal:exit()
                end)
                
                chooser
                    :placeholderText("Choose an application for " .. group_name .. "+" .. key .. ":")
                    :choices(choices)
                    :show()
            end
        end
        
        modal.exited = function()
            hs.alert.closeAll()
        end
        
        -- Allow escape to exit mode
        modal:bind({}, 'escape', function() modal:exit() end)
        
        -- Bind the activation through Hyper
        Hyper:bind(trigger_mods, trigger_key, function()
            modal:enter()
        end)
    end
    
    -- Bind the direct hotkey if no modal
    if not modal then
        Hyper:bind({}, key, nil, function()
            local savedChoice = hs.settings.get("hyperGroup." .. group_name .. "." .. key)
            if savedChoice then
                chooseFromGroup({
                    bundleID = savedChoice,
                    key = key,
                    group_name = group_name,
                    position = position  -- Include position if specified
                })
            end
        end)
    end
    
    return modal
end

-- Function to create hyperGroups based on tags
local function createHyperGroups()
    -- Create a table to store apps by tag
    local appsByTag = {}
    
    -- Group apps by their tags
    for _, app in ipairs(apps) do
        if app.tags then
            for _, tag in ipairs(app.tags) do
                if not appsByTag[tag] then
                    appsByTag[tag] = {}
                end
                -- For browsers and PWAs, use bundleID or app name
                local identifier = app.bundleID or app.app
                table.insert(appsByTag[tag], identifier)
            end
        end
    end
    
    -- Create hyperGroups for each tag
    for tag, taggedApps in pairs(appsByTag) do
        local tagConfig = tags[tag]
        if tagConfig then
            print(string.format("Creating hyperGroup for tag: %s with %d apps", tag, #taggedApps))
            hyperGroup(tagConfig.trigger_key, taggedApps, {
                name = tagConfig.name,
                trigger_mods = tagConfig.trigger_mods,
                trigger_key = tagConfig.trigger_key,
                position = tagConfig.position
            })
        end
    end
end

-- Create all hyperGroups based on tags
createHyperGroups()

-- Jump to url used by hypergroup urls
jumpOrOpen = function(url)
  if brave.jump(url) then
    return true
  else
    hs.urlevent.openURL("https://" .. url)
  end
end

require('browserSnip')

-- change audio settings based on output
hs.audiodevice.watcher.setCallback(function(event)
  if event == "dOut" then
    local name = hs.audiodevice.defaultOutputDevice():name()
    if name == "WH-1000XM4" then
      hs.shortcuts.run("XM4")
    end
    if name == "MacBook Pro Speakers" then
      hs.shortcuts.run("Macbook Pro Speakers")
    end
  end
end)
hs.audiodevice.watcher.start()

-- Add this helper function
local function printAllWindows()
  -- Print Hammerspoon window info
  local windows = hs.window.allWindows()
  print("\nHammerspoon windows:")
  for _, win in ipairs(windows) do
      local app = win:application()
      local frame = win:frame()
      print(string.format("App: '%s', Title: '%s', Bundle ID: '%s', Frame: x=%.0f,y=%.0f,w=%.0f,h=%.0f", 
          app:name(), win:title(), app:bundleID(), frame.x, frame.y, frame.w, frame.h))
  end
  
  -- Print yabai window info
  print("\nYabai windows:")
  local output = hs.execute("/run/current-system/sw/bin/yabai -m query --windows")
  local windows_info = hs.json.decode(output)
  for _, win in ipairs(windows_info) do
      print(string.format("ID: %d, App: '%s', Title: '%s', Bundle: '%s', Frame: x=%d,y=%d,w=%d,h=%d, Floating: %s", 
          win.id, win.app, win.title, win["bundle-identifier"], 
          win.frame.x, win.frame.y, win.frame.w, win.frame.h,
          win["is-floating"] and "yes" or "no"))
  end
end

-- Function to check if window should be unmanaged
local function shouldUnmanage(window)
    if not window then return false end
    
    local app = window:application()
    if not app then return false end
    
    local app_name = app:name()
    if not app_name then return false end
    
    for _, app_config in ipairs(apps) do
        -- Add ^ to start and $ to end to make it a proper regex match
        local pattern = "^" .. app_config.app .. "$"
        if app_name:match(pattern) then
            return true
        end
    end
    return false
end

-- Add window creation watcher with error handling
local function setupWindowWatcher()
    local wf = hs.window.filter.new()
    
    -- Add error handling for window creation events
    wf:subscribe(hs.window.filter.windowCreated, function(window)
        if not window then return end
        
        -- Delay the check slightly to ensure window is fully created
        hs.timer.doAfter(0.5, function()
            -- Check if window still exists and is valid
            if window and window:id() and shouldUnmanage(window) then
                local app = window:application()
                if app then
                    print(string.format("Unmanaging new window for app: %s", app:name()))
                    -- Get window ID from yabai
                    local cmd = string.format(
                        "/run/current-system/sw/bin/yabai -m query --windows | " ..
                        "jq '.[] | select(.app==\"%s\") | .id'",
                        app:name()
                    )
                    local window_id = hs.execute(cmd):gsub("%s+", "")
                    if window_id and window_id ~= "" then
                        -- Check if window is already floating
                        local check_cmd = string.format("/run/current-system/sw/bin/yabai -m query --windows | jq '.[] | select(.id==%s) | .\"is-floating\"'", window_id)
                        local is_floating = hs.execute(check_cmd):gsub("%s+", "")
                        
                        if is_floating == "false" then
                            print("Making new window float")
                            yabaiSync({"window", window_id, "--toggle", "float"})
                        end
                    end
                end
            end
        end)
    end)
    
    return wf
end

-- Create the window watcher
local window_watcher = setupWindowWatcher()

-- Bind arrow keys with Hyper and add debug output
print("Setting up arrow key bindings...")
Hyper:bind({}, "left", function() 
    print("Hyper + left pressed")
    moveWindowInDirection("left") 
end)
Hyper:bind({}, "right", function() 
    print("Hyper + right pressed")
    moveWindowInDirection("right") 
end)
Hyper:bind({}, "up", function() 
    print("Hyper + up pressed")
    moveWindowInDirection("up") 
end)
Hyper:bind({}, "down", function() 
    print("Hyper + down pressed")
    moveWindowInDirection("down") 
end)

-- Bind hotkey for positioning current window
Hyper:bind({"alt"}, ",", function()
  print("Hyper + , pressed")
  positionCurrentWindow("center_left")
end)
-- Bind hotkey for positioning current window
Hyper:bind({"alt"}, ".", function()
  print("Hyper + . pressed")
  positionCurrentWindow("center")
end)
-- Bind hotkey for positioning current window
Hyper:bind({"alt"}, "/", function()
  print("Hyper + / pressed")
  positionCurrentWindow("center_right")
end)

-- register all apps
hs.fnutils.each(apps, function(app)
    -- Bind app launch hotkeys
    if app.hotkey then
        -- Build modifier table
        local mods = {}
        if app.hotkey.shift then
            table.insert(mods, "shift")
        end
        
        print(string.format("Setting up bindings for app: %s", app.app))
        print(string.format("  Position: %s, Display: %s", 
            app.position, 
            standardPositions[app.position].display))
        
        -- Only bind to HyperModal if it's available and loaded
        if HyperModal and HyperModal.bind then
            print(string.format("  Using HyperModal binding with key '%s' and mods: %s", 
                app.hotkey.key, 
                table.concat(mods, "+")))
            
            -- Bind directly without unbinding first
            HyperModal:bind(mods, app.hotkey.key, function()
                print(string.format("HyperModal triggered for app: %s", app.app))
                local pos = standardPositions[app.position]
                -- Single focus and move operation
                moveAndResizeWindow(app, pos.x, pos.y, pos.w, pos.h, pos.display)
                focusWindowByApp(app.app)
                HyperModal:exit()
            end)
        else
            -- For Hyper binding, always include alt modifier
            table.insert(mods, "alt")
            print(string.format("  Using Hyper binding with key '%s' and mods: %s", 
                app.hotkey.key, 
                table.concat(mods, "+")))
            
            -- Bind directly without unbinding first
            Hyper:bind(mods, app.hotkey.key, function()
                print(string.format("Hyper triggered for app: %s", app.app))
                local pos = standardPositions[app.position]
                moveAndResizeWindow(app, pos.x, pos.y, pos.w, pos.h, pos.display)
                focusWindowByApp(app.app)
            end)
        end
    end
    
    -- Bind local keys if they exist
    if app.local_keys and app.bundleID then
        print(string.format("  Setting up local keys for app: %s", app.app))
        for _, key in ipairs(app.local_keys) do
            print(string.format("    Adding passthrough for key: %s", key))
            -- Local keys should always use Hyper, not HyperModal
            Hyper:bindPassThrough(key, app.bundleID)
        end
    end
end)

-- Function to print all HyperModal bindings
local function printHyperModalBindings()
    print("\n=== HyperModal Bindings ===")
    print("Format: KEY [MODIFIERS] -> APP (POSITION) [TYPE] {BUNDLE_ID}")
    print("Note: PWA = Progressive Web App, Local = Has local key bindings")
    
    -- Sort apps by hotkey for consistent output
    local appsByHotkey = {}
    for _, app in ipairs(apps) do
        if app.hotkey then
            table.insert(appsByHotkey, app)
        end
    end
    table.sort(appsByHotkey, function(a, b) 
        return a.hotkey.key < b.hotkey.key 
    end)
    
    -- Print bindings
    for _, app in ipairs(appsByHotkey) do
        if app.hotkey then
            -- Build modifiers string
            local mods = {}
            if app.hotkey.shift then
                table.insert(mods, "shift")
            end
            local modString = #mods > 0 and " [" .. table.concat(mods, "+") .. "]" or ""
            
            -- Build type indicators
            local types = {}
            if app.isPWA then table.insert(types, "PWA") end
            if app.local_keys then table.insert(types, "Local") end
            local typeString = #types > 0 and " [" .. table.concat(types, ",") .. "]" or ""
            
            -- Get display number and bundle ID
            local displayNum = standardPositions[app.position].display
            local bundleString = app.bundleID and " {" .. app.bundleID .. "}" or ""
            
            -- Build title string if present
            local titleString = app.title and " \"" .. app.title .. "\"" or ""
            
            print(string.format("  %s%s -> %s%s (at %s on display %d)%s%s", 
                app.hotkey.key,
                modString,
                app.app,
                titleString,
                app.position,
                displayNum,
                typeString,
                bundleString
            ))
            
            -- Print local keys if present
            if app.local_keys then
                print(string.format("    Local keys: %s", 
                    table.concat(app.local_keys, ", ")
                ))
            end
        end
    end
    print("=========================\n")
end

-- Print HyperModal bindings after registration
if HyperModal and HyperModal.bind then
    printHyperModalBindings()
else
    print("\nHyperModal is not available - using Hyper with alt modifier instead")
end
